# Dev環境用出力定義

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "otel_alb_dns" {
  description = "OTel Collector ALBのDNS名"
  value       = module.alb.otel_alb_dns_name
}

output "otel_alb_url" {
  description = "OTel CollectorのHTTPS URL"
  value       = "https://${module.alb.otel_alb_dns_name}"
}

output "grafana_alb_dns" {
  description = "Grafana ALBのDNS名"
  value       = module.alb.grafana_alb_dns_name
}

output "grafana_alb_url" {
  description = "GrafanaのHTTPS URL"
  value       = "https://${module.alb.grafana_alb_dns_name}"
}

output "amp_workspace_id" {
  description = "AWS Managed Prometheus Workspace ID"
  value       = module.amp.workspace_id
}

output "amp_workspace_arn" {
  description = "AWS Managed Prometheus Workspace ARN"
  value       = module.amp.workspace_arn
}

output "amp_query_endpoint" {
  description = "AWS Managed Prometheusクエリエンドポイント"
  value       = module.amp.query_endpoint
}

output "amp_remote_write_endpoint" {
  description = "AWS Managed Prometheus Remote Writeエンドポイント"
  value       = module.amp.remote_write_endpoint
}

output "ecs_cluster_name" {
  description = "ECSクラスター名"
  value       = module.ecs_cluster.cluster_name
}

output "grafana_admin_username" {
  description = "Grafana管理者ユーザー名"
  value       = "admin"
}

output "grafana_admin_password" {
  description = "Grafana管理者パスワード"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "efs_file_system_id" {
  description = "EFSファイルシステムID（有効化時）"
  value       = var.enable_grafana_efs ? module.efs[0].file_system_id : null
}

output "config_bucket_id" {
  description = "設定ファイル保存用S3バケットID"
  value       = module.config_storage.bucket_id
}

output "otel_config_s3_uri" {
  description = "OTel Collector設定ファイルのS3 URI"
  value       = module.config_storage.otel_config_s3_uri
}
