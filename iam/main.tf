# EKS Roles
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}



# IAM Group for EKS Administrators
resource "aws_iam_group" "eks_admins" {
  name = "eks_admins"
}

# Export IAM Group ARN via SSM
resource "aws_ssm_parameter" "eks_admins_arn" {
  name  = "/platform/iam/eks_admins_arn"
  type  = "String"
  value = aws_iam_group.eks_admins.arn
}

# IAM Policy for AWS Load Balancer Controller (IRSA)
resource "aws_iam_policy" "lbc" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for the AWS Load Balancer Controller running in EKS"
  policy      = file("${path.module}/policies/lbc_iam_policy.json")
}
