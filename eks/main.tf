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

resource "aws_kms_key" "eks" {
  count                   = var.deploy_eks ? 1 : 0
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_eks_cluster" "main" {
  count                     = var.deploy_eks ? 1 : 0
  name                      = var.eks_cluster_name
  role_arn                  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-cluster-role"
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

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

  lifecycle {
    # prevent_destroy is intentionally not set here; controlled by the
    # deletion_protection variable at the API level (e.g. node group scaling).
    # Set deletion_protection = true and use Terraform state locks for
    # production-grade protection instead.
    prevent_destroy = false
  }
}

resource "aws_eks_node_group" "main" {
  count           = var.deploy_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "default-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn
  # Restrict node pool to eu-central-1a (primary private subnet)
  subnet_ids      = [local.private_subnets[0]]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  node_repair_config {
    enabled = true
  }

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = var.node_instance_types

  # Explicit depends_on ensures IAM policies are fully attached before EC2 instances boot
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_registry,
    aws_iam_role_policy_attachment.eks_cloudwatch_agent,
    aws_iam_role_policy_attachment.eks_ssm,
  ]

  lifecycle {
    # See aws_eks_cluster lifecycle comment above.
    prevent_destroy = false
  }
}

resource "aws_eks_addon" "pod_identity" {
  count        = var.deploy_eks ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  count        = var.deploy_eks ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "amazon-cloudwatch-observability"
  depends_on   = [aws_eks_node_group.main]
}

# Zero-trust EKS boundary allowing ingress strictly from ALB Security Group
resource "aws_security_group_rule" "alb_to_eks" {
  count                    = var.deploy_eks ? 1 : 0
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
  count         = var.deploy_eks ? 1 : 0
  cluster_name  = aws_eks_cluster.main[0].name
  principal_arn = var.eks_admins_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_admins" {
  count         = var.deploy_eks ? 1 : 0
  cluster_name  = aws_eks_cluster.main[0].name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.eks_admins_arn

  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.eks_admins]
}

# Default Kubernetes Workloads / Apps
module "apps" {
  source     = "./apps"
  count      = var.deploy_eks && var.deploy_apps ? 1 : 0
  depends_on = [aws_eks_node_group.main]

  eks_cluster_name = aws_eks_cluster.main[0].name
  lbc_role_arn     = aws_iam_role.lbc[0].arn
}
