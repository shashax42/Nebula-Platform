# ========================================
# Redis Module - 재사용 가능한 Redis 모듈
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
  replication_group_id = "${var.name_prefix}-redis-${var.environment}"
  
  common_tags = merge(
    var.tags,
    {
      Module      = "data/redis"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# ========================================
# Security Group
# ========================================
resource "aws_security_group" "redis" {
  name_prefix = "${var.name_prefix}-redis-"
  description = "Security group for Redis cluster ${var.name_prefix}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis from VPC"
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
      Name = "${var.name_prefix}-redis-sg"
    }
  )
}

# ========================================
# Subnet Group
# ========================================
resource "aws_elasticache_subnet_group" "redis" {
  count = var.create_subnet_group ? 1 : 0
  
  name        = "${var.name_prefix}-redis-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Subnet group for Redis cluster ${var.name_prefix}"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-redis-subnet-group"
    }
  )
}

# ========================================
# Parameter Group
# ========================================
resource "aws_elasticache_parameter_group" "redis" {
  count = var.create_parameter_group ? 1 : 0
  
  name        = "${var.name_prefix}-redis-param-group"
  family      = var.parameter_group_family
  description = "Parameter group for Redis cluster ${var.name_prefix}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

# ========================================
# Redis Replication Group
# ========================================
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = local.replication_group_id
  description               = "Redis cluster for ${var.name_prefix}"
  
  # 노드 설정
  node_type                 = var.node_type
  num_cache_clusters        = var.num_cache_clusters
  
  # 엔진 설정
  engine_version            = var.engine_version
  port                      = var.port
  parameter_group_name      = var.create_parameter_group ? aws_elasticache_parameter_group.redis[0].name : var.parameter_group_name
  
  # 네트워크 설정
  subnet_group_name         = var.create_subnet_group ? aws_elasticache_subnet_group.redis[0].name : var.subnet_group_name
  security_group_ids        = concat([aws_security_group.redis.id], var.additional_security_group_ids)
  
  # 백업 설정
  snapshot_retention_limit  = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window
  
  # 보안 설정
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                = var.auth_token
  
  # 고가용성
  multi_az_enabled          = var.multi_az_enabled
  automatic_failover_enabled = var.automatic_failover_enabled
  
  # 로그 설정
  log_delivery_configuration {
    destination      = var.log_destination
    destination_type = var.log_destination_type
    log_format      = var.log_format
    log_type        = "slow-log"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = local.replication_group_id
    }
  )
  
  lifecycle {
    ignore_changes = [auth_token]
  }
}
