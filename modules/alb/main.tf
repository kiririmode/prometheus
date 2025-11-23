# Application Load Balancer for OTel Collector
resource "aws_lb" "otel" {
  name               = "${var.project_name}-${var.environment}-otel-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.otel_alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-otel-alb"
    }
  )
}

# Target Group for OTel Collector
resource "aws_lb_target_group" "otel" {
  name        = "${var.project_name}-${var.environment}-otel-tg"
  port        = 4318
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200,404"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-otel-tg"
    }
  )
}

# HTTP Listener for OTel (HTTPSが無効な場合はターゲットグループに直接転送)
resource "aws_lb_listener" "otel_http" {
  count             = var.use_https ? 0 : 1
  load_balancer_arn = aws_lb.otel.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.otel.arn
  }
}

# HTTP Listener for OTel (HTTPSが有効な場合はHTTPSにリダイレクト)
resource "aws_lb_listener" "otel_http_redirect" {
  count             = var.use_https ? 1 : 0
  load_balancer_arn = aws_lb.otel.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener for OTel (self-signed cert for dev, use ACM for prod)
resource "aws_lb_listener" "otel_https" {
  count             = var.use_https ? 1 : 0
  load_balancer_arn = aws_lb.otel.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.otel_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.otel.arn
  }
}

# Application Load Balancer for Grafana
resource "aws_lb" "grafana" {
  name               = "${var.project_name}-${var.environment}-grafana-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.grafana_alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-alb"
    }
  )
}

# Target Group for Grafana
resource "aws_lb_target_group" "grafana" {
  name        = "${var.project_name}-${var.environment}-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-tg"
    }
  )
}

# HTTP Listener for Grafana (HTTPSが無効な場合はターゲットグループに直接転送)
resource "aws_lb_listener" "grafana_http" {
  count             = var.use_https ? 0 : 1
  load_balancer_arn = aws_lb.grafana.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

# HTTP Listener for Grafana (HTTPSが有効な場合はHTTPSにリダイレクト)
resource "aws_lb_listener" "grafana_http_redirect" {
  count             = var.use_https ? 1 : 0
  load_balancer_arn = aws_lb.grafana.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener for Grafana (self-signed cert for dev, use ACM for prod)
resource "aws_lb_listener" "grafana_https" {
  count             = var.use_https ? 1 : 0
  load_balancer_arn = aws_lb.grafana.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.grafana_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}
