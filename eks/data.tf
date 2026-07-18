# Cross-repo: VPC and networking params come from the core_infra repository
data "aws_ssm_parameter" "vpc_id" {
  name = var.vpc_ssm_path
}

data "aws_ssm_parameter" "private_subnets" {
  name = var.private_subnets_ssm_path
}

data "aws_caller_identity" "current" {}

# Intra-repo: IAM roles provisioned by the iam/ state of this repository
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket         = "core-infra-terraform-state-bucket"
    key            = "iam/terraform.tfstate"
    dynamodb_table = "core-infra-terraform-state-locks"
    encrypt        = true
    region         = var.aws_region
  }
}

# Intra-repo: ALB resources provisioned by the load_balancer/ state of this repository.
# Only fetched when deploy_aws_lbc = true — if there is no load balancer there is no state to read.
data "terraform_remote_state" "load_balancer" {
  count   = var.deploy_aws_lbc ? 1 : 0
  backend = "s3"
  config = {
    bucket         = "core-infra-terraform-state-bucket"
    key            = "load_balancer/terraform.tfstate"
    dynamodb_table = "core-infra-terraform-state-locks"
    encrypt        = true
    region         = var.aws_region
  }
}

