variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
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
  default = false
}

variable "deploy_rabbitmq" {
  type    = bool
  default = false
}

variable "deploy_mongodb" {
  type    = bool
  default = false
}

variable "deploy_monitoring" {
  type    = bool
  default = true
}

variable "public_subnets_ssm_path" {
  type    = string
  default = "/platform/vpc/public_subnets"
}

variable "deletion_protection" {
  description = "Enable deletion protection on supported resources (disable_api_termination on EC2). Set to true for production deployments."
  type        = bool
  default     = false
}
