variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "deletion_protection" {
  description = "Enable deletion protection on supported resources. Set to true for production deployments."
  type        = bool
  default     = false
}

variable "exclude_log_groups" {
  description = "Toggle to enable/disable exclusion of particular log sources from ingestion into CloudWatch"
  type        = bool
  default     = true
}

variable "excluded_log_groups" {
  description = "List of CloudWatch log group names to exclude from ingestion when exclude_log_groups is true"
  type        = list(string)
  default = [
    "/aws/containerinsights/platform-cluster/performance",
    "/aws/eks/platform-cluster/cluster",
    "/aws/containerinsights/platform-cluster/application"
  ]
}

variable "excluded_log_roles" {
  description = "List of IAM role names to attach the log exclusion policy to when exclude_log_groups is true"
  type        = list(string)
  default     = ["eks-node-role", "eks-cluster-role"]
}

