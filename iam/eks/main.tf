data "aws_caller_identity" "current" {}

# ==============================================================================
# 1. EKS Cluster Control Plane IAM Role
# ==============================================================================
data "aws_iam_policy_document" "eks_assume_role" {
  count = var.deploy_eks ? 1 : 0
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  count              = var.deploy_eks ? 1 : 0
  name               = "eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role[0].json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.deploy_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_auto_mode_compute" {
  count      = var.deploy_eks && var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_auto_mode_storage" {
  count      = var.deploy_eks && var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_auto_mode_lb" {
  count      = var.deploy_eks && var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_auto_mode_networking" {
  count      = var.deploy_eks && var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.eks_cluster[0].name
}

resource "aws_iam_role_policy" "eks_cluster_auto_mode_instance_profiles" {
  count = var.deploy_eks ? 1 : 0
  name  = "EKSAutoModeInstanceProfiles"
  role  = aws_iam_role.eks_cluster[0].id

  # Belt-and-suspenders supplement to AmazonEKSComputePolicy.
  # Auto Mode's internal Karpenter controller uses the cluster role to:
  #   1. CreateInstanceProfile  — one profile per custom NodeClass
  #   2. AddRoleToInstanceProfile  — attach eks-node-role to the new profile
  #   3. TagInstanceProfile  — required for Auto Mode internal bookkeeping
  #   4. RemoveRoleFromInstanceProfile + DeleteInstanceProfile  — teardown
  #   5. PassRole  — hand eks-node-role to EC2 when launching instances
  #
  # Without AddRoleToInstanceProfile / PassRole the NodeClass status will show:
  #   InstanceProfileReady: False — "Failed to create instance profile"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageInstanceProfiles"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassNodeRoleToEC2"
        Effect = "Allow"
        Action = "iam:PassRole"
        # Scoped to the specific node role — no wildcard passrole.
        Resource = aws_iam_role.eks_node[0].arn
      }
    ]
  })
}



# ==============================================================================
# 2. EKS Worker Node IAM Role
# ==============================================================================
data "aws_iam_policy_document" "ec2_assume_role" {
  count = var.deploy_eks ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  count              = var.deploy_eks ? 1 : 0
  name               = "eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role[0].json
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  count      = var.deploy_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  count      = var.deploy_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node[0].name
}

resource "aws_iam_role_policy_attachment" "eks_registry" {
  count      = var.deploy_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node[0].name
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch_agent" {
  count      = var.deploy_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_node[0].name
}

resource "aws_iam_role_policy_attachment" "eks_ssm" {
  count      = var.deploy_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node[0].name
}

resource "aws_iam_role_policy_attachment" "eks_worker_minimal" {
  count      = var.deploy_eks && var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.eks_node[0].name
}

resource "aws_iam_role_policy_attachment" "eks_registry_pull_only" {
  count      = var.deploy_eks && var.enable_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.eks_node[0].name
}





# ==============================================================================
# 3. IAM Group and Assumable Role for EKS Administrators
# ==============================================================================
resource "aws_iam_group" "eks_admins" {
  name = "eks_admins"
}

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



# ==============================================================================
# 4. AWS Private CA Connector IAM Role & Policy (EKS Pod Identity)
# ==============================================================================
data "aws_iam_policy_document" "privateca_connector_trust" {
  count = var.deploy_eks && var.deploy_adot ? 1 : 0
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "privateca_connector" {
  count              = var.deploy_eks && var.deploy_adot ? 1 : 0
  name               = "${var.eks_cluster_name}-privateca-connector-role"
  assume_role_policy = data.aws_iam_policy_document.privateca_connector_trust[0].json
}

resource "aws_iam_role_policy" "privateca_connector" {
  count = var.deploy_eks && var.deploy_adot ? 1 : 0
  name  = "PrivateCAConnectorPolicy"
  role  = aws_iam_role.privateca_connector[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSPrivateCAPermissions"
        Effect = "Allow"
        Action = [
          "acm-pca:IssueCertificate",
          "acm-pca:GetCertificate",
          "acm-pca:DescribeCertificateAuthority"
        ]
        Resource = "*"
      }
    ]
  })
}



# ==============================================================================
# 6. ADOT Collector IAM Role & Policy Attachments (EKS Pod Identity)
# ==============================================================================
data "aws_iam_policy_document" "adot_collector_pod_identity_trust" {
  count = var.deploy_adot ? 1 : 0
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "adot_collector" {
  count              = var.deploy_adot ? 1 : 0
  name               = "${var.eks_cluster_name}-adot-collector-role"
  assume_role_policy = data.aws_iam_policy_document.adot_collector_pod_identity_trust[0].json
}

resource "aws_iam_role_policy_attachment" "adot_cloudwatch" {
  count      = var.deploy_adot ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.adot_collector[0].name
}

resource "aws_iam_role_policy_attachment" "adot_xray" {
  count      = var.deploy_adot ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
  role       = aws_iam_role.adot_collector[0].name
}

resource "aws_iam_role_policy_attachment" "adot_prometheus" {
  count      = var.deploy_adot ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
  role       = aws_iam_role.adot_collector[0].name
}



# ==============================================================================
# 7. External Secrets Operator IAM Role & Policy (EKS Pod Identity)
# ==============================================================================
data "aws_iam_policy_document" "external_secrets_pod_identity_trust" {
  count = var.deploy_external_secrets ? 1 : 0
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  count              = var.deploy_external_secrets ? 1 : 0
  name               = "${var.eks_cluster_name}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_pod_identity_trust[0].json
}

resource "aws_iam_role_policy" "external_secrets" {
  count = var.deploy_external_secrets ? 1 : 0
  name  = "ExternalSecretsOperatorPolicy"
  role  = aws_iam_role.external_secrets[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ExternalSecretsOperatorPermissions"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}



# ==============================================================================
# 8. Argo CD Server IAM Role & Policy (EKS Pod Identity)
# ==============================================================================
data "aws_iam_policy_document" "argocd_pod_identity_trust" {
  count = var.deploy_argocd ? 1 : 0
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "argocd_server" {
  count              = var.deploy_argocd ? 1 : 0
  name               = "${var.eks_cluster_name}-argocd-server-role"
  assume_role_policy = data.aws_iam_policy_document.argocd_pod_identity_trust[0].json
}

resource "aws_iam_role_policy" "argocd_server" {
  count = var.deploy_argocd ? 1 : 0
  name  = "ArgoCDServerPolicy"
  role  = aws_iam_role.argocd_server[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ArgoCDServerPermissions"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = ["arn:aws:iam::*:role/ArgoCD*"]
      }
    ]
  })
}



# ==============================================================================
# 9. AWS Load Balancer Controller IAM Role & Policy (EKS Pod Identity)
# ==============================================================================
resource "aws_iam_policy" "lbc" {
  count       = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  name        = "${var.eks_cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy"
  policy      = file("${path.module}/policies/lbc_iam_policy.json")
}

data "aws_iam_policy_document" "lbc_pod_identity_trust" {
  count = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "lbc" {
  count              = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  name               = "${var.eks_cluster_name}-aws-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.lbc_pod_identity_trust[0].json
}

resource "aws_iam_role_policy_attachment" "lbc_attach" {
  count      = var.deploy_aws_lbc && !var.enable_auto_mode ? 1 : 0
  role       = aws_iam_role.lbc[0].name
  policy_arn = aws_iam_policy.lbc[0].arn
}

