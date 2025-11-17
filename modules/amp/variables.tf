variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "amp_retention_days" {
  description = "CloudWatch Logs retention period for AMP logs"
  type        = number
  default     = 30
}

variable "enable_logging" {
  description = "Enable AMP workspace logging"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
