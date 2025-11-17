output "otel_alb_security_group_id" {
  description = "OTel ALB security group ID"
  value       = aws_security_group.otel_alb.id
}

output "otel_security_group_id" {
  description = "OTel Collector security group ID"
  value       = aws_security_group.otel.id
}

output "grafana_alb_security_group_id" {
  description = "Grafana ALB security group ID"
  value       = aws_security_group.grafana_alb.id
}

output "grafana_security_group_id" {
  description = "Grafana security group ID"
  value       = aws_security_group.grafana.id
}

output "efs_security_group_id" {
  description = "EFS security group ID (if enabled)"
  value       = var.enable_efs ? aws_security_group.efs[0].id : null
}
