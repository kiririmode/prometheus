# 設定ファイル保存用S3バケット
# OTel CollectorとGrafanaの設定ファイルを保存する

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21.0"
    }
  }
}

resource "aws_s3_bucket" "config" {
  bucket = "${var.project_name}-${var.environment}-config-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# バケットのバージョニング有効化
resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

# サーバーサイド暗号化
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# パブリックアクセスブロック
resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# OTel Collector設定ファイルをアップロード
resource "aws_s3_object" "otel_config" {
  bucket       = aws_s3_bucket.config.id
  key          = "otel-collector/config.yaml"
  content      = var.otel_collector_config
  content_type = "application/x-yaml"

  tags = var.tags
}

# Grafana データソース設定をアップロード
resource "aws_s3_object" "grafana_datasources" {
  bucket       = aws_s3_bucket.config.id
  key          = "grafana/provisioning/datasources/datasources.yaml"
  content      = var.grafana_datasources_config
  content_type = "application/x-yaml"

  tags = var.tags
}

# Grafana ダッシュボードプロバイダー設定をアップロード
resource "aws_s3_object" "grafana_dashboards_provider" {
  bucket       = aws_s3_bucket.config.id
  key          = "grafana/provisioning/dashboards/dashboards.yaml"
  content      = var.grafana_dashboards_config
  content_type = "application/x-yaml"

  tags = var.tags
}

# サンプルダッシュボードをアップロード
resource "aws_s3_object" "grafana_sample_dashboard" {
  bucket       = aws_s3_bucket.config.id
  key          = "grafana/provisioning/dashboards/default/sample-dashboard.json"
  content      = var.grafana_sample_dashboard
  content_type = "application/json"

  tags = var.tags
}
