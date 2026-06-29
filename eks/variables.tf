variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_ssm_path" {
  type    = string
  default = "/infra/networking/vpc_id"
}

variable "private_subnets_ssm_path" {
  type    = string
  default = "/infra/networking/private_subnets"
}

variable "deploy_eks" {
  type    = bool
  default = true
}

variable "eks_cluster_name" {
  type    = string
  default = "platform-cluster"
}

variable "node_instance_types" {
  description = "List of EC2 instance types for the default EKS managed node group"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "alb_sg_ssm_path" {
  type    = string
  default = "/platform/alb/security_group_id"
}

variable "admin_allowed_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach EKS API public endpoint (DevOps local PCs / VPN)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_admins_ssm_path" {
  description = "SSM Parameter path for the IAM group ARN of EKS Admins"
  type        = string
  default     = "/platform/iam/eks_admins_arn"
}

variable "deletion_protection" {
  description = "Enable deletion protection on supported resources (EKS API-level). Set to true for production deployments."
  type        = bool
  default     = false
}
