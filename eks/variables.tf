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

variable "deploy_eks" {
  type    = bool
  default = true
}

variable "eks_cluster_name" {
  type    = string
  default = "platform-cluster"
}
