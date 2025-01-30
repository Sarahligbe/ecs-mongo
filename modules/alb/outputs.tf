output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_arn_suffix" {
  value = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "alb_tg_arn_suffix" {
  value = aws_lb_target_group.main.arn_suffix
}