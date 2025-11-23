# ------------------------------------------------------------------------------
# ACM モジュール - 出力定義
# ------------------------------------------------------------------------------

output "certificate_arn" {
  description = "検証済みACM証明書のARN"
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}

output "certificate_domain_name" {
  description = "証明書のドメイン名"
  value       = aws_acm_certificate.wildcard.domain_name
}
