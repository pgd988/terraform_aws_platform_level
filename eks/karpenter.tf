# IAM Role for EKS Fargate Pod Execution (required to run Karpenter controller without pre-existing EC2 nodes)
resource "aws_iam_role" "fargate_pod_execution_role" {
  count = var.deploy_eks ? 1 : 0
  name  = "${var.eks_cluster_name}-fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution" {
  count      = var.deploy_eks ? 1 : 0
  role       = aws_iam_role.fargate_pod_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# Fargate Profile specifically for Karpenter namespace to avoid 0-node deadlock
resource "aws_eks_fargate_profile" "karpenter" {
  count                  = var.deploy_eks ? 1 : 0
  cluster_name           = aws_eks_cluster.main[0].name
  fargate_profile_name   = "karpenter"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role[0].arn
  subnet_ids             = local.private_subnets

  selector {
    namespace = "karpenter"
  }
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
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory",
          "ssm:GetParameter"
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

# IAM Role for Karpenter Controller (using EKS Pod Identity)
resource "aws_iam_role" "karpenter_controller" {
  count = var.deploy_eks ? 1 : 0
  name  = "${var.eks_cluster_name}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole", "sts:TagSession"]
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:podidentityassociation/${var.eks_cluster_name}/*"
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

resource "kubernetes_namespace" "karpenter" {
  count = var.deploy_eks ? 1 : 0
  metadata {
    name = "karpenter"
  }
}

resource "kubernetes_service_account" "karpenter" {
  count = var.deploy_eks ? 1 : 0
  metadata {
    name      = "karpenter"
    namespace = "karpenter"
  }
  depends_on = [kubernetes_namespace.karpenter]
}

resource "aws_eks_pod_identity_association" "karpenter" {
  count           = var.deploy_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller[0].arn

  depends_on = [kubernetes_service_account.karpenter]
}

# Optional Knative logging config to silence LOGGING_CONFIGMAP_NOT_FOUND notices
resource "kubernetes_config_map" "karpenter_logging" {
  count = var.deploy_eks ? 1 : 0
  metadata {
    name      = "aws-logging"
    namespace = "karpenter"
  }
  data = {
    "loglevel.controller" = "info"
    "loglevel.webhook"    = "error"
  }
  depends_on = [kubernetes_namespace.karpenter]
}

# Helm Release for Karpenter Controller
resource "helm_release" "karpenter" {
  count            = var.deploy_eks ? 1 : 0
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  namespace        = "karpenter"
  version          = "1.2.1"
  create_namespace = false

  values = [
    <<EOF
logLevel: info
dnsPolicy: Default
controller:
  resources:
    requests:
      cpu: 1
      memory: 1Gi
    limits:
      cpu: 1
      memory: 1Gi
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
  create: false
  name: karpenter
EOF
  ]

  depends_on = [
    aws_eks_fargate_profile.karpenter,
    aws_eks_pod_identity_association.karpenter,
    kubernetes_config_map.karpenter_logging
  ]
}

# Deploy default Karpenter NodePool and EC2NodeClass CRDs via local Helm chart
resource "helm_release" "karpenter_defaults" {
  count     = var.deploy_eks ? 1 : 0
  name      = "karpenter-defaults"
  chart     = "${path.module}/charts/karpenter-defaults"
  namespace = "karpenter"

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

  depends_on = [helm_release.karpenter]
}
