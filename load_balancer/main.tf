locals {
  public_subnets    = split(",", data.aws_ssm_parameter.public_subnets.value)
  private_subnets   = split(",", data.aws_ssm_parameter.private_subnets.value)
  cloudflare_policy = jsondecode(file("${path.module}/policies/cloudflare_nlb_policy.json"))
}

# Generate a self-signed certificate
resource "tls_private_key" "alb_cert" {
  count     = var.deploy_alb ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_cert" {
  count           = var.deploy_alb ? 1 : 0
  private_key_pem = tls_private_key.alb_cert[0].private_key_pem

  subject {
    common_name  = "platform.internal"
    organization = "Platform Team"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb_cert" {
  count            = var.deploy_alb ? 1 : 0
  private_key      = tls_private_key.alb_cert[0].private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert[0].cert_pem
}

# ==============================================================================
# Security Groups (Zero-Trust Locking Boundaries)
# ==============================================================================

# 1. NLB Security Group allowing ingress strictly from Cloudflare AS13335
resource "aws_security_group" "nlb_cloudflare" {
  count       = var.deploy_alb ? 1 : 0
  name        = "platform-nlb-cloudflare-sg"
  description = "Security policy allowing ingress strictly from Cloudflare AS13335 CIDRs"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  ingress {
    description = "Allow HTTPS (443) from Cloudflare AS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.cloudflare_policy.AllowedCIDRs
  }

  ingress {
    description = "Allow HTTP (80) from Cloudflare AS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.cloudflare_policy.AllowedCIDRs
  }

  egress {
    description = "Allow traffic forward to internal tiers"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  lifecycle {
    prevent_destroy = false
  }
}

# 2. ALB Security Group allowing ingress strictly from NLB Security Group
resource "aws_security_group" "alb_locked" {
  count       = var.deploy_alb ? 1 : 0
  name        = "platform-alb-locked-sg"
  description = "Zero-trust security boundary allowing ingress strictly from NLB"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  ingress {
    description     = "Allow HTTPS (443) from NLB Security Group"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb_cloudflare[0].id]
  }

  ingress {
    description     = "Allow HTTP (80) from NLB Security Group"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb_cloudflare[0].id]
  }

  egress {
    description = "Allow application traffic forward to EKS / private tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  lifecycle {
    prevent_destroy = false
  }
}



# ==============================================================================
# Application Load Balancer (Private Tier)
# ==============================================================================

resource "aws_lb" "main" {
  count                      = var.deploy_alb ? 1 : 0
  name                       = "platform-alb"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_locked[0].id]
  subnets                    = local.private_subnets
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
}

# Target Group for EKS Default NGINX Sink
resource "aws_lb_target_group" "default_nginx" {
  count       = var.deploy_alb ? 1 : 0
  name        = "platform-default-nginx-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  target_type = "ip"
}



# HTTPS Listener
resource "aws_lb_listener" "https" {
  count             = var.deploy_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.alb_cert[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default_nginx[0].arn
  }
}

# HTTP Listener (Redirects to HTTPS)
resource "aws_lb_listener" "http" {
  count             = var.deploy_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ==============================================================================
# Static External IP Bridge (NLB Chaining to ALB - Public Tier)
# ==============================================================================

# 1. Allocate Static Elastic IPs for NLB (Protected from destroy)
resource "aws_eip" "nlb" {
  count  = var.deploy_alb ? var.public_subnet_count : 0
  domain = "vpc"

  tags = {
    Name = "platform-static-entrypoint-ip-${count.index}"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# 2. Create Network Load Balancer with Static EIPs & Cloudflare Security Policy
resource "aws_lb" "nlb" {
  count                      = var.deploy_alb ? 1 : 0
  name                       = "platform-static-nlb"
  load_balancer_type         = "network"
  security_groups            = [aws_security_group.nlb_cloudflare[0].id]
  enable_deletion_protection = var.deletion_protection

  dynamic "subnet_mapping" {
    for_each = range(var.public_subnet_count)
    content {
      subnet_id     = local.public_subnets[subnet_mapping.value]
      allocation_id = aws_eip.nlb[subnet_mapping.value].id
    }
  }
}

# 3. Target Groups registering ALB directly
resource "aws_lb_target_group" "nlb_to_alb_443" {
  count       = var.deploy_alb ? 1 : 0
  name        = "nlb-to-alb-443-tg"
  port        = 443
  protocol    = "TCP"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  target_type = "alb"
}

resource "aws_lb_target_group" "nlb_to_alb_80" {
  count       = var.deploy_alb ? 1 : 0
  name        = "nlb-to-alb-80-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  target_type = "alb"
}

# 4. Attach ALB to NLB Target Groups
resource "aws_lb_target_group_attachment" "alb_443" {
  count            = var.deploy_alb ? 1 : 0
  target_group_arn = aws_lb_target_group.nlb_to_alb_443[0].arn
  target_id        = aws_lb.main[0].arn
  port             = 443

  depends_on = [
    aws_lb_listener.https
  ]
}

resource "aws_lb_target_group_attachment" "alb_80" {
  count            = var.deploy_alb ? 1 : 0
  target_group_arn = aws_lb_target_group.nlb_to_alb_80[0].arn
  target_id        = aws_lb.main[0].arn
  port             = 80

  depends_on = [
    aws_lb_listener.http
  ]
}

# 5. NLB TCP Listeners
resource "aws_lb_listener" "nlb_443" {
  count             = var.deploy_alb ? 1 : 0
  load_balancer_arn = aws_lb.nlb[0].arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_to_alb_443[0].arn
  }
}

resource "aws_lb_listener" "nlb_80" {
  count             = var.deploy_alb ? 1 : 0
  load_balancer_arn = aws_lb.nlb[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_to_alb_80[0].arn
  }
}

# Export Static External IPs via SSM
resource "aws_ssm_parameter" "nlb_static_ips" {
  count = var.deploy_alb ? 1 : 0
  name  = "/platform/alb/external_static_ips"
  type  = "StringList"
  value = join(",", aws_eip.nlb[*].public_ip)
}
