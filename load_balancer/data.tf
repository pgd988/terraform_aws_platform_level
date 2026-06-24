data "aws_ssm_parameter" "vpc_id" {
  name = var.vpc_ssm_path
}

data "aws_ssm_parameter" "public_subnets" {
  name = var.public_subnets_ssm_path
}

data "aws_ssm_parameter" "alb_sg" {
  name = var.alb_sg_ssm_path
}
