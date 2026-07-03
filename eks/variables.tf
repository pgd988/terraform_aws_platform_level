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

variable "deploy_apps" {
  description = "Toggle deployment of default Kubernetes workloads/apps (NGINX, Argo CD, AWS Load Balancer Controller, etc.)"
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  type    = string
  default = "platform-cluster"
}

variable "node_instance_types" {
  description = "List of EC2 instance types for the default EKS managed node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "alb_sg_id" {
  description = "Security Group ID of the ALB (output from load_balancer module). Required when deploy_eks = true."
  type        = string
  default     = ""
}

variable "admin_allowed_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach EKS API public endpoint (DevOps local PCs / VPN)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_admins_arn" {
  description = "ARN of the IAM Group for EKS Administrators (output from iam module). Required when deploy_eks = true."
  type        = string
  default     = ""
}

variable "deletion_protection" {
  description = "Enable deletion protection on supported resources (EKS API-level). Set to true for production deployments."
  type        = bool
  default     = false
}
