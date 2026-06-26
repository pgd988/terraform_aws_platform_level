data "aws_ssm_parameter" "vpc_id" {
  name = var.vpc_ssm_path
}

data "aws_ssm_parameter" "private_subnets" {
  name = var.private_subnets_ssm_path
}

data "aws_ssm_parameter" "redis_sg" {
  name = var.redis_sg_ssm_path
}

data "aws_ssm_parameter" "rds_sg" {
  name = var.rds_sg_ssm_path
}
