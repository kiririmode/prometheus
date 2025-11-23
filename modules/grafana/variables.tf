variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "grafana_security_group_id" {
  description = "Security group ID for Grafana"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role ARN for ECS task"
  type        = string
}

variable "task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MB for ECS task"
  type        = number
  default     = 512
}

variable "admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_root_url" {
  description = "Grafana root URL"
  type        = string
  default     = "http://localhost:3000"
}

variable "alb_target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period"
  type        = number
  default     = 7
}

variable "grafana_version" {
  description = "Grafana version"
  type        = string
  default     = "latest"
}

variable "enable_efs" {
  description = "Enable EFS for data persistence"
  type        = bool
  default     = false
}

variable "efs_file_system_id" {
  description = "EFS file system ID (required if enable_efs is true)"
  type        = string
  default     = null
}

variable "grafana_provisioning_s3_prefix" {
  description = "Grafanaプロビジョニングファイルが保存されているS3プレフィックス（例: s3://bucket/grafana/provisioning/）"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
