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

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "otel_alb_security_group_id" {
  description = "Security group ID for OTel ALB"
  type        = string
}

variable "grafana_alb_security_group_id" {
  description = "Security group ID for Grafana ALB"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALBs"
  type        = bool
  default     = false
}

variable "use_https" {
  description = "Use HTTPS listeners (requires ACM certificates)"
  type        = bool
  default     = false
}

variable "otel_certificate_arn" {
  description = "ACM certificate ARN for OTel ALB HTTPS listener"
  type        = string
  default     = ""
}

variable "grafana_certificate_arn" {
  description = "ACM certificate ARN for Grafana ALB HTTPS listener"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
