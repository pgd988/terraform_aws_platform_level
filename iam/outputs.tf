output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}
output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "lbc_iam_policy_arn" {
  value = aws_iam_policy.lbc.arn
}

output "eks_admins_group_arn" {
  description = "IAM Group ARN for EKS Administrators"
  value       = aws_iam_group.eks_admins.arn
}
