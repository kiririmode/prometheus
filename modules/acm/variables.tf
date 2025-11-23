# ------------------------------------------------------------------------------
# ACM モジュール - 変数定義
# ------------------------------------------------------------------------------

variable "domain_name" {
  description = "ベースドメイン名（例: example.com）"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53ホストゾーンID"
  type        = string
}

variable "tags" {
  description = "リソースに付与するタグ"
  type        = map(string)
  default     = {}
}
