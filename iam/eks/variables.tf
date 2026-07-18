variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "platform-cluster"
}

variable "enable_auto_mode" {
  description = "Enable Amazon EKS Auto Mode IAM policy attachments for the cluster role and minimal worker node policies"
  type        = bool
  default     = true
}

variable "deploy_eks" {
  description = "Toggle creation of EKS cluster and node IAM roles"
  type        = bool
  default     = true
}

variable "deploy_adot" {
  description = "Toggle creation of ADOT Collector IAM Role"
  type        = bool
  default     = true
}

variable "deploy_external_secrets" {
  description = "Toggle creation of External Secrets Operator IAM Role"
  type        = bool
  default     = true
}

variable "deploy_argocd" {
  description = "Toggle creation of Argo CD Server IAM Role"
  type        = bool
  default     = true
}

variable "deploy_aws_lbc" {
  description = "Toggle creation of AWS Load Balancer Controller IAM Role"
  type        = bool
  default     = false
}
