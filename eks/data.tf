data "aws_ssm_parameter" "vpc_id" {
  name = var.vpc_ssm_path
}

data "aws_ssm_parameter" "private_subnets" {
  name = var.private_subnets_ssm_path
}

data "aws_caller_identity" "current" {}
