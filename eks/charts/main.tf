# CloudWatch Observability Helm Chart
resource "helm_release" "cloudwatch_observability" {
  name             = "amazon-cloudwatch-observability"
  repository       = "https://aws-observability.github.io/helm-charts"
  chart            = "amazon-cloudwatch-observability"
  namespace        = "amazon-cloudwatch"
  create_namespace = true
  version          = "6.2.0"
  wait             = false

  values = [
    <<EOF
clusterName: ${var.eks_cluster_name}
region: ${var.aws_region}
EOF
  ]
}


