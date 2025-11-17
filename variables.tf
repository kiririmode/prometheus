variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "prometheus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# Network variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost optimization (dev) vs multiple for HA (prod)"
  type        = bool
  default     = true
}

# ECS variables
variable "enable_fargate_spot" {
  description = "Enable Fargate Spot for cost optimization (dev) vs Fargate for stability (prod)"
  type        = bool
  default     = true
}

variable "otel_cpu" {
  description = "CPU units for OTel Collector task (256 = 0.25 vCPU, 512 = 0.5 vCPU)"
  type        = number
  default     = 512
}

variable "otel_memory" {
  description = "Memory in MB for OTel Collector task"
  type        = number
  default     = 1024
}

variable "otel_desired_count" {
  description = "Desired number of OTel Collector tasks"
  type        = number
  default     = 1
}

variable "grafana_cpu" {
  description = "CPU units for Grafana task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "grafana_memory" {
  description = "Memory in MB for Grafana task"
  type        = number
  default     = 512
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}

variable "enable_grafana_efs" {
  description = "Enable EFS for Grafana data persistence (false for Dashboards as Code approach)"
  type        = bool
  default     = false
}

# AMP variables
variable "amp_retention_days" {
  description = "Data retention period in days for AWS Managed Prometheus"
  type        = number
  default     = 30
}

# CloudWatch Logs
variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

# Security
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access OTel Collector ALB (Claude Code)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "grafana_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Grafana ALB (operators)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
