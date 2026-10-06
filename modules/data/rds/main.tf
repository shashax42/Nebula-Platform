# ========================================
# RDS Module - 단일 인스턴스 MySQL (dev: Single-AZ, staging: Multi-AZ 동기 standby)
# Aurora 모듈과 같은 변수 이름(name_prefix, environment, tags)을 따른다
# ========================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  identifier = "${var.name_prefix}-mysql-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Module      = "data/rds"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.name_prefix}-rds-${var.environment}-"
  description = "Security group for RDS ${local.identifier}"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from VPC"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${local.identifier}-sg" })
}

resource "aws_db_parameter_group" "rds" {
  name_prefix = "${local.identifier}-"
  family      = var.parameter_group_family
  description = "Parameter group for ${local.identifier}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_db_instance" "rds" {
  identifier     = local.identifier
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_id

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password
  port     = var.port

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = concat([aws_security_group.rds.id], var.additional_security_group_ids)
  parameter_group_name   = aws_db_parameter_group.rds.name
  publicly_accessible    = false

  # 고가용성: true 면 다른 AZ 에 동기 standby (읽기 불가, 장애 시 DNS 가 standby 로 넘어감)
  multi_az = var.multi_az

  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.identifier}-final"
  deletion_protection       = var.deletion_protection
  copy_tags_to_snapshot     = true

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  performance_insights_enabled    = var.performance_insights_enabled
  auto_minor_version_upgrade      = true
  apply_immediately               = var.apply_immediately

  tags = merge(local.common_tags, { Name = local.identifier })

  lifecycle {
    ignore_changes = [password]
  }
}
