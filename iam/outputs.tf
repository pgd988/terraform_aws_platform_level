output "gitlab_instance_profile" {
  value = aws_iam_instance_profile.gitlab.name
}
output "rabbitmq_instance_profile" {
  value = aws_iam_instance_profile.rabbitmq.name
}
output "mongodb_instance_profile" {
  value = aws_iam_instance_profile.mongodb.name
}
output "monitoring_instance_profile" {
  value = aws_iam_instance_profile.monitoring.name
}
output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}
output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "lbc_iam_policy_arn" {
  value = aws_iam_policy.lbc.arn
}
