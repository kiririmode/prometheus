# ALB Security Group for OTel Collector
resource "aws_security_group" "otel_alb" {
  name        = "${var.project_name}-${var.environment}-otel-alb-sg"
  description = "Security group for OTel Collector ALB"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-otel-alb-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "otel_alb_https" {
  count = length(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.otel_alb.id
  description       = "Allow HTTPS from Claude Code"

  cidr_ipv4   = var.allowed_cidr_blocks[count.index]
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  tags = {
    Name = "allow-https-from-claude-code"
  }
}

resource "aws_vpc_security_group_egress_rule" "otel_alb_to_otel" {
  security_group_id = aws_security_group.otel_alb.id
  description       = "Allow traffic to OTel Collector"

  referenced_security_group_id = aws_security_group.otel.id
  from_port                    = 4318
  to_port                      = 4318
  ip_protocol                  = "tcp"

  tags = {
    Name = "allow-to-otel-collector"
  }
}

# OTel Collector Security Group
resource "aws_security_group" "otel" {
  name        = "${var.project_name}-${var.environment}-otel-sg"
  description = "Security group for OTel Collector"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-otel-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "otel_from_alb" {
  security_group_id = aws_security_group.otel.id
  description       = "Allow traffic from ALB"

  referenced_security_group_id = aws_security_group.otel_alb.id
  from_port                    = 4318
  to_port                      = 4318
  ip_protocol                  = "tcp"

  tags = {
    Name = "allow-from-otel-alb"
  }
}

resource "aws_vpc_security_group_egress_rule" "otel_https" {
  security_group_id = aws_security_group.otel.id
  description       = "Allow HTTPS to AMP and VPC Endpoints"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  tags = {
    Name = "allow-https-outbound"
  }
}

# ALB Security Group for Grafana
resource "aws_security_group" "grafana_alb" {
  name        = "${var.project_name}-${var.environment}-grafana-alb-sg"
  description = "Security group for Grafana ALB"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-alb-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "grafana_alb_https" {
  count = length(var.grafana_allowed_cidr_blocks)

  security_group_id = aws_security_group.grafana_alb.id
  description       = "Allow HTTPS from operators"

  cidr_ipv4   = var.grafana_allowed_cidr_blocks[count.index]
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  tags = {
    Name = "allow-https-from-operators"
  }
}

resource "aws_vpc_security_group_egress_rule" "grafana_alb_to_grafana" {
  security_group_id = aws_security_group.grafana_alb.id
  description       = "Allow traffic to Grafana"

  referenced_security_group_id = aws_security_group.grafana.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"

  tags = {
    Name = "allow-to-grafana"
  }
}

# Grafana Security Group
resource "aws_security_group" "grafana" {
  name        = "${var.project_name}-${var.environment}-grafana-sg"
  description = "Security group for Grafana"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "grafana_from_alb" {
  security_group_id = aws_security_group.grafana.id
  description       = "Allow traffic from ALB"

  referenced_security_group_id = aws_security_group.grafana_alb.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"

  tags = {
    Name = "allow-from-grafana-alb"
  }
}

resource "aws_vpc_security_group_egress_rule" "grafana_https" {
  security_group_id = aws_security_group.grafana.id
  description       = "Allow HTTPS to AMP and VPC Endpoints"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  tags = {
    Name = "allow-https-outbound"
  }
}

resource "aws_vpc_security_group_egress_rule" "grafana_to_efs" {
  count = var.enable_efs ? 1 : 0

  security_group_id = aws_security_group.grafana.id
  description       = "Allow NFS to EFS"

  referenced_security_group_id = aws_security_group.efs[0].id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"

  tags = {
    Name = "allow-to-efs"
  }
}

# EFS Security Group (Optional)
resource "aws_security_group" "efs" {
  count = var.enable_efs ? 1 : 0

  name        = "${var.project_name}-${var.environment}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-efs-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_grafana" {
  count = var.enable_efs ? 1 : 0

  security_group_id = aws_security_group.efs[0].id
  description       = "Allow NFS from Grafana"

  referenced_security_group_id = aws_security_group.grafana.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"

  tags = {
    Name = "allow-from-grafana"
  }
}
