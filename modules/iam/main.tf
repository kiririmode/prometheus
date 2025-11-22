# IAM Roles for ECS Tasks
# OTel Collector、Grafana用のTask RoleとExecution Roleを定義

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21.0"
    }
  }
}

# ECS Task Execution Role (Common for all ECS tasks)
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager and SSM Parameter Store access
resource "aws_iam_role_policy" "ecs_task_execution_additional" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-additional"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters",
          "ssm:GetParameter",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# OTel Collector Task Role
resource "aws_iam_role" "otel_task" {
  name = "${var.project_name}-${var.environment}-otel-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "otel_task" {
  name = "${var.project_name}-${var.environment}-otel-task-policy"
  role = aws_iam_role.otel_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite"
        ]
        Resource = var.amp_workspace_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}-${var.environment}-otel-collector:*"
      }
      ],
      # S3から設定ファイルを読み取る権限（config_bucket_arnが指定されている場合のみ）
      var.config_bucket_arn != "" ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion"
          ]
          Resource = "${var.config_bucket_arn}/*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = var.config_bucket_arn
        }
      ] : []
    )
  })
}

# Grafana Task Role
resource "aws_iam_role" "grafana_task" {
  name = "${var.project_name}-${var.environment}-grafana-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "grafana_task" {
  name = "${var.project_name}-${var.environment}-grafana-task-policy"
  role = aws_iam_role.grafana_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "aps:QueryMetrics",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = var.amp_workspace_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}-${var.environment}-grafana:*"
      }
      ],
      # S3から設定ファイルを読み取る権限（config_bucket_arnが指定されている場合のみ）
      var.config_bucket_arn != "" ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion"
          ]
          Resource = "${var.config_bucket_arn}/*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = var.config_bucket_arn
        }
      ] : []
    )
  })
}
