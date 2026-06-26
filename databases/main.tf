locals {
  private_subnets = split(",", data.aws_ssm_parameter.private_subnets.value)
}

# DynamoDB Template (Disabled by default)
resource "aws_dynamodb_table" "main" {
  count                       = var.deploy_dynamodb ? 1 : 0
  name                        = "platform-generic-table"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "id"
  deletion_protection_enabled = true

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "PlatformGenericTable"
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "redis" {
  name       = "platform-redis-subnet-group"
  subnet_ids = local.private_subnets
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "platform-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [data.aws_ssm_parameter.redis_sg.value]
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds" {
  count      = var.deploy_rds ? 1 : 0
  name       = "platform-rds-subnet-group"
  subnet_ids = local.private_subnets
}

# Custom Parameter Group for RDS PostgreSQL Flags
resource "aws_db_parameter_group" "rds" {
  count  = var.deploy_rds ? 1 : 0
  name   = "platform-rds-pg"
  family = var.rds_parameter_group_family

  dynamic "parameter" {
    for_each = var.rds_custom_parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }
}

# Relational Database Service (RDS)
resource "aws_db_instance" "main" {
  count                       = var.deploy_rds ? 1 : 0
  identifier                  = "platform-rds"
  engine                      = var.rds_engine
  engine_version              = var.rds_engine_version
  instance_class              = var.rds_instance_class
  allocated_storage           = var.rds_allocated_storage
  db_name                     = var.rds_db_name
  username                    = var.rds_username
  manage_master_user_password = true
  parameter_group_name        = aws_db_parameter_group.rds[0].name
  db_subnet_group_name        = aws_db_subnet_group.rds[0].name
  vpc_security_group_ids      = [data.aws_ssm_parameter.rds_sg.value]
  skip_final_snapshot         = false
  deletion_protection         = true
}

# Export RDS Endpoint via SSM
resource "aws_ssm_parameter" "rds_endpoint" {
  count = var.deploy_rds ? 1 : 0
  name  = "/platform/databases/rds_endpoint"
  type  = "String"
  value = aws_db_instance.main[0].endpoint
}
