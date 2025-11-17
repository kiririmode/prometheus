terraform {
  backend "s3" {
    bucket         = "prometheus-terraform-state-dev"
    key            = "terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "prometheus-terraform-lock"
  }
}
