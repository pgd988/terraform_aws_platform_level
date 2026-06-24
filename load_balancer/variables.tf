variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_ssm_path" {
  type    = string
  default = "/platform/vpc/id"
}

variable "public_subnets_ssm_path" {
  type    = string
  default = "/platform/vpc/public_subnets"
}

variable "alb_sg_ssm_path" {
  type    = string
  default = "/platform/vpc/alb_sg"
}
