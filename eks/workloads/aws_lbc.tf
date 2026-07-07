data "aws_caller_identity" "current" {}

# Create AWS Load Balancer Controller IAM Policy from local file
resource "aws_iam_policy" "lbc" {
  count       = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  name        = "${var.eks_cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy"
  policy      = file("${path.module}/../policies/lbc_iam_policy.json")
}

# EKS Pod Identity Trust Policy (Least Privilege Principle)
data "aws_iam_policy_document" "lbc_pod_identity_trust" {
  count = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
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

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.eks_cluster_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks-pod-identity-agent:namespace"
      values   = ["kube-system"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks-pod-identity-agent:service-account"
      values   = ["aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  count              = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  name               = "${var.eks_cluster_name}-aws-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.lbc_pod_identity_trust[0].json
}

resource "aws_iam_role_policy_attachment" "lbc_attach" {
  count      = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  role       = aws_iam_role.lbc[0].name
  policy_arn = aws_iam_policy.lbc[0].arn
}

# Kubernetes Service Account for AWS Load Balancer Controller
resource "kubernetes_service_account" "lbc" {
  count = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
}

# Link IAM Role to K8s Service Account via Pod Identity
resource "aws_eks_pod_identity_association" "lbc" {
  count           = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  cluster_name    = var.eks_cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc[0].arn

  depends_on = [kubernetes_service_account.lbc]
}

# Helm Release for AWS Load Balancer Controller
resource "helm_release" "lbc" {
  count      = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"
  wait       = false

  values = [
    <<EOF
clusterName: ${var.eks_cluster_name}
serviceAccount:
  create: false
  name: aws-load-balancer-controller
EOF
  ]

  depends_on = [aws_eks_pod_identity_association.lbc]
}
