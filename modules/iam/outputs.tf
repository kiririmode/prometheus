output "ecs_task_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "ECS Task Execution Role name"
  value       = aws_iam_role.ecs_task_execution.name
}

output "otel_task_role_arn" {
  description = "OTel Collector Task Role ARN"
  value       = aws_iam_role.otel_task.arn
}

output "otel_task_role_name" {
  description = "OTel Collector Task Role name"
  value       = aws_iam_role.otel_task.name
}

output "grafana_task_role_arn" {
  description = "Grafana Task Role ARN"
  value       = aws_iam_role.grafana_task.arn
}

output "grafana_task_role_name" {
  description = "Grafana Task Role name"
  value       = aws_iam_role.grafana_task.name
}
