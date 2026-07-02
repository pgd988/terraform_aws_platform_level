variable "eks_cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "lbc_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  type        = string
}
