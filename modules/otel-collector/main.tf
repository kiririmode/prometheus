# CloudWatch Log Group for OTel Collector
resource "aws_cloudwatch_log_group" "otel" {
  name              = "/ecs/${var.project_name}-${var.environment}-otel-collector"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ECS Task Definition for OTel Collector
resource "aws_ecs_task_definition" "otel" {
  family                   = "${var.project_name}-${var.environment}-otel-collector"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "otel-collector"
      image     = "otel/opentelemetry-collector-contrib:${var.otel_version}"
      essential = true

      portMappings = [
        {
          containerPort = 4318
          protocol      = "tcp"
          name          = "otlp-http"
        }
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "AMP_REMOTE_WRITE_ENDPOINT"
          value = var.amp_remote_write_endpoint
        }
      ]

      command = ["--config=/etc/otel-collector-config.yaml"]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.otel.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "otel"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --spider -q http://localhost:13133/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = var.tags
}

# ECS Service for OTel Collector
resource "aws_ecs_service" "otel" {
  name            = "${var.project_name}-${var.environment}-otel-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.otel.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = var.enable_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
    base              = var.enable_fargate_spot ? 0 : 1
  }

  # Fallback to FARGATE if FARGATE_SPOT is not available
  dynamic "capacity_provider_strategy" {
    for_each = var.enable_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 0
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.otel_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "otel-collector"
    container_port   = 4318
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

# Auto Scaling Target
resource "aws_appautoscaling_target" "otel" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${split("/", var.ecs_cluster_id)[1]}/${aws_ecs_service.otel.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "otel_cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${var.project_name}-${var.environment}-otel-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.otel[0].resource_id
  scalable_dimension = aws_appautoscaling_target.otel[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.otel[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "otel_memory" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${var.project_name}-${var.environment}-otel-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.otel[0].resource_id
  scalable_dimension = aws_appautoscaling_target.otel[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.otel[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
