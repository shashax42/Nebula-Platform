# AWS 없이 세 환경 프로파일의 plan 을 검증한다 (mock provider).
#   cd modules/environment && terraform init -backend=false && terraform test
# 확인하는 것: 환경별로 맞는 데이터 계층·메시·큐가 만들어지는지, 서비스 ConfigMap 이 nebula-services 의 변수 이름과 맞는지

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"] }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012", arn = "arn:aws:iam::123456789012:user/terraform" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_iam_session_context" {
    defaults = { issuer_arn = "arn:aws:iam::123456789012:role/admin" }
  }
  mock_data "aws_region" {
    defaults = { name = "ap-northeast-2" }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "random" {}
mock_provider "tls" {}
mock_provider "time" {}
mock_provider "cloudinit" {}
mock_provider "null" {}

variables {
  region = "ap-northeast-2"
  auth0  = { domain = "nebula.example.auth0.com", client_id = "test", client_secret = "test" }
}

run "dev" {
  command = plan

  variables {
    environment  = "dev"
    network_cidr = "10.10.0.0/16"
    node_group   = { instance_types = ["t3.large"], capacity_type = "SPOT", min_size = 2, max_size = 4, desired_size = 3 }
    database     = { engine = "rds", instance_class = "db.t3.medium" }
    redis        = { enabled = true }
    istio        = { enabled = false }
  }

  assert {
    condition     = length(module.rds) == 1 && length(module.aurora) == 0
    error_message = "dev 는 RDS 단일 인스턴스여야 합니다"
  }
  assert {
    condition     = length(helm_release.istiod) == 0
    error_message = "dev 에는 Istio 가 없어야 합니다"
  }
  assert {
    condition     = kubernetes_config_map_v1.service["order"].data["PROFILE"] == "kubernetes"
    error_message = "서비스는 kubernetes 프로파일로 떠야 합니다"
  }
  assert {
    condition     = kubernetes_config_map_v1.service["order"].data["ORDER_DB_DATABASE"] == "order" && kubernetes_config_map_v1.service["gateway"].data["ACCOUNT_DB_DATABASE"] == "account"
    error_message = "서비스별 DB 스키마 매핑이 nebula-services 와 다릅니다"
  }
  assert {
    condition     = kubernetes_config_map_v1.service["order"].data["KAFKA_BOOTSTRAP_SERVER1"] == "market-message-kafka-bootstrap.backend.svc"
    error_message = "service-order 는 Strimzi Kafka 를 봐야 합니다"
  }
  assert {
    condition     = !contains(keys(kubernetes_config_map_v1.service["batch-order"].data), "REDIS_CLUSTER_NODE_1_HOST")
    error_message = "batch-order 는 Redis 를 쓰지 않습니다"
  }
  assert {
    condition     = length(aws_sqs_queue.order_events) == 0
    error_message = "dev 에는 SQS 가 없어야 합니다"
  }
  assert {
    condition     = kubernetes_storage_class_v1.gp3.metadata[0].annotations["storageclass.kubernetes.io/is-default-class"] == "true" && kubernetes_storage_class_v1.gp3.parameters["type"] == "gp3"
    error_message = "Kafka PVC 가 바인딩되려면 gp3 가 기본 StorageClass 여야 합니다"
  }
  assert {
    condition     = kubernetes_storage_class_v1.gp3.reclaim_policy == "Delete"
    error_message = "dev 볼륨은 PVC 와 함께 지워져야 합니다"
  }
}

run "dev_without_redis" {
  command = plan

  variables {
    environment  = "dev"
    network_cidr = "10.10.0.0/16"
    node_group   = { instance_types = ["t3.large"], min_size = 2, max_size = 4, desired_size = 3 }
    database     = { engine = "rds", instance_class = "db.t3.medium" }
    redis        = { enabled = false }
  }

  assert {
    condition     = length(module.redis) == 0 && !contains(keys(kubernetes_config_map_v1.service["order"].data), "REDIS_CLUSTER_NODE_1_HOST")
    error_message = "Redis 를 끄면 ElastiCache 와 Redis 연결 정보가 모두 빠져야 합니다"
  }
}

run "staging" {
  command = plan

  variables {
    environment  = "staging"
    network_cidr = "10.20.0.0/16"
    node_group   = { instance_types = ["t3.xlarge"], min_size = 3, max_size = 6, desired_size = 3 }
    database     = { engine = "rds", instance_class = "db.t3.medium", multi_az = true }
    redis        = { multi_az = true }
    enable_sqs   = true
    istio        = { enabled = true, mtls_mode = "PERMISSIVE" }
  }

  assert {
    condition     = length(module.rds) == 1 && length(aws_sqs_queue.order_events) == 1 && length(aws_sqs_queue.order_events_dlq) == 1
    error_message = "staging 은 RDS Multi-AZ + SQS(+DLQ) 여야 합니다"
  }
  assert {
    condition     = length(helm_release.istiod) == 1 && length(helm_release.istio_ingressgateway) == 1
    error_message = "staging 에는 Istio 가 있어야 합니다"
  }
}

run "prod" {
  command = plan

  variables {
    environment        = "prod"
    network_cidr       = "10.30.0.0/16"
    nat_gateway_per_az = true
    node_group         = { instance_types = ["m6i.large"], min_size = 3, max_size = 9, desired_size = 3 }
    database           = { engine = "aurora", instance_class = "db.t4g.medium", reader_count = 1, deletion_protection = true }
    redis              = { node_type = "cache.t4g.small", shards = 1, multi_az = true, snapshot_retention_limit = 0 }
    istio              = { enabled = true, mtls_mode = "STRICT" }
  }

  assert {
    condition     = length(module.aurora) == 1 && length(module.rds) == 0
    error_message = "prod 는 Aurora 여야 합니다"
  }
  assert {
    condition     = length(module.aurora[0].instance_ids) == 2
    error_message = "prod Aurora 는 writer 1 + reader 1 이어야 합니다"
  }
  assert {
    condition     = length(aws_sqs_queue.order_events) == 0
    error_message = "prod 에는 SQS 가 없어야 합니다"
  }
  assert {
    condition     = kubernetes_storage_class_v1.gp3.reclaim_policy == "Retain"
    error_message = "prod 볼륨은 PVC 를 지워도 남아야 합니다"
  }
  assert {
    condition     = strcontains(helm_release.argocd_root.values[0], "platform/envs/prod")
    error_message = "prod 클러스터는 nebula-gitops 의 platform/envs/prod (승격된 이미지)를 따라야 합니다"
  }
}

run "missing_auth0_warns" {
  command = plan

  variables {
    environment  = "dev"
    network_cidr = "10.10.0.0/16"
    node_group   = { instance_types = ["t3.large"], min_size = 2, max_size = 4, desired_size = 3 }
    database     = { engine = "rds", instance_class = "db.t3.medium" }
    auth0        = {}
  }

  # 실제 plan 에서는 경고만 나오고 진행된다. 테스트에서는 경고가 났는지를 확인한다
  expect_failures = [check.auth0_for_gateway]
}
