variable "project_name" {
  description = "リソース命名用のプロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev, staging, prod)"
  type        = string
}

variable "otel_collector_config" {
  description = "OTel Collector設定ファイルの内容（YAML形式）"
  type        = string
}

variable "grafana_datasources_config" {
  description = "Grafanaデータソース設定の内容（YAML形式）"
  type        = string
}

variable "grafana_dashboards_config" {
  description = "Grafanaダッシュボードプロバイダー設定の内容（YAML形式）"
  type        = string
}

variable "grafana_sample_dashboard" {
  description = "Grafanaサンプルダッシュボードの内容（JSON形式）"
  type        = string
}

variable "tags" {
  description = "全リソースに適用する共通タグ"
  type        = map(string)
  default     = {}
}
