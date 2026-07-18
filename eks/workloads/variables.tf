variable "eks_cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "eks_cluster_arn" {
  description = "EKS Cluster ARN"
  type        = string
}

# IAM Role ARNs — passed in from parent eks/ module (sourced from iam/ remote state)
variable "adot_collector_role_arn" {
  description = "IAM Role ARN for the ADOT Collector (EKS Pod Identity)"
  type        = string
  default     = ""
}

variable "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets Operator (EKS Pod Identity)"
  type        = string
  default     = ""
}

variable "argocd_server_role_arn" {
  description = "IAM Role ARN for the Argo CD Server (EKS Pod Identity)"
  type        = string
  default     = ""
}

variable "lbc_role_arn" {
  description = "IAM Role ARN for the AWS Load Balancer Controller (EKS Pod Identity)"
  type        = string
  default     = ""
}

# Cross-module: ALB Target Group ARN — passed from load_balancer/ remote state via parent eks/ module
variable "default_tg_arn" {
  description = "ARN of the ALB default Target Group for the NGINX sink TargetGroupBinding"
  type        = string
  default     = null
}

variable "deploy_aws_lbc" {
  description = "Toggle deployment of AWS Load Balancer Controller"
  type        = bool
  default     = false
}

variable "enable_auto_mode" {
  description = "Enable Amazon EKS Auto Mode (bypasses self-managed AWS Load Balancer Controller)"
  type        = bool
  default     = true
}



variable "deploy_nginx" {
  description = "Toggle deployment of NGINX default backend"
  type        = bool
  default     = false
}

variable "deploy_argocd" {
  description = "Toggle deployment of Argo CD"
  type        = bool
  default     = true
}

variable "deploy_argo_rollouts" {
  description = "Toggle deployment of Argo Rollouts"
  type        = bool
  default     = true
}

variable "deploy_argo_events" {
  description = "Toggle deployment of Argo Events"
  type        = bool
  default     = false
}

variable "deploy_external_secrets" {
  description = "Toggle deployment of External Secrets Operator"
  type        = bool
  default     = true
}

variable "deploy_adot" {
  description = "Toggle deployment of ADOT Collector IAM Role and EKS Pod Identity association"
  type        = bool
  default     = true
}

variable "argocd_github_repo_url" {
  description = "GitHub repository URL for Argo CD"
  type        = string
  default     = "https://github.com/pgd988/argocd_test_repo.git"
}

variable "argocd_github_app_id" {
  description = "GitHub App ID for Argo CD repo authentication"
  type        = string
  default     = "4238467"
}

variable "argocd_github_app_installation_id" {
  description = "GitHub App Installation ID for Argo CD repo authentication"
  type        = string
  default     = "145000316"
}

variable "argocd_github_secret_name" {
  description = "AWS Secrets Manager secret name containing the GitHub App private key"
  type        = string
  default     = "argocd/github-app"
}
