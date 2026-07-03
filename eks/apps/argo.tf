# Argo CD
resource "kubernetes_namespace" "argocd" {
  count = var.deploy_argocd ? 1 : 0
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  count      = var.deploy_argocd ? 1 : 0
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "5.51.6"
  wait       = false

  depends_on = [kubernetes_namespace.argocd]

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
  count = var.deploy_argo_rollouts ? 1 : 0
  metadata {
    name = "argo-rollouts"
  }
}

resource "helm_release" "argo_rollouts" {
  count      = var.deploy_argo_rollouts ? 1 : 0
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = "argo-rollouts"
  version    = "2.32.4"
  wait       = false

  depends_on = [kubernetes_namespace.argo_rollouts]
}

# Argo Events
resource "kubernetes_namespace" "argo_events" {
  count = var.deploy_argo_events ? 1 : 0
  metadata {
    name = "argo-events"
  }
}

resource "helm_release" "argo_events" {
  count      = var.deploy_argo_events ? 1 : 0
  name       = "argo-events"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-events"
  namespace  = "argo-events"
  version    = "2.4.1"
  wait       = false

  depends_on = [kubernetes_namespace.argo_events]
}
