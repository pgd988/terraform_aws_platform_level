output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "rds_endpoint" {
  value = var.deploy_rds ? aws_db_instance.main[0].endpoint : null
}

output "rds_secret_arn" {
  description = "Secrets Manager Secret ARN containing generated master user credentials"
  value       = var.deploy_rds ? aws_db_instance.main[0].master_user_secret[0].secret_arn : null
}
