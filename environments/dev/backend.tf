# Terraform State Backend設定
# Terraform 1.10以降ではS3ネイティブロック機能によりDynamoDBテーブル不要
# バケットは scripts/setup-backend.sh で作成
terraform {
  backend "s3" {
    bucket       = "visualization-otel-tfstate-dev"
    key          = "dev/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true # S3ネイティブロック（Terraform 1.10+）
  }
}
