output "eks_cluster_role_arn" {
  description = "ARN of the EKS Cluster IAM Role"
  value       = try(aws_iam_role.eks_cluster[0].arn, "")
}

output "eks_node_role_arn" {
  description = "ARN of the EKS Worker Node IAM Role"
  value       = try(aws_iam_role.eks_node[0].arn, "")
}


output "eks_admins_role_arn" {
  description = "ARN of the EKS Administrators Assumable Role"
  value       = aws_iam_role.eks_admin.arn
}


output "privateca_connector_role_arn" {
  description = "ARN of the Private CA Connector IAM Role"
  value       = try(aws_iam_role.privateca_connector[0].arn, "")
}

output "adot_collector_role_arn" {
  description = "ARN of the ADOT Collector IAM Role"
  value       = try(aws_iam_role.adot_collector[0].arn, "")
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets Operator IAM Role"
  value       = try(aws_iam_role.external_secrets[0].arn, "")
}

output "argocd_server_role_arn" {
  description = "ARN of the Argo CD Server IAM Role"
  value       = try(aws_iam_role.argocd_server[0].arn, "")
}

output "lbc_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM Role"
  value       = try(aws_iam_role.lbc[0].arn, "")
}
