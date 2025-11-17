output "task_definition_arn" {
  description = "Grafana task definition ARN"
  value       = aws_ecs_task_definition.grafana.arn
}

output "service_name" {
  description = "Grafana service name"
  value       = aws_ecs_service.grafana.name
}

output "service_id" {
  description = "Grafana service ID"
  value       = aws_ecs_service.grafana.id
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.grafana.name
}
