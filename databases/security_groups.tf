# ==============================================================================
# Security Groups
# ==============================================================================

resource "aws_security_group" "redis" {
  name        = "platform-redis-sg"
  description = "Allow inbound Redis traffic from private VPC tiers"
  vpc_id      = local.vpc_id

  ingress {
    description = "Redis port from private tiers"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_security_group" "rds" {
  count       = var.deploy_rds ? 1 : 0
  name        = "platform-rds-sg"
  description = "Allow inbound PostgreSQL traffic from private VPC tiers"
  vpc_id      = local.vpc_id

  ingress {
    description = "PostgreSQL port from private tiers"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    prevent_destroy = false
  }
}
