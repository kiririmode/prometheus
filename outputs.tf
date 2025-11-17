output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "otel_alb_dns" {
  description = "DNS name of OTel Collector ALB"
  value       = module.alb.otel_alb_dns_name
}

output "otel_alb_url" {
  description = "HTTPS URL for OTel Collector"
  value       = "https://${module.alb.otel_alb_dns_name}"
}

output "grafana_alb_dns" {
  description = "DNS name of Grafana ALB"
  value       = module.alb.grafana_alb_dns_name
}

output "grafana_alb_url" {
  description = "HTTPS URL for Grafana"
  value       = "https://${module.alb.grafana_alb_dns_name}"
}

output "amp_workspace_id" {
  description = "AWS Managed Prometheus workspace ID"
  value       = module.amp.workspace_id
}

output "amp_workspace_arn" {
  description = "AWS Managed Prometheus workspace ARN"
  value       = module.amp.workspace_arn
}

output "amp_query_endpoint" {
  description = "AWS Managed Prometheus query endpoint"
  value       = module.amp.query_endpoint
}

output "amp_remote_write_endpoint" {
  description = "AWS Managed Prometheus remote write endpoint"
  value       = module.amp.remote_write_endpoint
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "grafana_admin_username" {
  description = "Grafana admin username"
  value       = "admin"
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "efs_file_system_id" {
  description = "EFS file system ID (if enabled)"
  value       = var.enable_grafana_efs ? module.efs[0].file_system_id : null
}
