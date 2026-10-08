# ==========================================================================
# Dev — "이 설계는 말이 되나?" (Assumption Layer)
#   운영에서 틀릴 설계를 싸게, 빨리 드러내는 환경.
#   - RDS 단일 인스턴스 + Redis(선택): 캐시 유무에 따른 실패 양상을 스위치 하나로 비교
#   - ALB Ingress → core-gateway: 요청 진입 구조 자체를 설계 대상으로
#   - Spot 노드, 짧은 로그 보존, 빠른 축소: 비용 최소화
#   - 로컬에서는 compose/ 로 같은 구성요소를 가볍게 복제한다
# ==========================================================================

module "platform" {
  source = "../../modules/environment"

  environment  = "dev"
  region       = var.region
  network_cidr = "10.10.0.0/16"

  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  node_group = {
    instance_types = ["t3.large", "t3a.large", "m5.large"]
    capacity_type  = "SPOT"
    min_size       = 2
    max_size       = 4
    desired_size   = 3
  }
  autoscaling        = { scale_down_utilization_threshold = 0.6, scale_down_unneeded_time = "5m", scale_down_delay_after_add = "5m" }
  log_retention_days = 7

  database = { engine = "rds", instance_class = "db.t3.medium", multi_az = false, backup_retention_period = 1 }
  redis    = { enabled = var.enable_redis, node_type = "cache.t3.micro", shards = 1, replicas_per_shard = 1 }

  istio   = { enabled = false }
  ingress = { certificate_arn = var.ingress_certificate_arn }

  gitops_token             = var.gitops_token
  enable_aws_platform_apps = var.enable_aws_platform_apps
  auth0                    = var.auth0
}
