data "aws_ssm_parameter" "vpc_id" {
  name = var.vpc_ssm_path
}

data "aws_ssm_parameter" "private_subnets" {
  name = var.private_subnets_ssm_path
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "alb_sg" {
  name = var.alb_sg_ssm_path
}

data "aws_ssm_parameter" "eks_admins_arn" {
  name = var.eks_admins_ssm_path
}
