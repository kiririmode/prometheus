# ------------------------------------------------------------------------------
# DNS モジュール - Route53 Aliasレコード
# ------------------------------------------------------------------------------

# OTel Collector用サブドメイン
resource "aws_route53_record" "otel" {
  zone_id = var.hosted_zone_id
  name    = "${var.otel_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.otel_alb_dns_name
    zone_id                = var.otel_alb_zone_id
    evaluate_target_health = true
  }
}

# Grafana用サブドメイン
resource "aws_route53_record" "grafana" {
  zone_id = var.hosted_zone_id
  name    = "${var.grafana_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.grafana_alb_dns_name
    zone_id                = var.grafana_alb_zone_id
    evaluate_target_health = true
  }
}
