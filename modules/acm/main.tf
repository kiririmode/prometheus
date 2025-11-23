# ------------------------------------------------------------------------------
# ACM モジュール - ワイルドカードSSL/TLS証明書
# ------------------------------------------------------------------------------

# ワイルドカード証明書の作成
resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"

  # ベースドメインも含める（オプション）
  subject_alternative_names = [var.domain_name]

  tags = merge(var.tags, {
    Name = "wildcard.${var.domain_name}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# DNS検証用のRoute53レコード作成
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

# 証明書の検証完了を待機
resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
