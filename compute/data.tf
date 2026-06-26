data "aws_ssm_parameter" "vpc_id" {
  name = var.vpc_ssm_path
}

data "aws_ssm_parameter" "private_subnets" {
  name = var.private_subnets_ssm_path
}

data "aws_ssm_parameter" "default_sg" {
  name = var.default_sg_ssm_path
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_ssm_parameter" "public_subnets" {
  name = var.public_subnets_ssm_path
}
