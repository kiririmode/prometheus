# Dev環境用変数定義

variable "project_name" {
  description = "リソース命名用のプロジェクト名"
  type        = string
  default     = "prometheus"
}

variable "environment" {
  description = "環境名 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "インフラストラクチャの所有者"
  type        = string
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

# ネットワーク変数
variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDRブロック"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットのCIDRブロック"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "サブネット用のアベイラビリティゾーン"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "single_nat_gateway" {
  description = "コスト最適化のため単一NAT Gateway使用（dev）、HA用に複数使用（prod）"
  type        = bool
  default     = true
}

# ECS変数
variable "enable_fargate_spot" {
  description = "コスト最適化のためFargate Spot使用（dev）、安定性のためFargate使用（prod）"
  type        = bool
  default     = true
}

variable "otel_cpu" {
  description = "OTel CollectorタスクのCPUユニット（256 = 0.25 vCPU, 512 = 0.5 vCPU）"
  type        = number
  default     = 512
}

variable "otel_memory" {
  description = "OTel Collectorタスクのメモリ（MB）"
  type        = number
  default     = 1024
}

variable "otel_desired_count" {
  description = "OTel Collectorタスクの希望数"
  type        = number
  default     = 1
}

variable "grafana_cpu" {
  description = "GrafanaタスクのCPUユニット（256 = 0.25 vCPU）"
  type        = number
  default     = 256
}

variable "grafana_memory" {
  description = "Grafanaタスクのメモリ（MB）"
  type        = number
  default     = 512
}

variable "grafana_admin_password" {
  description = "Grafana管理者パスワード"
  type        = string
  sensitive   = true
}

variable "enable_grafana_efs" {
  description = "Grafanaデータ永続化用EFSを有効化（Dashboards as Codeアプローチの場合はfalse）"
  type        = bool
  default     = false
}

# AMP変数
variable "amp_retention_days" {
  description = "AWS Managed Prometheusのデータ保持期間（日）"
  type        = number
  default     = 30
}

# CloudWatch Logs
variable "log_retention_days" {
  description = "CloudWatch Logsの保持期間（日）"
  type        = number
  default     = 7
}

# セキュリティ
variable "allowed_cidr_blocks" {
  description = "OTel Collector ALBへのアクセスを許可するCIDRブロック（Claude Code用）"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "grafana_allowed_cidr_blocks" {
  description = "Grafana ALBへのアクセスを許可するCIDRブロック（運用者用）"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# タグ
variable "additional_tags" {
  description = "全リソースに適用する追加タグ"
  type        = map(string)
  default     = {}
}
