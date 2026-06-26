locals {
  public_subnets = split(",", data.aws_ssm_parameter.public_subnets.value)
}

# Generate a self-signed certificate
resource "tls_private_key" "alb_cert" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_cert" {
  private_key_pem = tls_private_key.alb_cert.private_key_pem

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
  private_key      = tls_private_key.alb_cert.private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert.cert_pem
}

# Load Balancer
resource "aws_lb" "main" {
  name               = "platform-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_ssm_parameter.alb_sg.value]
  subnets            = local.public_subnets
}

# Target Group for EKS Default NGINX Sink
resource "aws_lb_target_group" "default_nginx" {
  name        = "platform-default-nginx-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  target_type = "ip"
}

# Export Target Group ARN via SSM
resource "aws_ssm_parameter" "default_tg_arn" {
  name  = "/platform/alb/default_tg_arn"
  type  = "String"
  value = aws_lb_target_group.default_nginx.arn
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.alb_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default_nginx.arn
  }
}
