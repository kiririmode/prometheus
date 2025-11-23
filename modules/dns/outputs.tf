# ------------------------------------------------------------------------------
# DNS モジュール - 出力定義
# ------------------------------------------------------------------------------

output "otel_fqdn" {
  description = "OTel CollectorのFQDN"
  value       = aws_route53_record.otel.fqdn
}

output "grafana_fqdn" {
  description = "GrafanaのFQDN"
  value       = aws_route53_record.grafana.fqdn
}

output "otel_url" {
  description = "OTel CollectorのHTTPS URL"
  value       = "https://${aws_route53_record.otel.fqdn}"
}

output "grafana_url" {
  description = "GrafanaのHTTPS URL"
  value       = "https://${aws_route53_record.grafana.fqdn}"
}
