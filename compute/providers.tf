terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "core-infra-terraform-state-bucket"
    key            = "compute/terraform.tfstate"
    dynamodb_table = "core-infra-terraform-state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "managed-by" = "terraform_aws_platform_level/compute"
      "managed_by" = "terraform_aws_platform_level/compute"
      "ManagedBy"  = "terraform_aws_platform_level/compute"
    }
  }
}
