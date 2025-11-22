# Dev環境用ローカル変数

locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = var.owner
    },
    var.additional_tags
  )
}
