# ========================================
# Database Infrastructure - 모듈화된 구조
# 기존 273줄의 중복 코드를 모듈로 완전 교체
# ========================================

# 공통 설정
locals {
  database_config = {
    vpc_id              = module.vpc.vpc_id
    subnet_ids          = local.internal_subnets
    db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
    
    # 환경별 차이
    environment = "dev"
    
    # Dev 환경은 비용 절감
    instance_class = "db.t3.medium"
    instance_count = 2  # 1 writer + 1 reader
    
    # 백업 설정
    backup_retention_period = 7
    skip_final_snapshot = true  # Dev는 스냅샷 생략
  }
}

# ========================================
# Aurora Cluster 1 - Main Database
# ========================================
module "aurora_main" {
  source = "../../modules/data/aurora"
  
  name_prefix    = "main"
  environment    = local.database_config.environment
  
  # 네트워크
  vpc_id                = local.database_config.vpc_id
  db_subnet_group_name  = local.database_config.db_subnet_group_name
  allowed_cidr_blocks   = [var.network_cidr]
  
  # 데이터베이스 설정
  database_name    = var.rds_db_name1
  master_username  = var.rds_username
  master_password  = var.rds_password
  port            = 3306
  
  # 인스턴스 설정
  instance_class  = local.database_config.instance_class
  instance_count  = local.database_config.instance_count
  
  # 엔진
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.04.1"
  engine_family  = "aurora-mysql8.0"
  
  # 파라미터 최적화
  cluster_parameters = [
    {
      name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "character_set_client"
      value = "utf8mb4"
    }
  ]
  
  # 백업
  backup_retention_period = local.database_config.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  skip_final_snapshot    = local.database_config.skip_final_snapshot
  
  # 보안
  storage_encrypted = true
  deletion_protection = false  # Dev는 false
  
  # 모니터링
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  performance_insights_enabled = true
  
  # 태그
  tags = {
    Purpose = "main-application"
    Team    = "backend"
  }
}

# ========================================
# Aurora Cluster 2 - Analytics Database
# ========================================
module "aurora_analytics" {
  source = "../../modules/data/aurora"
  
  name_prefix    = "analytics"
  environment    = local.database_config.environment
  
  # 네트워크
  vpc_id                = local.database_config.vpc_id
  db_subnet_group_name  = local.database_config.db_subnet_group_name
  allowed_cidr_blocks   = [var.network_cidr]
  
  # 데이터베이스 설정
  database_name    = var.rds_db_name2
  master_username  = var.rds_username
  master_password  = var.rds_password
  port            = 3307  # 다른 포트 사용
  
  # 분석용은 더 많은 읽기 노드
  instance_class  = local.database_config.instance_class
  instance_count  = 3  # 1 writer + 2 readers
  
  # 엔진
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.04.1"
  engine_family  = "aurora-mysql8.0"
  
  # 분석용 파라미터 최적화
  cluster_parameters = [
    {
      name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "innodb_read_io_threads"
      value = "64"
    },
    {
      name  = "innodb_write_io_threads"
      value = "64"
    }
  ]
  
  # 백업 (분석용은 짧게)
  backup_retention_period = 3
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  skip_final_snapshot    = local.database_config.skip_final_snapshot
  
  tags = {
    Purpose = "analytics"
    Team    = "data"
  }
}

# ========================================
# Aurora Cluster 3 - Reporting Database  
# ========================================
module "aurora_reporting" {
  source = "../../modules/data/aurora"
  
  name_prefix    = "reporting"
  environment    = local.database_config.environment
  
  # 네트워크
  vpc_id                = local.database_config.vpc_id
  db_subnet_group_name  = local.database_config.db_subnet_group_name
  allowed_cidr_blocks   = [var.network_cidr]
  
  # 데이터베이스 설정
  database_name    = var.rds_db_name3
  master_username  = var.rds_username
  master_password  = var.rds_password
  port            = 3308
  
  # Reporting은 기본 설정
  instance_class  = local.database_config.instance_class
  instance_count  = local.database_config.instance_count
  
  # 엔진
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.04.1"
  engine_family  = "aurora-mysql8.0"
  
  # 백업
  backup_retention_period = 1  # Reporting은 최소
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  skip_final_snapshot    = local.database_config.skip_final_snapshot
  
  tags = {
    Purpose = "reporting"
    Team    = "bi"
  }
}

# ========================================
# Redis Cache
# ========================================
module "redis_cache" {
  source = "../../modules/data/redis"
  
  name_prefix    = "cache"
  environment    = "dev"
  
  # 네트워크
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = local.internal_subnets
  allowed_cidr_blocks   = [var.network_cidr]
  
  # Redis 설정
  node_type            = "cache.t3.micro"  # Dev는 작게
  num_cache_clusters   = 2
  engine_version       = "7.0"
  
  # 보안
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  # 백업
  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"
  maintenance_window      = "sun:05:00-sun:07:00"
  
  tags = {
    Purpose = "application-cache"
    Team    = "backend"
  }
}

# ========================================
# Outputs - 모듈에서 가져온 정보
# ========================================
output "aurora_endpoints" {
  description = "Aurora cluster endpoints"
  value = {
    main = {
      writer = module.aurora_main.cluster_endpoint
      reader = module.aurora_main.reader_endpoint
    }
    analytics = {
      writer = module.aurora_analytics.cluster_endpoint
      reader = module.aurora_analytics.reader_endpoint
    }
    reporting = {
      writer = module.aurora_reporting.cluster_endpoint
      reader = module.aurora_reporting.reader_endpoint
    }
  }
  sensitive = true
}

output "redis_endpoints" {
  description = "Redis endpoints"
  value = {
    primary = module.redis_cache.primary_endpoint_address
    reader  = module.redis_cache.reader_endpoint_address
  }
  sensitive = true
}
