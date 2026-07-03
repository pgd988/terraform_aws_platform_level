# Argo CD
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
server:
  service:
    type: ClusterIP
EOF
  ]
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
