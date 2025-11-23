output "bucket_id" {
  description = "設定ファイル保存用S3バケットID"
  value       = aws_s3_bucket.config.id
}

output "bucket_arn" {
  description = "設定ファイル保存用S3バケットARN"
  value       = aws_s3_bucket.config.arn
}

output "otel_config_s3_uri" {
  description = "OTel Collector設定ファイルのS3 URI"
  value       = "s3://${aws_s3_bucket.config.id}.s3.${data.aws_region.current.name}.amazonaws.com/${aws_s3_object.otel_config.key}"
}

output "grafana_provisioning_s3_prefix" {
  description = "Grafanaプロビジョニングファイルが保存されているS3プレフィックス"
  value       = "s3://${aws_s3_bucket.config.id}/grafana/provisioning/"
}
