output "exclude_logs_policy_arn" {
  description = "ARN of the CloudWatch Logs ingestion exclusion IAM policy"
  value       = var.exclude_log_groups ? aws_iam_policy.exclude_logs_ingestion[0].arn : null
}
