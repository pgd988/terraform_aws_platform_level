module "eks" {
  source = "./eks"

  aws_region              = var.aws_region
  eks_cluster_name        = var.eks_cluster_name
  enable_auto_mode        = var.enable_auto_mode
  deploy_eks              = var.deploy_eks
  deploy_adot             = var.deploy_adot
  deploy_external_secrets = var.deploy_external_secrets
  deploy_argocd           = var.deploy_argocd
  deploy_aws_lbc          = var.deploy_aws_lbc
}
