locals {
  private_subnets = split(",", data.aws_ssm_parameter.private_subnets.value)
}

resource "aws_eks_cluster" "main" {
  count    = var.deploy_eks ? 1 : 0
  name     = var.eks_cluster_name
  # The role is created in the iam module
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-cluster-role"

  vpc_config {
    subnet_ids = local.private_subnets
  }
}

resource "aws_eks_node_group" "main" {
  count           = var.deploy_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "default-node-group"
  # The role is created in the iam module
  node_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-node-role"
  subnet_ids      = local.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]
}
