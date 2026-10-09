# ==========================================================================
# 인프라 → 서비스 연결
#   nebula-gitops 의 서비스 매니페스트는 envFrom 으로 config-<service> ConfigMap 과 secret-<service> Secret 을 읽는다.
#   그 값(DB·Redis·Kafka 주소, 비밀번호)은 환경마다 다르고 Terraform 만 알고 있으므로 여기서 만든다.
#   → 매니페스트(무엇을 띄울지)는 모든 환경이 같고, 연결 정보(어디에 붙을지)만 환경별로 달라진다.
#
#   변수 이름은 nebula-services 의 src/main/resources/config/*.yml 플레이스홀더와 1:1 이다.
# ==========================================================================

resource "kubernetes_namespace_v1" "backend" {
  depends_on = [module.eks]

  metadata {
    name = "backend"
    labels = {
      "nebula.io/environment" = var.environment
    }
  }

  # nebula-gitops 의 namespace/ 앱도 같은 네임스페이스를 선언한다 (ArgoCD 추적 메타데이터는 건드리지 않는다)
  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}

locals {
  kafka_bootstrap = "market-message-kafka-bootstrap.backend.svc"

  # 서비스별로 어떤 DB 스키마 / Redis / Kafka 를 쓰는지 (nebula-services 기준)
  services = {
    gateway       = { db_prefix = "ACCOUNT", database = "account", redis = true, kafka = false }
    account       = { db_prefix = "ACCOUNT", database = "account", redis = true, kafka = false }
    order         = { db_prefix = "ORDER", database = "order", redis = true, kafka = true }
    product       = { db_prefix = "PRODUCT", database = "product", redis = true, kafka = true }
    "batch-order" = { db_prefix = "ORDER", database = "order", redis = false, kafka = false }
  }

  common_env = {
    PROFILE                       = "kubernetes"
    SPRING_JPA_HIBERNATE_DDL_AUTO = var.service_config.ddl_auto
    DB_POOL_SIZE                  = tostring(var.service_config.db_pool_size)
    NEBULA_ENVIRONMENT            = var.environment
  }

  # Redis Cluster: configuration endpoint 하나로 전체 토폴로지를 찾으므로 6개 노드 자리에 같은 주소를 넣는다
  redis_env = var.redis.enabled ? merge(
    { for i in range(1, 7) : "REDIS_CLUSTER_NODE_${i}_HOST" => module.redis[0].endpoint_address },
    { for i in range(1, 7) : "REDIS_CLUSTER_NODE_${i}_PORT" => "6379" },
    { SPRING_DATA_REDIS_SSL_ENABLED = "true" },
  ) : {}

  kafka_env = merge(
    { for i in range(1, 4) : "KAFKA_BOOTSTRAP_SERVER${i}" => local.kafka_bootstrap },
    { for i in range(1, 4) : "KAFKA_BOOTSTRAP_PORT${i}" => "9092" },
  )

  service_config = {
    for name, s in local.services : name => merge(
      local.common_env,
      {
        "${s.db_prefix}_DB_HOST"             = local.db_writer_host
        "${s.db_prefix}_DB_PORT"             = "3306"
        "${s.db_prefix}_DB_DATABASE"         = s.database
        "${s.db_prefix}_DB_USER"             = var.db_master_username
        "${s.db_prefix}_DB_REPLICA_HOST"     = local.db_reader_host
        "${s.db_prefix}_DB_REPLICA_PORT"     = "3306"
        "${s.db_prefix}_DB_REPLICA_DATABASE" = s.database
        "${s.db_prefix}_DB_REPLICA_USER"     = var.db_master_username
      },
      s.redis ? local.redis_env : {},
      s.kafka ? local.kafka_env : {},
    )
  }
}

resource "kubernetes_config_map_v1" "service" {
  for_each = local.services

  metadata {
    name      = "config-${each.key}"
    namespace = kubernetes_namespace_v1.backend.metadata[0].name
    labels    = { "app.kubernetes.io/managed-by" = "terraform" }
  }

  data = local.service_config[each.key]
}

resource "kubernetes_secret_v1" "service" {
  for_each = local.services

  metadata {
    name      = "secret-${each.key}"
    namespace = kubernetes_namespace_v1.backend.metadata[0].name
    labels    = { "app.kubernetes.io/managed-by" = "terraform" }
  }

  data = merge(
    {
      "${each.value.db_prefix}_DB_PASSWORD"         = random_password.db_master.result
      "${each.value.db_prefix}_DB_REPLICA_PASSWORD" = random_password.db_master.result
    },
    each.value.redis && var.redis.enabled ? { REDIS_CLUSTER_PASSWORD = random_password.redis_auth[0].result } : {},
    each.key == "gateway" ? {
      AUTH0_DOMAIN        = var.auth0.domain
      AUTH0_CLIENT_ID     = var.auth0.client_id
      AUTH0_CLIENT_SECRET = var.auth0.client_secret
    } : {},
  )
}

# --------------------------------------------------------------------------
# DB 스키마 초기화: 서비스 DB(account, order, product)를 만든다 (멱등).
# DB 는 database 서브넷에만 있으므로 클러스터 안에서 Job 으로 실행한다.
# backend 네임스페이스는 Kyverno 가 ghcr.io/shashax42 이미지만 허용하므로 별도 네임스페이스를 쓴다.
# --------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "platform_jobs" {
  depends_on = [module.eks]

  metadata {
    name = "nebula-system"
  }
}

resource "kubernetes_secret_v1" "db_admin" {
  metadata {
    name      = "db-admin"
    namespace = kubernetes_namespace_v1.platform_jobs.metadata[0].name
  }

  data = {
    DB_HOST     = local.db_writer_host
    DB_USER     = var.db_master_username
    DB_PASSWORD = random_password.db_master.result
  }
}

resource "kubernetes_job_v1" "db_bootstrap" {
  metadata {
    name      = "db-bootstrap"
    namespace = kubernetes_namespace_v1.platform_jobs.metadata[0].name
  }

  spec {
    backoff_limit = 10

    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "mysql"
          image = "mysql:8.4"
          command = [
            "mysql", "--host=$(DB_HOST)", "--user=$(DB_USER)", "--password=$(DB_PASSWORD)", "--connect-timeout=10",
            "--execute=${join(" ", [for d in local.service_databases : "CREATE DATABASE IF NOT EXISTS `${d}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"])}",
          ]

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.db_admin.metadata[0].name
            }
          }

          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { memory = "256Mi" }
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "15m"
    update = "15m"
  }

  # 스키마가 이미 있으면 다시 돌 필요가 없다. 엔드포인트가 바뀔 때만 다시 만든다
  lifecycle {
    replace_triggered_by = [kubernetes_secret_v1.db_admin]
  }
}

# core-gateway 는 기동할 때 https://<auth0.domain>/.well-known/openid-configuration 을 읽는다.
# 값이 없으면 게이트웨이가 계속 재시작하므로 plan 단계에서 경고한다 (막지는 않는다: 다른 서비스는 영향 없음)
check "auth0_for_gateway" {
  assert {
    condition     = nonsensitive(var.auth0.domain != "")
    error_message = "auth0.domain 이 비어 있습니다. core-gateway 는 Auth0 OIDC 설정 없이 기동하지 못하고 재시작을 반복합니다. terraform.tfvars 의 auth0 값을 채우세요."
  }
}
