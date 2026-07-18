# Option 1: AWS Managed EKS Add-on for cert-manager
resource "aws_eks_addon" "cert_manager" {
  count        = var.deploy_eks && var.deploy_adot ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "cert-manager"
}

# Option 2: Full AWS Certificate Flow using AWS Private CA and Private CA Connector EKS Add-on

# 1. Root AWS Private Certificate Authority (ACM Private CA)
resource "aws_acmpca_certificate_authority" "cluster_ca" {
  count = var.deploy_eks && var.deploy_adot ? 1 : 0
  type  = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      common_name  = "${var.eks_cluster_name}-root-ca"
      organization = "Platform Engineering"
    }
  }

  permanent_deletion_time_in_days = 7
}

# 2. Self-sign the Root CA certificate signing request
resource "aws_acmpca_certificate" "cluster_ca" {
  count                     = var.deploy_eks && var.deploy_adot ? 1 : 0
  certificate_authority_arn = aws_acmpca_certificate_authority.cluster_ca[0].arn
  certificate_signing_request = aws_acmpca_certificate_authority.cluster_ca[0].certificate_signing_request
  signing_algorithm         = "SHA256WITHRSA"

  template_arn = "arn:aws:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 10
  }
}

# 3. Import self-signed certificate back to CA to transition status to ACTIVE
resource "aws_acmpca_certificate_authority_certificate" "cluster_ca" {
  count                     = var.deploy_eks && var.deploy_adot ? 1 : 0
  certificate_authority_arn = aws_acmpca_certificate_authority.cluster_ca[0].arn
  certificate               = aws_acmpca_certificate.cluster_ca[0].certificate
  certificate_chain         = aws_acmpca_certificate.cluster_ca[0].certificate_chain
}

# 4. Official AWS Private CA Connector for Kubernetes EKS Add-on
resource "aws_eks_addon" "aws_privateca_connector" {
  count        = var.deploy_eks && var.deploy_adot ? 1 : 0
  cluster_name = aws_eks_cluster.main[0].name
  addon_name   = "aws-privateca-connector-for-kubernetes"

  pod_identity_association {
    role_arn        = data.terraform_remote_state.iam.outputs.privateca_connector_role_arn
    service_account = "aws-privateca-connector"
  }

  depends_on = [
    aws_eks_addon.cert_manager,
    aws_acmpca_certificate_authority_certificate.cluster_ca
  ]
}

# 5. Deploy AWSPCAClusterIssuer CR inside Kubernetes to complete the full certificate flow
resource "helm_release" "awspca_cluster_issuer" {
  count     = var.deploy_eks && var.deploy_adot ? 1 : 0
  name      = "awspca-cluster-issuer"
  chart     = "${path.module}/charts/awspca-cluster-issuer"
  namespace = "cert-manager"
  wait      = true

  set {
    name  = "arn"
    value = aws_acmpca_certificate_authority.cluster_ca[0].arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  depends_on = [
    aws_eks_addon.aws_privateca_connector
  ]
}
