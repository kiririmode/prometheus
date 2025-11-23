output "otel_alb_id" {
  description = "OTel ALB ID"
  value       = aws_lb.otel.id
}

output "otel_alb_arn" {
  description = "OTel ALB ARN"
  value       = aws_lb.otel.arn
}

output "otel_alb_dns_name" {
  description = "OTel ALB DNS name"
  value       = aws_lb.otel.dns_name
}

output "otel_target_group_arn" {
  description = "OTel target group ARN"
  value       = aws_lb_target_group.otel.arn
}

output "grafana_alb_id" {
  description = "Grafana ALB ID"
  value       = aws_lb.grafana.id
}

output "grafana_alb_arn" {
  description = "Grafana ALB ARN"
  value       = aws_lb.grafana.arn
}

output "grafana_alb_dns_name" {
  description = "Grafana ALB DNS name"
  value       = aws_lb.grafana.dns_name
}

output "grafana_target_group_arn" {
  description = "Grafana target group ARN"
  value       = aws_lb_target_group.grafana.arn
}

output "otel_alb_zone_id" {
  description = "OTel ALBのRoute53ホストゾーンID（Aliasレコード用）"
  value       = aws_lb.otel.zone_id
}

output "grafana_alb_zone_id" {
  description = "Grafana ALBのRoute53ホストゾーンID（Aliasレコード用）"
  value       = aws_lb.grafana.zone_id
}
