# ==========================================================================
# Prod — "사람이 아니라 시스템이 결정할 수 있는가?" (Decision Layer)
#   운영자는 상태를 확인하고 개입 여부만 결정한다. 나머지는 시스템이 판단한다.
#   - Aurora Multi-AZ (writer + reader 1, AZ 분산): writer 장애 시 reader 자동 승격
#   - Redis 세션·캐시 (Cluster 1 샤드 + replica, Multi-AZ 자동 failover, 백업 없음): 원본 데이터는 Aurora
#   - AZ 별 NAT Gateway: AZ 하나가 죽어도 나머지 AZ 의 외부 통신 유지
#   - Cluster Autoscaler(최대 3배) + HPA: 피크 트래픽 대응, 유휴 노드 반납
#   - ALB Ingress + Istio(STRICT mTLS, 서킷브레이커): 트래픽 흐름·정책을 중앙에서 제어
#   - Argo Rollouts 카나리 + AMP 분석: 배포 결함은 사람이 아니라 지표가 롤백한다
#
# 크기는 "적정 크기" 가정이다 (docs/COST_COMPARISON.md). 가용성 구조(Multi-AZ, reader, AZ 별 NAT)는
# 유지하고 인스턴스 크기만 현재 트래픽 규모에 맞췄다. 부하 테스트 결과에 따라 아래 값을 올린다:
#   노드 수가 상시 3 을 넘으면 instance_types 를 m6i.xlarge 로, DB CPU 크레딧이 바닥나면 db.r6g.large 로.
# ==========================================================================

module "platform" {
  source = "../../modules/environment"

  environment        = "prod"
  region             = var.region
  network_cidr       = "10.30.0.0/16"
  nat_gateway_per_az = true

  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  node_group = {
    instance_types = ["m6i.large"]
    min_size       = 3
    max_size       = 9
    desired_size   = 3
  }
  autoscaling        = { scale_down_utilization_threshold = 0.5, scale_down_unneeded_time = "15m", scale_down_delay_after_add = "15m" }
  log_retention_days = 90

  database = { engine = "aurora", instance_class = "db.t4g.medium", reader_count = 1, backup_retention_period = 14, deletion_protection = true }
  redis    = { node_type = "cache.t4g.small", shards = 1, replicas_per_shard = 1, multi_az = true, snapshot_retention_limit = 0 }

  istio   = { enabled = true, mtls_mode = "STRICT", gateway_replicas = { min = 2, max = 6 } }
  ingress = { certificate_arn = var.ingress_certificate_arn }

  gitops_token             = var.gitops_token
  enable_aws_platform_apps = var.enable_aws_platform_apps
  auth0                    = var.auth0
}
