# Dev環境 Terraform設定
# 環境: dev
# リージョン: ap-northeast-1

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Phase 1: Network Infrastructure
module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  single_nat_gateway   = var.single_nat_gateway

  tags = local.common_tags
}

# Phase 1: Security Groups
module "security_groups" {
  source = "../../modules/security-groups"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.network.vpc_id
  allowed_cidr_blocks         = var.allowed_cidr_blocks
  grafana_allowed_cidr_blocks = var.grafana_allowed_cidr_blocks
  enable_efs                  = var.enable_grafana_efs

  tags = local.common_tags
}

# Phase 1: IAM Roles
module "iam" {
  source = "../../modules/iam"

  project_name      = var.project_name
  environment       = var.environment
  amp_workspace_arn = module.amp.workspace_arn
  aws_region        = var.aws_region
  config_bucket_arn = module.config_storage.bucket_arn

  tags = local.common_tags
}

# Phase 2: AWS Managed Prometheus
module "amp" {
  source = "../../modules/amp"

  project_name       = var.project_name
  environment        = var.environment
  amp_retention_days = var.amp_retention_days

  tags = local.common_tags
}

# Phase 2: 設定ファイルストレージ（S3）
module "config_storage" {
  source = "../../modules/config-storage"

  project_name = var.project_name
  environment  = var.environment

  # OTel Collector設定（環境変数を展開）
  otel_collector_config = templatefile("${path.module}/../../configs/otel-collector-config.yaml", {
    AMP_REMOTE_WRITE_ENDPOINT = module.amp.remote_write_endpoint
    AWS_REGION                = var.aws_region
  })

  # Grafana データソース設定（環境変数を展開）
  grafana_datasources_config = templatefile("${path.module}/../../configs/grafana/provisioning/datasources/amp-datasource.yaml", {
    AMP_QUERY_ENDPOINT = module.amp.query_endpoint
    AWS_REGION         = var.aws_region
  })

  # Grafana ダッシュボードプロバイダー設定
  grafana_dashboards_config = file("${path.module}/../../configs/grafana/provisioning/dashboards/dashboards.yaml")

  # サンプルダッシュボード
  grafana_sample_dashboard = file("${path.module}/../../configs/grafana/provisioning/dashboards/default/sample-dashboard.json")

  tags = local.common_tags
}

# Phase 2: EFS (Optional - for Grafana data persistence)
module "efs" {
  count  = var.enable_grafana_efs ? 1 : 0
  source = "../../modules/efs"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  grafana_security_group = module.security_groups.grafana_security_group_id

  tags = local.common_tags
}

# Phase 3: ECS Cluster
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project_name = var.project_name
  environment  = var.environment

  tags = local.common_tags
}

# Phase 3: Application Load Balancers
module "alb" {
  source = "../../modules/alb"

  project_name                  = var.project_name
  environment                   = var.environment
  vpc_id                        = module.network.vpc_id
  public_subnet_ids             = module.network.public_subnet_ids
  otel_alb_security_group_id    = module.security_groups.otel_alb_security_group_id
  grafana_alb_security_group_id = module.security_groups.grafana_alb_security_group_id

  tags = local.common_tags
}

# Phase 4: OpenTelemetry Collector
module "otel_collector" {
  source = "../../modules/otel-collector"

  project_name              = var.project_name
  environment               = var.environment
  ecs_cluster_id            = module.ecs_cluster.cluster_id
  private_subnet_ids        = module.network.private_subnet_ids
  otel_security_group_id    = module.security_groups.otel_security_group_id
  task_role_arn             = module.iam.otel_task_role_arn
  task_execution_role_arn   = module.iam.ecs_task_execution_role_arn
  amp_remote_write_endpoint = module.amp.remote_write_endpoint
  aws_region                = var.aws_region
  cpu                       = var.otel_cpu
  memory                    = var.otel_memory
  desired_count             = var.otel_desired_count
  enable_fargate_spot       = var.enable_fargate_spot
  alb_target_group_arn      = module.alb.otel_target_group_arn
  log_retention_days        = var.log_retention_days
  otel_config_s3_uri        = module.config_storage.otel_config_s3_uri

  tags = local.common_tags
}

# Phase 4: Grafana
module "grafana" {
  source = "../../modules/grafana"

  project_name                   = var.project_name
  environment                    = var.environment
  ecs_cluster_id                 = module.ecs_cluster.cluster_id
  private_subnet_ids             = module.network.private_subnet_ids
  grafana_security_group_id      = module.security_groups.grafana_security_group_id
  task_role_arn                  = module.iam.grafana_task_role_arn
  task_execution_role_arn        = module.iam.ecs_task_execution_role_arn
  aws_region                     = var.aws_region
  cpu                            = var.grafana_cpu
  memory                         = var.grafana_memory
  admin_password                 = var.grafana_admin_password
  enable_efs                     = var.enable_grafana_efs
  efs_file_system_id             = var.enable_grafana_efs ? module.efs[0].file_system_id : null
  alb_target_group_arn           = module.alb.grafana_target_group_arn
  log_retention_days             = var.log_retention_days
  grafana_provisioning_s3_prefix = module.config_storage.grafana_provisioning_s3_prefix

  tags = local.common_tags
}
