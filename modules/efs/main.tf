# EFS File System
resource "aws_efs_file_system" "grafana" {
  creation_token = "${var.project_name}-${var.environment}-grafana-efs"
  encrypted      = true

  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-efs"
    }
  )
}

# EFS Mount Targets
resource "aws_efs_mount_target" "grafana" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.grafana.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [var.grafana_security_group]
}

# EFS Backup Policy
resource "aws_efs_backup_policy" "grafana" {
  count = var.enable_backup ? 1 : 0

  file_system_id = aws_efs_file_system.grafana.id

  backup_policy {
    status = "ENABLED"
  }
}

# EFS Access Point for Grafana
resource "aws_efs_access_point" "grafana" {
  file_system_id = aws_efs_file_system.grafana.id

  posix_user {
    gid = 472 # Grafana default GID
    uid = 472 # Grafana default UID
  }

  root_directory {
    path = "/grafana"
    creation_info {
      owner_gid   = 472
      owner_uid   = 472
      permissions = "755"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-grafana-access-point"
    }
  )
}
