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

resource "aws_iam_role_policy_attachment" "eks_cluster_auto_mode_compute" {
  count      = var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_auto_mode_storage" {
  count      = var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_auto_mode_lb" {
  count      = var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_auto_mode_networking" {
  count      = var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.eks_cluster.name
}




# IAM Group for EKS Administrators
resource "aws_iam_group" "eks_admins" {
  name = "eks_admins"
}

# Assumable IAM Role for EKS Administrators (Kubernetes RBAC ClusterAdmin)
data "aws_iam_policy_document" "eks_admin_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "eks_admin" {
  name               = "eks-admin-role"
  assume_role_policy = data.aws_iam_policy_document.eks_admin_assume_role.json
}

resource "aws_iam_group_policy" "eks_admins" {
  name  = "EKSAdminFullAccessPolicy"
  group = aws_iam_group.eks_admins.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSClusterAdministration"
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:*",
          "logs:*",
          "monitoring:*",
          "cloudwatch:*",
          "iam:ListRoles",
          "iam:GetRole",
          "iam:PassRole",
          "iam:ListAttachedRolePolicies",
          "iam:CreateServiceLinkedRole",
          "kms:DescribeKey",
          "kms:ListKeys",
          "kms:CreateGrant",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:StartSession",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
      },
      {
        Sid      = "AssumeEKSAdminRole"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = [aws_iam_role.eks_admin.arn]
      }
    ]
  })
}

# Export EKS Admin Role ARN via SSM (EKS Access Entry requires Role/User, not Group)
resource "aws_ssm_parameter" "eks_admins_arn" {
  name  = "/platform/iam/eks_admins_arn"
  type  = "String"
  value = aws_iam_role.eks_admin.arn
}

# IAM Policy for AWS Load Balancer Controller (IRSA)
resource "aws_iam_policy" "lbc" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for the AWS Load Balancer Controller running in EKS"
  policy      = file("${path.module}/policies/lbc_iam_policy.json")
}
