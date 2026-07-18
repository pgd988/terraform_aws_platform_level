locals {
  private_subnets = split(",", data.aws_ssm_parameter.private_subnets.value)
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
  role_arn                      = data.terraform_remote_state.iam.outputs.eks_cluster_role_arn
  enabled_cluster_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  bootstrap_self_managed_addons = !var.enable_auto_mode

  access_config {
    # API-only mode: EKS Access Entries are the sole authentication mechanism.
    # API_AND_CONFIG_MAP was causing the EKS console "Unexpected non-whitespace
    # character after JSON" deserialization error — the console tried to merge
    # Access Entries with the aws-auth ConfigMap, which fails when the ConfigMap
    # is empty or contains non-JSON content on a fresh cluster.
    # NOTE: This migration is one-way — AWS does not allow reverting from API to
    # API_AND_CONFIG_MAP once the cluster has been updated.
    authentication_mode                         = "API"
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
      node_role_arn = data.terraform_remote_state.iam.outputs.eks_node_role_arn
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

    # Catch missing IAM role ARNs at plan time, before the EKS API call.
    # If iam/ hasn't been applied yet, terraform_remote_state returns "" and the
    # EKS CreateCluster API will fail after ~2 minutes with:
    #   "InvalidParameterException: Provided NodeRole does not exist"
    # These preconditions surface the real cause immediately.
    precondition {
      condition     = data.terraform_remote_state.iam.outputs.eks_cluster_role_arn != ""
      error_message = "eks_cluster_role_arn is empty — apply the iam/ module first: terraform -chdir=iam apply"
    }

    precondition {
      condition     = !var.enable_auto_mode || data.terraform_remote_state.iam.outputs.eks_node_role_arn != ""
      error_message = "eks_node_role_arn is empty — apply the iam/ module first: terraform -chdir=iam apply"
    }
  }
}


resource "aws_eks_addon" "pod_identity" {
  count        = var.deploy_eks ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_eks_addon" "secrets_store_csi_driver_provider" {
  count        = var.deploy_eks && var.deploy_ascp ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "aws-secrets-store-csi-driver-provider"
}

# Base Cluster Helm Charts
module "charts" {
  source     = "./charts"
  count      = var.deploy_eks ? 1 : 0
  depends_on = [aws_eks_addon.pod_identity]

  eks_cluster_name = aws_eks_cluster.main[0].name
  aws_region       = var.aws_region
}

resource "aws_eks_addon" "adot" {
  count        = var.deploy_eks && var.deploy_adot ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "adot"

  depends_on = [
    aws_eks_addon.cert_manager,
    helm_release.awspca_cluster_issuer
  ]
}

# Zero-trust EKS boundary allowing ingress strictly from ALB Security Group
resource "aws_security_group_rule" "alb_to_eks" {
  count                    = var.deploy_eks && var.deploy_aws_lbc && try(data.terraform_remote_state.load_balancer[0].outputs.alb_sg_id, null) != null ? 1 : 0
  type                     = "ingress"
  from_port                = 80
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.load_balancer[0].outputs.alb_sg_id
  security_group_id        = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  description              = "Allow application traffic strictly from ALB Security Group"
}

# Grant EKS Admins IAM Role ClusterAdmin kubectl permissions
resource "aws_eks_access_entry" "eks_admins" {
  count         = var.deploy_eks && data.terraform_remote_state.iam.outputs.eks_admins_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main[0].name
  principal_arn = data.terraform_remote_state.iam.outputs.eks_admins_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_admins" {
  count         = var.deploy_eks && data.terraform_remote_state.iam.outputs.eks_admins_role_arn != "" ? 1 : 0
  cluster_name  = aws_eks_cluster.main[0].name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.terraform_remote_state.iam.outputs.eks_admins_role_arn

  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.eks_admins]
}

# Default Kubernetes Workloads
module "workloads" {
  source     = "./workloads"
  count      = var.deploy_eks && var.deploy_apps ? 1 : 0
  depends_on = [
    aws_eks_addon.pod_identity,
    aws_eks_addon.secrets_store_csi_driver_provider,
    aws_eks_addon.adot
  ]

  eks_cluster_name        = aws_eks_cluster.main[0].name
  eks_cluster_arn         = aws_eks_cluster.main[0].arn
  enable_auto_mode        = var.enable_auto_mode
  deploy_adot             = var.deploy_adot
  deploy_argocd           = var.deploy_argocd
  deploy_external_secrets = var.deploy_external_secrets
  deploy_argo_rollouts    = var.deploy_argo_rollouts
  deploy_argo_events      = var.deploy_argo_events
  deploy_aws_lbc          = var.deploy_aws_lbc
  deploy_nginx            = var.deploy_nginx

  adot_collector_role_arn   = data.terraform_remote_state.iam.outputs.adot_collector_role_arn
  external_secrets_role_arn = data.terraform_remote_state.iam.outputs.external_secrets_role_arn
  argocd_server_role_arn    = data.terraform_remote_state.iam.outputs.argocd_server_role_arn
  lbc_role_arn              = data.terraform_remote_state.iam.outputs.lbc_role_arn
  default_tg_arn            = var.deploy_aws_lbc && var.deploy_nginx ? try(data.terraform_remote_state.load_balancer[0].outputs.default_tg_arn, null) : null

  argocd_github_repo_url            = var.argocd_github_repo_url
  argocd_github_app_id              = var.argocd_github_app_id
  argocd_github_app_installation_id = var.argocd_github_app_installation_id
  argocd_github_secret_name         = var.argocd_github_secret_name
}
