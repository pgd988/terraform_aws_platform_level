resource "aws_cloudwatch_log_group" "platform_general" {
  name              = "/platform/general-logs"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "platform_eks" {
  name              = "/platform/eks-cluster-logs"
  retention_in_days = 30
}
