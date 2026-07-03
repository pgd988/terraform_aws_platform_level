# Explicit security group rules to guarantee probe and webhook reachability
resource "aws_security_group_rule" "karpenter_probes" {
  count                    = var.deploy_eks ? 1 : 0
  type                     = "ingress"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  security_group_id        = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  description              = "Allow EKS control plane and kubelet liveness/readiness probes to Karpenter on port 8081"
}

resource "aws_security_group_rule" "karpenter_webhook" {
  count                    = var.deploy_eks ? 1 : 0
  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  security_group_id        = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  description              = "Allow EKS control plane webhook requests to Karpenter on port 8443"
}

# IAM Policy for Karpenter Controller
resource "aws_iam_policy" "karpenter_controller" {
  count       = var.deploy_eks ? 1 : 0
  name        = "${var.eks_cluster_name}-karpenter-controller-policy"
  description = "IAM Policy for Karpenter Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KarpenterControllerEC2"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
          "ec2:Describe*",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterControllerIAMInstanceProfile"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterControllerASG"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterControllerEKS"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterControllerPricing"
        Effect = "Allow"
        Action = [
          "pricing:GetProducts",
          "pricing:GetAttributeValues"
        ]
        Resource = "*"
      },
      {
        Sid      = "KarpenterControllerPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.eks_node.arn
      },
      {
        Sid      = "KarpenterControllerCreateSLR"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "spot.amazonaws.com",
              "spotfleet.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# IAM Role for Karpenter Controller (using IRSA / OIDC)
resource "aws_iam_role" "karpenter_controller" {
  count = var.deploy_eks ? 1 : 0
  name  = "${var.eks_cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_attach" {
  count      = var.deploy_eks ? 1 : 0
  role       = aws_iam_role.karpenter_controller[0].name
  policy_arn = aws_iam_policy.karpenter_controller[0].arn
}

# Helm Release for Karpenter Controller
resource "helm_release" "karpenter" {
  count            = var.deploy_eks ? 1 : 0
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  namespace        = "karpenter"
  version          = "1.2.1"
  create_namespace = true
  wait             = false

  values = [
    <<EOF
logLevel: info
dnsPolicy: Default
affinity: {}
#tolerations:
#  - operator: Exists
controller:
  env:
    - name: AWS_REGION
      value: ${var.aws_region}
livenessProbe:
  timeoutSeconds: 60
  initialDelaySeconds: 60
readinessProbe:
  timeoutSeconds: 60
  initialDelaySeconds: 30
settings:
  clusterName: ${var.eks_cluster_name}
  clusterEndpoint: ${aws_eks_cluster.main[0].endpoint}
serviceAccount:
  create: true
  name: karpenter
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.karpenter_controller[0].arn}
EOF
  ]

  depends_on = [
    aws_eks_node_group.default
  ]
}

# Deploy default Karpenter NodePool and EC2NodeClass CRDs via local Helm chart
resource "helm_release" "karpenter_defaults" {
  count     = var.deploy_eks ? 1 : 0
  name      = "karpenter-defaults"
  chart     = "${path.module}/charts/karpenter-defaults"
  namespace = "karpenter"
  wait      = false

  set {
    name  = "nodeRoleName"
    value = aws_iam_role.eks_node.name
  }
  set {
    name  = "subnetId"
    value = local.private_subnets[0]
  }
  set {
    name  = "securityGroupId"
    value = aws_eks_cluster.main[0].vpc_config[0].cluster_security_group_id
  }
  set {
    name  = "region"
    value = var.aws_region
  }

  depends_on = [helm_release.karpenter]
}
