# EKS Pod Identity Trust Policy for Argo CD Server
data "aws_iam_policy_document" "argocd_pod_identity_trust" {
  count = var.deploy_argocd ? 1 : 0
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

# IAM Role for Argo CD Server
resource "aws_iam_role" "argocd_server" {
  count              = var.deploy_argocd ? 1 : 0
  name               = "${var.eks_cluster_name}-argocd-server-role"
  assume_role_policy = data.aws_iam_policy_document.argocd_pod_identity_trust[0].json
}

# IAM Policy for Argo CD Server
resource "aws_iam_role_policy" "argocd_server" {
  count = var.deploy_argocd ? 1 : 0
  name  = "ArgoCDServerPolicy"
  role  = aws_iam_role.argocd_server[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ArgoCDServerPermissions"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "s3:GetObject",
          "s3:ListBucket",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "kms:Decrypt",
          "kms:DescribeKey",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Argo CD Helm Release
resource "helm_release" "argocd" {
  count            = var.deploy_argocd ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.6"
  wait             = false

  values = [
    <<EOF
configs:
  rbac:
    policy.default: role:readonly
    policy.csv: |
      g, admin, role:admin

controller:
  clusterAdminAccess:
    enabled: true

server:
  clusterAdminAccess:
    enabled: true
  service:
    type: ClusterIP
  serviceAccount:
    create: false
    name: argocd-server
EOF
  ]
}

# Kubernetes Service Account for Argo CD Server
resource "kubernetes_service_account" "argocd_server" {
  count = var.deploy_argocd ? 1 : 0
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
  depends_on = [helm_release.argocd]
}

# Link IAM Role to K8s Service Account via Pod Identity
resource "aws_eks_pod_identity_association" "argocd_server" {
  count           = var.deploy_argocd ? 1 : 0
  cluster_name    = var.eks_cluster_name
  namespace       = "argocd"
  service_account = kubernetes_service_account.argocd_server[0].metadata[0].name
  role_arn        = aws_iam_role.argocd_server[0].arn
}

# Argo Rollouts
resource "helm_release" "argo_rollouts" {
  count            = var.deploy_argo_rollouts ? 1 : 0
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
  version          = "2.32.4"
  wait             = false
}

# Argo Events
resource "helm_release" "argo_events" {
  count            = var.deploy_argo_events ? 1 : 0
  name             = "argo-events"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-events"
  namespace        = "argo-events"
  create_namespace = true
  version          = "2.4.1"
  wait             = false
}
