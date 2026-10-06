# ========================================
# Aurora Module - 재사용 가능한 Aurora 모듈
# 중복된 Aurora 클러스터들을 하나의 모듈로 통합
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
  cluster_identifier = "${var.name_prefix}-aurora-${var.environment}"
  
  common_tags = merge(
    var.tags,
    {
      Module      = "data/aurora"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# ========================================
# Security Group
# ========================================
resource "aws_security_group" "aurora" {
  name_prefix = "${var.name_prefix}-aurora-"
  description = "Security group for Aurora cluster ${var.name_prefix}"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL/Aurora from VPC"
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

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-aurora-sg"
    }
  )
}

# ========================================
# Parameter Groups
# ========================================
resource "aws_rds_cluster_parameter_group" "aurora" {
  count = var.create_parameter_group ? 1 : 0
  
  name_prefix = "${var.name_prefix}-aurora-cluster-"
  family      = var.engine_family
  description = "Cluster parameter group for ${var.name_prefix}"

  dynamic "parameter" {
    for_each = var.cluster_parameters
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

# ========================================
# Aurora Cluster
# ========================================
resource "aws_rds_cluster" "aurora" {
  cluster_identifier              = local.cluster_identifier
  engine                         = var.engine
  engine_version                 = var.engine_version
  database_name                  = var.database_name
  master_username                = var.master_username
  master_password                = var.master_password
  port                          = var.port
  
  # 네트워크
  db_subnet_group_name           = var.db_subnet_group_name
  vpc_security_group_ids         = concat([aws_security_group.aurora.id], var.additional_security_group_ids)
  
  # 파라미터 그룹
  db_cluster_parameter_group_name = var.create_parameter_group ? aws_rds_cluster_parameter_group.aurora[0].name : var.cluster_parameter_group_name
  
  # 백업
  backup_retention_period        = var.backup_retention_period
  preferred_backup_window        = var.backup_window
  preferred_maintenance_window   = var.maintenance_window
  skip_final_snapshot           = var.skip_final_snapshot
  final_snapshot_identifier     = var.skip_final_snapshot ? null : "${local.cluster_identifier}-final"
  
  # 암호화
  storage_encrypted             = var.storage_encrypted
  kms_key_id                   = var.kms_key_id
  
  # 고가용성
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  deletion_protection           = var.deletion_protection
  
  tags = merge(
    local.common_tags,
    {
      Name = local.cluster_identifier
    }
  )
  
  lifecycle {
    ignore_changes = [master_password]
  }
}

# ========================================
# Aurora Instances (자동 스케일링)
# ========================================
resource "aws_rds_cluster_instance" "aurora" {
  count = var.instance_count
  
  identifier                   = "${local.cluster_identifier}-${count.index + 1}"
  cluster_identifier          = aws_rds_cluster.aurora.id
  instance_class              = var.instance_class
  engine                      = aws_rds_cluster.aurora.engine
  engine_version              = aws_rds_cluster.aurora.engine_version
  
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval         = var.monitoring_interval
  monitoring_role_arn         = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null

  # Multi-AZ: writer 와 reader 를 서로 다른 AZ 에 고정 (장애 시 다른 AZ 의 reader 가 writer 로 승격)
  availability_zone = length(var.availability_zones) > 0 ? element(var.availability_zones, count.index) : null
  
  # 인스턴스별 역할 지정 (Writer/Reader)
  promotion_tier             = count.index
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_identifier}-${count.index + 1}"
      Role = count.index == 0 ? "writer" : "reader"
    }
  )
}

# ========================================
# Enhanced Monitoring Role (monitoring_interval > 0 이면 필수)
# ========================================
resource "aws_iam_role" "enhanced_monitoring" {
  count       = var.monitoring_interval > 0 ? 1 : 0
  name_prefix = "${var.name_prefix}-rds-mon-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
