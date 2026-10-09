# ==========================================================================
# 환경 하나(dev / staging / prod)를 만드는 입력값.
# 세 환경은 같은 모듈을 쓰고, 아래 값만 다르다 → 환경 차이가 코드가 아니라 입력값으로 드러난다.
# ==========================================================================

variable "environment" {
  description = "환경 이름 (dev / staging / prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment 는 dev, staging, prod 중 하나여야 합니다."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "network_cidr" {
  description = "VPC CIDR (환경끼리 겹치지 않게: dev 10.10, staging 10.20, prod 10.30)"
  type        = string
}

variable "nat_gateway_per_az" {
  description = "AZ 마다 NAT Gateway (prod: AZ 장애가 다른 AZ 의 외부 통신을 끊지 않게). false 면 NAT 1개"
  type        = bool
  default     = false
}

# --------------------------------------------------------------------------
# EKS
# --------------------------------------------------------------------------
variable "cluster_version" {
  description = "EKS Kubernetes 버전. Istio(istio.version)·Cluster Autoscaler 가 지원하는 범위 안에서 올린다"
  type        = string
  default     = "1.35"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "EKS API 엔드포인트에 접근할 수 있는 CIDR"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_group" {
  description = "기본 노드 그룹. max_size 까지는 Cluster Autoscaler 가 트래픽에 맞춰 늘리고 줄인다"
  type = object({
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = number
    max_size       = number
    desired_size   = number
  })
}

variable "autoscaling" {
  description = "Cluster Autoscaler 축소 정책 (FinOps: 놀고 있는 노드를 얼마나 빨리 반납할지)"
  type = object({
    scale_down_utilization_threshold = optional(number, 0.5)
    scale_down_unneeded_time         = optional(string, "10m")
    scale_down_delay_after_add       = optional(string, "10m")
  })
  default = {}
}

variable "log_retention_days" {
  description = "EKS 컨트롤 플레인 로그 보존 기간"
  type        = number
  default     = 30
}

# --------------------------------------------------------------------------
# 데이터 계층
# --------------------------------------------------------------------------
variable "database" {
  description = <<-EOT
    서비스 DB (account / order / product 스키마를 한 클러스터에 둔다).
      engine = "rds"    : RDS MySQL 단일 인스턴스. multi_az = true 면 동기 standby (staging)
      engine = "aurora" : Aurora MySQL. writer 1 + reader_count 개 reader 를 서로 다른 AZ 에 배치 (prod)
  EOT
  type = object({
    engine                  = string
    instance_class          = string
    multi_az                = optional(bool, false)
    reader_count            = optional(number, 0)
    backup_retention_period = optional(number, 7)
    deletion_protection     = optional(bool, false)
  })

  validation {
    condition     = contains(["rds", "aurora"], var.database.engine)
    error_message = "database.engine 은 rds 또는 aurora 여야 합니다."
  }
}

variable "db_master_username" {
  description = "DB 마스터 사용자 (비밀번호는 random_password 로 생성해 Kubernetes Secret 으로만 전달)"
  type        = string
  default     = "nebula_admin"
}

variable "redis" {
  description = <<-EOT
    ElastiCache Redis (Cluster 모드, TLS + AUTH). 서비스는 Redis Cluster 클라이언트로 접속한다.
      enabled = false 면 Redis 없이 배포한다 (dev 에서 캐시 유무에 따른 실패 양상을 보기 위한 스위치)
      snapshot_retention_limit = 0 이면 백업 없음 (prod: 캐시 전용, 원본은 Aurora)
  EOT
  type = object({
    enabled                  = optional(bool, true)
    node_type                = optional(string, "cache.t3.micro")
    shards                   = optional(number, 1)
    replicas_per_shard       = optional(number, 1)
    multi_az                 = optional(bool, false)
    snapshot_retention_limit = optional(number, 1)
  })
  default = {}
}

variable "enable_sqs" {
  description = "비동기 처리용 SQS 큐 + DLQ (staging: 동기/비동기 병목 비교 실험용)"
  type        = bool
  default     = false
}

# --------------------------------------------------------------------------
# 트래픽 계층
# --------------------------------------------------------------------------
variable "istio" {
  description = <<-EOT
    Istio 서비스 메시. ALB(Ingress) → istio-ingressgateway → 서비스.
      mtls_mode: PERMISSIVE (평문 허용, staging) / STRICT (메시 내부 mTLS 강제, prod)
  EOT
  type = object({
    enabled   = bool
    version   = optional(string, "1.30.5") # Kubernetes 1.32 ~ 1.36 지원
    mtls_mode = optional(string, "PERMISSIVE")
    gateway_replicas = optional(object({
      min = number
      max = number
    }), { min = 1, max = 3 })
  })
  default = { enabled = false }

  validation {
    condition     = contains(["PERMISSIVE", "STRICT"], var.istio.mtls_mode)
    error_message = "istio.mtls_mode 는 PERMISSIVE 또는 STRICT 여야 합니다."
  }
}

variable "ingress" {
  description = "ALB Ingress 설정. certificate_arn 이 있으면 HTTPS(443) 리스너를 추가하고 80 → 443 리다이렉트"
  type = object({
    scheme          = optional(string, "internet-facing")
    certificate_arn = optional(string, "")
    allowed_cidrs   = optional(list(string), ["0.0.0.0/0"])
  })
  default = {}
}

# --------------------------------------------------------------------------
# GitOps / 서비스 배포
# --------------------------------------------------------------------------
variable "gitops_repo_url" {
  description = "ArgoCD 가 동기화할 GitOps 레포"
  type        = string
  default     = "https://github.com/shashax42/nebula-gitops.git"
}

variable "gitops_revision" {
  description = "ArgoCD 가 따라갈 GitOps 브랜치"
  type        = string
  default     = "main"
}

variable "gitops_token" {
  description = "GitOps 레포 읽기 토큰 (public 레포면 빈 값)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_aws_platform_apps" {
  description = "nebula-gitops platform/aws/envs/<env> (모니터링 스택, AMP 카나리 분석)를 ArgoCD 로 동기화. Nebula-Monitoring apply 및 값 기록 후 true"
  type        = bool
  default     = false
}

variable "service_config" {
  description = <<-EOT
    서비스(nebula-services) 런타임 설정. config-<service> ConfigMap 으로 들어간다.
      ddl_auto: 스키마 마이그레이션 도구(Flyway 등)가 아직 없어 Hibernate 가 테이블을 만든다 (update)
  EOT
  type = object({
    ddl_auto     = optional(string, "update")
    db_pool_size = optional(number, 10)
  })
  default = {}
}

variable "auth0" {
  description = "core-gateway OIDC 로그인 (Auth0). secret-gateway Secret 으로 들어간다. 비우면 게이트웨이 로그인이 동작하지 않는다"
  type = object({
    domain        = optional(string, "")
    client_id     = optional(string, "")
    client_secret = optional(string, "")
  })
  default   = {}
  sensitive = true
}

variable "tags" {
  description = "모든 리소스 공통 태그"
  type        = map(string)
  default     = {}
}
