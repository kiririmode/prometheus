output "task_definition_arn" {
  description = "OTel Collector task definition ARN"
  value       = aws_ecs_task_definition.otel.arn
}

output "service_name" {
  description = "OTel Collector service name"
  value       = aws_ecs_service.otel.name
}

output "service_id" {
  description = "OTel Collector service ID"
  value       = aws_ecs_service.otel.id
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.otel.name
}
