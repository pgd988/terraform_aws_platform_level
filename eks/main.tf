locals {
  private_subnets = split(",", data.aws_ssm_parameter.private_subnets.value)
}

# EKS Node IAM Role
resource "aws_iam_role" "eks_node" {
  name               = "eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}
resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}
resource "aws_iam_role_policy_attachment" "eks_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}
resource "aws_iam_role_policy_attachment" "eks_cloudwatch_agent" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_node.name
}
resource "aws_iam_role_policy_attachment" "eks_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node.name
}
resource "aws_iam_role_policy_attachment" "eks_worker_minimal" {
  count      = var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_kms_key" "eks" {
  count                   = var.deploy_eks ? 1 : 0
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_eks_cluster" "main" {
  count                         = var.deploy_eks ? 1 : 0
  name                          = var.eks_cluster_name
  role_arn                      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-cluster-role"
  enabled_cluster_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  bootstrap_self_managed_addons = !var.enable_auto_mode

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks[0].arn
    }
  }

  vpc_config {
    subnet_ids              = local.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.admin_allowed_cidrs
  }

  dynamic "compute_config" {
    for_each = var.enable_auto_mode ? [1] : []
    content {
      enabled       = true
      node_pools    = var.auto_mode_node_pools
      node_role_arn = aws_iam_role.eks_node.arn
    }
  }

  dynamic "storage_config" {
    for_each = var.enable_auto_mode ? [1] : []
    content {
      block_storage {
        enabled = true
      }
    }
  }

  dynamic "kubernetes_network_config" {
    for_each = var.enable_auto_mode ? [1] : []
    content {
      elastic_load_balancing {
        enabled = true
      }
    }
  }

  lifecycle {
    # prevent_destroy is intentionally not set here; controlled by the
    # deletion_protection variable at the API level (e.g. node group scaling).
    # Set deletion_protection = true and use Terraform state locks for
    # production-grade protection instead.
    prevent_destroy = false
  }
}


data "aws_iam_openid_connect_provider" "eks" {
  count = var.deploy_eks && !var.enable_auto_mode ? 1 : 0
  url   = aws_eks_cluster.main[0].identity[0].oidc[0].issuer
}


# Default EKS Managed Node Group to run Karpenter, CoreDNS, and system workloads
resource "aws_eks_node_group" "default" {
  count           = var.deploy_eks && !var.enable_auto_mode ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "default-node-pool"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = local.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  instance_types = var.node_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_registry,
  ]
}

resource "aws_eks_addon" "coredns" {
  count        = var.deploy_eks && !var.enable_auto_mode ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.default]
}

resource "aws_eks_addon" "pod_identity" {
  count        = var.deploy_eks ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "eks-pod-identity-agent"
}

# Base Cluster Helm Charts
module "charts" {
  source     = "./charts"
  count      = var.deploy_eks ? 1 : 0
  depends_on = [helm_release.karpenter_defaults]

  eks_cluster_name = aws_eks_cluster.main[0].name
  aws_region       = var.aws_region
}

# Zero-trust EKS boundary allowing ingress strictly from ALB Security Group
resource "aws_security_group_rule" "alb_to_eks" {
  count                    = var.deploy_eks && var.alb_sg_id != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 80
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = var.alb_sg_id
  security_group_id        = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  description              = "Allow application traffic strictly from ALB Security Group"
}

# Grant EKS Admins IAM Role ClusterAdmin kubectl permissions
resource "aws_eks_access_entry" "eks_admins" {
  count         = var.deploy_eks && var.eks_admins_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main[0].name
  principal_arn = var.eks_admins_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_admins" {
  count         = var.deploy_eks && var.eks_admins_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main[0].name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.eks_admins_arn

  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.eks_admins]
}

# Default Kubernetes Workloads
module "workloads" {
  source     = "./workloads"
  count      = var.deploy_eks && var.deploy_apps ? 1 : 0
  depends_on = [helm_release.karpenter_defaults]

  eks_cluster_name = aws_eks_cluster.main[0].name
  eks_cluster_arn  = aws_eks_cluster.main[0].arn
  enable_auto_mode = var.enable_auto_mode
}
