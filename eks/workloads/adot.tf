# ADOT Collector Namespace
resource "kubernetes_namespace" "opentelemetry" {
  count = var.deploy_adot ? 1 : 0
  metadata {
    name = "opentelemetry"
    labels = {
      "managed-by" = "terraform_aws_platform_level_eks"
    }
    annotations = {
      "managed-by" = "terraform_aws_platform_level/eks"
    }
  }
}

# Kubernetes Service Account for ADOT Collector
resource "kubernetes_service_account" "adot_collector" {
  count = var.deploy_adot ? 1 : 0
  metadata {
    name      = "adot-collector"
    namespace = kubernetes_namespace.opentelemetry[0].metadata[0].name
    labels = {
      "managed-by" = "terraform_aws_platform_level_eks"
    }
    annotations = {
      "managed-by" = "terraform_aws_platform_level/eks"
    }
  }
}

# Link IAM Role to K8s Service Account via Pod Identity
resource "aws_eks_pod_identity_association" "adot_collector" {
  count           = var.deploy_adot ? 1 : 0
  cluster_name    = var.eks_cluster_name
  namespace       = kubernetes_namespace.opentelemetry[0].metadata[0].name
  service_account = kubernetes_service_account.adot_collector[0].metadata[0].name
  role_arn        = var.adot_collector_role_arn
}
