# Kubernetes Service Account for AWS Load Balancer Controller
resource "kubernetes_service_account" "lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
}

# Link IAM Role to K8s Service Account via Pod Identity
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = var.eks_cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = var.lbc_role_arn

  depends_on = [kubernetes_service_account.lbc]
}

# Helm Release for AWS Load Balancer Controller
resource "helm_release" "lbc" {
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
