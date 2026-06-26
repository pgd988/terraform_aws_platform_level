# IAM roles for EC2 instances
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gitlab" {
  name               = "gitlab-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
resource "aws_iam_instance_profile" "gitlab" {
  name = "gitlab-ec2-profile"
  role = aws_iam_role.gitlab.name
}

resource "aws_iam_role" "rabbitmq" {
  name               = "rabbitmq-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
resource "aws_iam_instance_profile" "rabbitmq" {
  name = "rabbitmq-ec2-profile"
  role = aws_iam_role.rabbitmq.name
}

resource "aws_iam_role" "mongodb" {
  name               = "mongodb-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
resource "aws_iam_instance_profile" "mongodb" {
  name = "mongodb-ec2-profile"
  role = aws_iam_role.mongodb.name
}

resource "aws_iam_role" "monitoring" {
  name               = "monitoring-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
resource "aws_iam_instance_profile" "monitoring" {
  name = "monitoring-ec2-profile"
  role = aws_iam_role.monitoring.name
}

# Attach ECR ReadOnly Policy to all EC2 roles
resource "aws_iam_role_policy_attachment" "gitlab_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.gitlab.name
}

resource "aws_iam_role_policy_attachment" "rabbitmq_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.rabbitmq.name
}

resource "aws_iam_role_policy_attachment" "mongodb_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.mongodb.name
}

resource "aws_iam_role_policy_attachment" "monitoring_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.monitoring.name
}

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

resource "aws_iam_role" "eks_node" {
  name               = "eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}
resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}
resource "aws_iam_role_policy_attachment" "eks_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

# AWS Load Balancer Controller Policy
resource "aws_iam_policy" "lbc" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy"
  policy      = file("${path.module}/policies/lbc_iam_policy.json")
}

resource "aws_ssm_parameter" "lbc_policy_arn" {
  name  = "/platform/iam/policies/lbc_policy_arn"
  type  = "String"
  value = aws_iam_policy.lbc.arn
}
