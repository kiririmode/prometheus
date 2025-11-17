variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access OTel Collector ALB"
  type        = list(string)
}

variable "grafana_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Grafana ALB"
  type        = list(string)
}

variable "enable_efs" {
  description = "Enable EFS security group"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
