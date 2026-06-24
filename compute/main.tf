locals {
  # Assuming the subnets are stored as a comma-separated string in SSM
  private_subnets = split(",", data.aws_ssm_parameter.private_subnets.value)
}

resource "aws_instance" "gitlab" {
  count                  = var.deploy_gitlab ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"
  subnet_id              = local.private_subnets[0]
  vpc_security_group_ids = [data.aws_ssm_parameter.default_sg.value]
  iam_instance_profile   = "gitlab-ec2-profile" # Created in the IAM directory

  tags = {
    Name = "GitLab"
  }
}

resource "aws_instance" "rabbitmq" {
  count                  = var.deploy_rabbitmq ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"
  subnet_id              = local.private_subnets[0]
  vpc_security_group_ids = [data.aws_ssm_parameter.default_sg.value]
  iam_instance_profile   = "rabbitmq-ec2-profile" # Created in the IAM directory

  tags = {
    Name = "RabbitMQ"
  }
}

resource "aws_instance" "mongodb" {
  count                  = var.deploy_mongodb ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"
  subnet_id              = local.private_subnets[0]
  vpc_security_group_ids = [data.aws_ssm_parameter.default_sg.value]
  iam_instance_profile   = "mongodb-ec2-profile" # Created in the IAM directory

  tags = {
    Name = "MongoDB"
  }
}

resource "aws_instance" "monitoring" {
  count                  = var.deploy_monitoring ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"
  subnet_id              = local.private_subnets[0]
  vpc_security_group_ids = [data.aws_ssm_parameter.default_sg.value]
  iam_instance_profile   = "monitoring-ec2-profile" # Created in the IAM directory

  tags = {
    Name = "Monitoring"
  }
}
