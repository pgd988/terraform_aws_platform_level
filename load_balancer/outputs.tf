output "alb_arn" {
  value = var.deploy_alb ? aws_lb.main[0].arn : null
}

output "default_tg_arn" {
  value = var.deploy_alb ? aws_lb_target_group.default_nginx[0].arn : null
}

output "nlb_static_ips" {
  description = "Static external Elastic IPs attached to the NLB entrypoint"
  value       = var.deploy_alb ? aws_eip.nlb[*].public_ip : []
}
