locals {
  private_subnets = split(",", data.aws_ssm_parameter.private_subnets.value)
}

# DynamoDB Template (Disabled by default)
resource "aws_dynamodb_table" "main" {
  count        = var.deploy_dynamodb ? 1 : 0
  name         = "platform-generic-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

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
