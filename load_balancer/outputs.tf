output "alb_arn" {
  value = aws_lb.main.arn
}

output "default_tg_arn" {
  value = aws_lb_target_group.default_nginx.arn
}
