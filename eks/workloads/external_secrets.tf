# External Secrets Operator Namespace
resource "kubernetes_namespace" "external_secrets" {
  count = var.deploy_external_secrets ? 1 : 0
  metadata {
    name = "external-secrets"
  }
}

# EKS Pod Identity Trust Policy for External Secrets Operator
data "aws_iam_policy_document" "external_secrets_pod_identity_trust" {
  count = var.deploy_external_secrets ? 1 : 0
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }


  }
}

# IAM Role for External Secrets Operator
resource "aws_iam_role" "external_secrets" {
  count              = var.deploy_external_secrets ? 1 : 0
  name               = "${var.eks_cluster_name}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_pod_identity_trust[0].json
}

# IAM Policy for External Secrets Operator
resource "aws_iam_role_policy" "external_secrets" {
  count = var.deploy_external_secrets ? 1 : 0
  name  = "ExternalSecretsOperatorPolicy"
  role  = aws_iam_role.external_secrets[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ExternalSecretsOperatorPermissions"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Kubernetes Service Account for External Secrets Operator
resource "kubernetes_service_account" "external_secrets" {
  count = var.deploy_external_secrets ? 1 : 0
  metadata {
    name      = "external-secrets"
    namespace = kubernetes_namespace.external_secrets[0].metadata[0].name
  }
}

# Link IAM Role to K8s Service Account via Pod Identity
resource "aws_eks_pod_identity_association" "external_secrets" {
  count           = var.deploy_external_secrets ? 1 : 0
  cluster_name    = var.eks_cluster_name
  namespace       = kubernetes_namespace.external_secrets[0].metadata[0].name
  service_account = kubernetes_service_account.external_secrets[0].metadata[0].name
  role_arn        = aws_iam_role.external_secrets[0].arn
}

# External Secrets Operator Helm Release
resource "helm_release" "external_secrets" {
  count            = var.deploy_external_secrets ? 1 : 0
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = kubernetes_namespace.external_secrets[0].metadata[0].name
  create_namespace = false
  version          = "0.10.5"
  wait             = true

  values = [
    <<EOF
installCRDs: true
serviceAccount:
  create: false
  name: external-secrets
EOF
  ]

  depends_on = [aws_eks_pod_identity_association.external_secrets]
}

data "aws_region" "current" {}

# Deploy default SecretStore and ClusterSecretStore resources via local Helm chart
resource "helm_release" "external_secrets_defaults" {
  count     = var.deploy_external_secrets ? 1 : 0
  name      = "external-secrets-defaults"
  chart     = "${path.module}/charts/external-secrets-defaults"
  namespace = kubernetes_namespace.external_secrets[0].metadata[0].name
  wait      = false

  set {
    name  = "region"
    value = data.aws_region.current.name
  }
  set {
    name  = "argocd.deployed"
    value = var.deploy_argocd
  }
  set {
    name  = "argocd.enabled"
    value = var.deploy_argocd && var.argocd_github_app_id != ""
  }
  set {
    name  = "argocd.repoUrl"
    value = var.argocd_github_repo_url
  }
  set {
    name  = "argocd.appID"
    value = var.argocd_github_app_id
  }
  set {
    name  = "argocd.installationID"
    value = var.argocd_github_app_installation_id
  }
  set {
    name  = "argocd.secretName"
    value = var.argocd_github_secret_name
  }
  set {
    name  = "templates_hash"
    value = sha1(join("", [for f in fileset("${path.module}/charts/external-secrets-defaults/templates", "*.yaml") : filesha1("${path.module}/charts/external-secrets-defaults/templates/${f}")]))
  }

  depends_on = [
    helm_release.external_secrets,
    helm_release.argocd
  ]
}
