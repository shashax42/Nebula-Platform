# ==========================================================================
# 데이터 계층: 서비스가 실제로 쓰는 것만 만든다
#   DB    : account / order / product 스키마 (nebula-services 의 *_DB_* 환경변수)
#   Redis : Spring Session(core-gateway, service-account) + 캐시(service-order, service-product)
#   Kafka : 클러스터 안 Strimzi (nebula-gitops data-kafka) — 여기서는 만들지 않는다
# ==========================================================================

locals {
  service_databases = ["account", "order", "product"]
  use_aurora        = var.database.engine == "aurora"
}

resource "random_password" "db_master" {
  length  = 32
  special = false
}

# --------------------------------------------------------------------------
# dev / staging: RDS MySQL (staging 은 Multi-AZ 동기 standby)
# --------------------------------------------------------------------------
module "rds" {
  source = "../data/rds"
  count  = local.use_aurora ? 0 : 1

  name_prefix = "nebula"
  environment = var.environment

  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  allowed_cidr_blocks  = module.vpc.private_subnets_cidr_blocks

  instance_class  = var.database.instance_class
  multi_az        = var.database.multi_az
  master_username = var.db_master_username
  master_password = random_password.db_master.result

  backup_retention_period = var.database.backup_retention_period
  deletion_protection     = var.database.deletion_protection
  skip_final_snapshot     = !var.database.deletion_protection

  tags = local.tags
}

# --------------------------------------------------------------------------
# prod: Aurora MySQL — writer 1 + reader N, AZ 분산. 장애 시 reader 가 writer 로 자동 승격
# --------------------------------------------------------------------------
module "aurora" {
  source = "../data/aurora"
  count  = local.use_aurora ? 1 : 0

  name_prefix = "nebula"
  environment = var.environment

  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  allowed_cidr_blocks  = module.vpc.private_subnets_cidr_blocks

  master_username = var.db_master_username
  master_password = random_password.db_master.result
  port            = 3306

  instance_class     = var.database.instance_class
  instance_count     = 1 + var.database.reader_count
  availability_zones = local.azs

  engine        = "aurora-mysql"
  engine_family = "aurora-mysql8.0"
  cluster_parameters = [
    { name = "character_set_server", value = "utf8mb4" },
    { name = "collation_server", value = "utf8mb4_unicode_ci" },
  ]

  backup_retention_period = var.database.backup_retention_period
  skip_final_snapshot     = !var.database.deletion_protection
  deletion_protection     = var.database.deletion_protection
  storage_encrypted       = true

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  performance_insights_enabled    = true

  tags = local.tags
}

locals {
  db_writer_host = local.use_aurora ? module.aurora[0].cluster_endpoint : module.rds[0].address
  # 서비스의 RoutingDataSource 는 replica 데이터소스를 따로 가진다.
  # Aurora 는 reader endpoint, RDS(standby 는 읽기 불가)는 writer 를 그대로 쓴다
  db_reader_host = local.use_aurora && var.database.reader_count > 0 ? module.aurora[0].reader_endpoint : local.db_writer_host
}

# --------------------------------------------------------------------------
# Redis Cluster (TLS + AUTH)
# --------------------------------------------------------------------------
resource "random_password" "redis_auth" {
  count   = var.redis.enabled ? 1 : 0
  length  = 32
  special = false
}

module "redis" {
  source = "../data/redis"
  count  = var.redis.enabled ? 1 : 0

  name_prefix = "nebula"
  environment = var.environment

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.database_subnets
  allowed_cidr_blocks = module.vpc.private_subnets_cidr_blocks

  node_type               = var.redis.node_type
  engine_version          = "7.1"
  cluster_mode_enabled    = true
  num_node_groups         = var.redis.shards
  replicas_per_node_group = var.redis.replicas_per_shard

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth[0].result

  multi_az_enabled           = var.redis.multi_az
  automatic_failover_enabled = true

  snapshot_retention_limit = var.redis.snapshot_retention_limit
  snapshot_window          = "17:00-18:00"
  maintenance_window       = "sun:20:00-sun:21:00"

  tags = local.tags
}

# --------------------------------------------------------------------------
# SQS (staging): 비동기 경로를 Kafka 와 분리해 병목을 비교하기 위한 큐 + DLQ
# --------------------------------------------------------------------------
resource "aws_sqs_queue" "order_events_dlq" {
  count = var.enable_sqs ? 1 : 0

  name                      = "${local.name}-order-events-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = local.tags
}

resource "aws_sqs_queue" "order_events" {
  count = var.enable_sqs ? 1 : 0

  name                       = "${local.name}-order-events"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_events_dlq[0].arn
    maxReceiveCount     = 5
  })

  tags = local.tags
}
