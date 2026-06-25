# Argo CD
resource "kubernetes_namespace" "argocd" {
  count = var.deploy_eks ? 1 : 0
  metadata {
    name = "argocd"
  }
  depends_on = [aws_eks_node_group.main]
}

resource "helm_release" "argocd" {
  count      = var.deploy_eks ? 1 : 0
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd[0].metadata[0].name
  version    = "5.51.6" 

  values = [
    <<EOF
server:
  service:
    type: ClusterIP
EOF
  ]
}

# Argo Rollouts
resource "kubernetes_namespace" "argo_rollouts" {
  count = var.deploy_eks ? 1 : 0
  metadata {
    name = "argo-rollouts"
  }
  depends_on = [aws_eks_node_group.main]
}

resource "helm_release" "argo_rollouts" {
  count      = var.deploy_eks ? 1 : 0
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = kubernetes_namespace.argo_rollouts[0].metadata[0].name
  version    = "2.32.4"
}

# Argo Events
resource "kubernetes_namespace" "argo_events" {
  count = var.deploy_eks ? 1 : 0
  metadata {
    name = "argo-events"
  }
  depends_on = [aws_eks_node_group.main]
}

resource "helm_release" "argo_events" {
  count      = var.deploy_eks ? 1 : 0
  name       = "argo-events"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-events"
  namespace  = kubernetes_namespace.argo_events[0].metadata[0].name
  version    = "2.4.1"
}
