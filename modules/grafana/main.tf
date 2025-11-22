# CloudWatch Log Group for Grafana
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.project_name}-${var.environment}-grafana"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# S3からプロビジョニング設定をダウンロードするかどうか
locals {
  use_s3_provisioning = var.grafana_provisioning_s3_prefix != "" && !var.enable_efs
}

# ECS Task Definition for Grafana
resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.project_name}-${var.environment}-grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  # EFS Volume (Optional)
  dynamic "volume" {
    for_each = var.enable_efs ? [1] : []
    content {
      name = "grafana-storage"

      efs_volume_configuration {
        file_system_id          = var.efs_file_system_id
        transit_encryption      = "ENABLED"
        transit_encryption_port = 2999
      }
    }
  }

  # S3からプロビジョニング設定をダウンロードする場合の共有ボリューム
  dynamic "volume" {
    for_each = local.use_s3_provisioning ? [1] : []
    content {
      name = "grafana-provisioning"
    }
  }

  container_definitions = jsonencode(concat(
    # initコンテナ: S3からプロビジョニング設定をダウンロード
    local.use_s3_provisioning ? [
      {
        name      = "init-provisioning"
        image     = "amazon/aws-cli:latest"
        essential = false

        # S3からプロビジョニングファイルをダウンロード
        command = [
          "sh", "-c",
          "aws s3 sync ${var.grafana_provisioning_s3_prefix} /provisioning/ && echo 'Provisioning files downloaded successfully'"
        ]

        environment = [
          {
            name  = "AWS_REGION"
            value = var.aws_region
          }
        ]

        mountPoints = [
          {
            sourceVolume  = "grafana-provisioning"
            containerPath = "/provisioning"
            readOnly      = false
          }
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
            "awslogs-region"        = var.aws_region
            "awslogs-stream-prefix" = "init"
          }
        }
      }
    ] : [],
    # メインコンテナ: Grafana
    [
      {
        name      = "grafana"
        image     = "grafana/grafana:${var.grafana_version}"
        essential = true

        # S3プロビジョニングを使用する場合、initコンテナの完了を待つ
        dependsOn = local.use_s3_provisioning ? [
          {
            containerName = "init-provisioning"
            condition     = "SUCCESS"
          }
        ] : []

        portMappings = [
          {
            containerPort = 3000
            protocol      = "tcp"
            name          = "grafana"
          }
        ]

        environment = concat([
          {
            name  = "GF_SERVER_ROOT_URL"
            value = var.grafana_root_url
          },
          {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.admin_password
          },
          {
            name  = "GF_AUTH_SIGV4_AUTH_ENABLED"
            value = "true"
          },
          {
            name  = "AWS_REGION"
            value = var.aws_region
          },
          {
            name  = "AWS_SDK_LOAD_CONFIG"
            value = "true"
          },
          {
            name  = "GF_INSTALL_PLUGINS"
            value = "grafana-amazonprometheus-datasource"
          }
          ],
          # S3プロビジョニングまたはEFSを使用しない場合のみプロビジョニングパスを設定
          local.use_s3_provisioning ? [
            {
              name  = "GF_PATHS_PROVISIONING"
              value = "/etc/grafana/provisioning"
            }
          ] : []
        )

        mountPoints = concat(
          # EFSマウント
          var.enable_efs ? [
            {
              sourceVolume  = "grafana-storage"
              containerPath = "/var/lib/grafana"
              readOnly      = false
            }
          ] : [],
          # S3からダウンロードしたプロビジョニング設定をマウント
          local.use_s3_provisioning ? [
            {
              sourceVolume  = "grafana-provisioning"
              containerPath = "/etc/grafana/provisioning"
              readOnly      = true
            }
          ] : []
        )

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
            "awslogs-region"        = var.aws_region
            "awslogs-stream-prefix" = "grafana"
          }
        }

        healthCheck = {
          command     = ["CMD-SHELL", "wget --spider -q http://localhost:3000/api/health || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 60
        }
      }
    ]
  ))

  tags = var.tags
}

# ECS Service for Grafana
resource "aws_ecs_service" "grafana" {
  name            = "${var.project_name}-${var.environment}-grafana-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.grafana_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "grafana"
    container_port   = 3000
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command = true

  tags = var.tags

  depends_on = [var.alb_target_group_arn]
}
