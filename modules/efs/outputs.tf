output "file_system_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.grafana.id
}

output "file_system_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.grafana.arn
}

output "file_system_dns_name" {
  description = "EFS file system DNS name"
  value       = aws_efs_file_system.grafana.dns_name
}

output "access_point_id" {
  description = "EFS access point ID for Grafana"
  value       = aws_efs_access_point.grafana.id
}

output "access_point_arn" {
  description = "EFS access point ARN for Grafana"
  value       = aws_efs_access_point.grafana.arn
}

output "mount_target_ids" {
  description = "List of EFS mount target IDs"
  value       = aws_efs_mount_target.grafana[*].id
}
