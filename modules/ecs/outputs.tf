output "service_name" {
  value = aws_ecs_service.app_service.name
}

output "ecs_role_arn" {
    value = aws_iam_role.ecs_task_execution_role.arn
}