resource "aws_cloudwatch_log_group" "platform_general" {
  name              = "/platform/general-logs"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "platform_eks" {
  name              = "/platform/eks-cluster-logs"
  retention_in_days = 1
}

resource "aws_iam_policy" "exclude_logs_ingestion" {
  count       = var.exclude_log_groups ? 1 : 0
  name        = "CloudWatchLogsIngestionExclusionPolicy"
  description = "IAM policy denying CloudWatch Logs ingestion for specified high-volume or excluded log groups"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyExcludedLogGroupsIngestion"
        Effect = "Deny"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          for log_group in var.excluded_log_groups :
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${log_group}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "exclude_logs_ingestion" {
  for_each = toset(var.exclude_log_groups ? var.excluded_log_roles : [])

  policy_arn = aws_iam_policy.exclude_logs_ingestion[0].arn
  role       = each.value
}

