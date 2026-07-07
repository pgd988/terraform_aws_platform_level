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

variable "enable_auto_mode" {
  description = "Enable Amazon EKS Auto Mode IAM policy attachments for the cluster role"
  type        = bool
  default     = true
}


