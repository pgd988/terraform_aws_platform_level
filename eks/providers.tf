terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster_auth" "main" {
  count = var.deploy_eks ? 1 : 0
  name  = aws_eks_cluster.main[0].name
}

provider "helm" {
  kubernetes {
    host                   = try(aws_eks_cluster.main[0].endpoint, "")
    cluster_ca_certificate = try(base64decode(aws_eks_cluster.main[0].certificate_authority[0].data), "")
    token                  = try(data.aws_eks_cluster_auth.main[0].token, "")
  }
}

provider "kubernetes" {
  host                   = try(aws_eks_cluster.main[0].endpoint, "")
  cluster_ca_certificate = try(base64decode(aws_eks_cluster.main[0].certificate_authority[0].data), "")
  token                  = try(data.aws_eks_cluster_auth.main[0].token, "")
}
