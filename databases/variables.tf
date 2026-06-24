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

variable "redis_sg_ssm_path" {
  type    = string
  default = "/platform/vpc/redis_sg"
}

variable "deploy_dynamodb" {
  type    = bool
  default = false
}
