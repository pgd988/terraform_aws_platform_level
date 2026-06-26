variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_ssm_path" {
  type    = string
  default = "/platform/vpc/id"
}

variable "private_subnets_ssm_path" {
  type    = string
  default = "/platform/vpc/private_subnets"
}

variable "default_sg_ssm_path" {
  type    = string
  default = "/platform/vpc/default_sg"
}

variable "deploy_gitlab" {
  type    = bool
  default = true
}

variable "deploy_rabbitmq" {
  type    = bool
  default = true
}

variable "deploy_mongodb" {
  type    = bool
  default = true
}

variable "deploy_monitoring" {
  type    = bool
  default = true
}

variable "public_subnets_ssm_path" {
  type    = string
  default = "/platform/vpc/public_subnets"
}
