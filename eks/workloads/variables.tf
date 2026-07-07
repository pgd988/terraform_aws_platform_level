variable "eks_cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "eks_cluster_arn" {
  description = "EKS Cluster ARN"
  type        = string
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
  default     = false
}

variable "deploy_argo_events" {
  description = "Toggle deployment of Argo Events"
  type        = bool
  default     = false
}
