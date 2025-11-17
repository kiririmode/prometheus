# AWS Managed Prometheus Workspace
resource "aws_prometheus_workspace" "main" {
  alias = "${var.project_name}-${var.environment}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-amp-workspace"
    }
  )
}

# Logging Configuration (Optional)
resource "aws_prometheus_workspace_logging_configuration" "main" {
  count         = var.enable_logging ? 1 : 0
  workspace_id  = aws_prometheus_workspace.main.id
  log_group_arn = "${aws_cloudwatch_log_group.amp_logs[0].arn}:*"
}

resource "aws_cloudwatch_log_group" "amp_logs" {
  count             = var.enable_logging ? 1 : 0
  name              = "/aws/prometheus/${var.project_name}-${var.environment}"
  retention_in_days = var.amp_retention_days

  tags = var.tags
}
