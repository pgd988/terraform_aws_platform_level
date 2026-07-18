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

  backend "s3" {
    bucket         = "core-infra-terraform-state-bucket"
    key            = "eks/terraform.tfstate"
    dynamodb_table = "core-infra-terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "managed-by" = "terraform_aws_platform_level/eks"
      "managed_by" = "terraform_aws_platform_level/eks"
      "ManagedBy"  = "terraform_aws_platform_level/eks"
    }
  }
}

# WHY managed resource references (not data sources) for the provider config:
#
# data "aws_eks_cluster" calls the AWS API during the refresh phase.
# When the cluster has been manually deleted (or not yet created), the API
# returns "not found" and Terraform hard-fails — you cannot catch this with try().
#
# aws_eks_cluster.main[0] reads from the Terraform STATE, not from AWS.
# If the resource was removed from state, try() returns "" gracefully.
# If the cluster is being destroyed, Terraform already has the endpoint
# from the last known state, so the provider can still initialise to
# clean up any remaining Kubernetes/Helm resources.
#
# The exec block uses var.eks_cluster_name (a static input variable) so the
# token-generation command never references a resource attribute that may
# be unknown during provider initialisation.
provider "helm" {
  kubernetes {
    host                   = try(aws_eks_cluster.main[0].endpoint, "")
    cluster_ca_certificate = try(base64decode(aws_eks_cluster.main[0].certificate_authority[0].data), "")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = try(aws_eks_cluster.main[0].endpoint, "")
  cluster_ca_certificate = try(base64decode(aws_eks_cluster.main[0].certificate_authority[0].data), "")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
  }
}
