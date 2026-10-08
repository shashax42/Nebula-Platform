# ==========================================================================
# Staging — "이 가정이 실제로 깨질 수 있나?" (Validation Layer)
#   운영을 시뮬레이션하고, 실패의 형태를 학습하는 환경.
#   - RDS Multi-AZ + Redis + SQS: 동기(DB) / 비동기(Kafka·SQS) 경로 중 어디서 지연이 쌓이는지 식별
#   - ALB Ingress + Istio(PERMISSIVE): 앱 문제와 트래픽 제어 계층 문제를 분리
#   - 노드 장애·네트워크 지연·자원 경합은 vagrant/ 의 로컬 클러스터에서 재현한다
# ==========================================================================

module "platform" {
  source = "../../modules/environment"

  environment  = "staging"
  region       = var.region
  network_cidr = "10.20.0.0/16"

  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  node_group = {
    instance_types = ["t3.xlarge"]
    min_size       = 3
    max_size       = 6
    desired_size   = 3
  }
  log_retention_days = 14

  database   = { engine = "rds", instance_class = "db.t3.medium", multi_az = true, backup_retention_period = 7 }
  redis      = { node_type = "cache.t3.small", shards = 1, replicas_per_shard = 1, multi_az = true }
  enable_sqs = true

  istio   = { enabled = true, mtls_mode = "PERMISSIVE" }
  ingress = { certificate_arn = var.ingress_certificate_arn }

  gitops_token             = var.gitops_token
  enable_aws_platform_apps = var.enable_aws_platform_apps
  auth0                    = var.auth0
}
