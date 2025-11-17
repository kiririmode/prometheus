output "workspace_id" {
  description = "AMP workspace ID"
  value       = aws_prometheus_workspace.main.id
}

output "workspace_arn" {
  description = "AMP workspace ARN"
  value       = aws_prometheus_workspace.main.arn
}

output "query_endpoint" {
  description = "AMP query endpoint"
  value       = aws_prometheus_workspace.main.prometheus_endpoint
}

output "remote_write_endpoint" {
  description = "AMP remote write endpoint"
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
}
