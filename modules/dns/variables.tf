# ------------------------------------------------------------------------------
# DNS モジュール - 変数定義
# ------------------------------------------------------------------------------

variable "hosted_zone_id" {
  description = "Route53ホストゾーンID"
  type        = string
}

variable "domain_name" {
  description = "ベースドメイン名（例: example.com）"
  type        = string
}

variable "otel_subdomain" {
  description = "OTel Collector用サブドメイン"
  type        = string
  default     = "otel"
}

variable "grafana_subdomain" {
  description = "Grafana用サブドメイン"
  type        = string
  default     = "dashboard"
}

variable "otel_alb_dns_name" {
  description = "OTel ALBのDNS名"
  type        = string
}

variable "otel_alb_zone_id" {
  description = "OTel ALBのホストゾーンID"
  type        = string
}

variable "grafana_alb_dns_name" {
  description = "Grafana ALBのDNS名"
  type        = string
}

variable "grafana_alb_zone_id" {
  description = "Grafana ALBのホストゾーンID"
  type        = string
}
