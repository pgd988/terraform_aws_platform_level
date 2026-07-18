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

variable "deploy_ascp" {
  description = "Toggle deployment of AWS Secrets and Configuration Provider (ASCP) EKS managed add-on (Kubernetes Secrets Store CSI Driver)"
  type        = bool
  default     = true
}

variable "deploy_adot" {
  description = "Toggle deployment of AWS Distro for OpenTelemetry (ADOT) EKS managed add-on and its required cert-manager prerequisite"
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  type    = string
  default = "platform-cluster"
}


variable "admin_allowed_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach EKS API public endpoint (DevOps local PCs / VPN)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


variable "deletion_protection" {
  description = "Enable deletion protection on supported resources (EKS API-level). Set to true for production deployments."
  type        = bool
  default     = false
}

variable "enable_auto_mode" {
  description = "Enable Amazon EKS Auto Mode (AWS-managed node provisioning, CoreDNS, EBS CSI, and Bottlerocket OS)"
  type        = bool
  default     = true
}


variable "auto_mode_node_pools" {
  description = "List of node pools to enable in EKS Auto Mode compute configuration"
  type        = list(string)
  default     = ["general-purpose", "system"]
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

variable "deploy_argocd" {
  description = "Toggle deployment of Argo CD"
  type        = bool
  default     = true
}

variable "deploy_external_secrets" {
  description = "Toggle deployment of External Secrets Operator"
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

variable "deploy_aws_lbc" {
  description = "Toggle deployment of AWS Load Balancer Controller (only applicable when enable_auto_mode = false)"
  type        = bool
  default     = false
}

variable "deploy_nginx" {
  description = "Toggle deployment of NGINX default backend"
  type        = bool
  default     = false
}
