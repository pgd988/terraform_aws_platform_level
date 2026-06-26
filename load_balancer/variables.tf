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

variable "deploy_alb" {
  description = "Switch to deploy Application Load Balancer and its chained Network Load Balancer entrypoint"
  type        = bool
  default     = true
}

variable "public_subnet_count" {
  description = "Number of public subnets to attach NLB EIPs to"
  type        = number
  default     = 2
}

variable "private_subnets_ssm_path" {
  type    = string
  default = "/platform/vpc/private_subnets"
}
