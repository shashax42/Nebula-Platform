# Nebula-Platform

Nebula 서비스가 올라가는 AWS 인프라(Terraform).
**dev / staging / prod 세 환경이 같은 모듈(`modules/environment`)을 쓰고 입력값만 다르다.**
환경 사이의 차이는 코드가 아니라 각 `environments/<env>/main.tf` 의 입력값에서 그대로 드러난다.

## 레포 관계 — 서비스가 인프라에 올라가고 모니터링되기까지

```
nebula-services ──push──▶ nebula-ci-templates (reusable workflow)
   (Spring 서비스)           Secrets Scan → Test → Build → Trivy → Push(GHCR) → SBOM → cosign Sign
                                                   │ 이미지 태그(tag@digest) 갱신
                                                   ▼
                                           nebula-gitops ◀──────────── ArgoCD (App of Apps)
                                           (매니페스트: 무엇을 띄울지)        ▲ 이 레포가 설치
                                                                            │
Nebula-Platform (이 레포) ─ terraform apply ─▶ EKS ─┬─ config-<svc> / secret-<svc> (DB·Redis·Kafka 연결 정보: 어디에 붙을지)
                                                    ├─ RDS | Aurora · ElastiCache Redis Cluster · Strimzi Kafka
                                                    ├─ ALB Ingress (+ Istio) → core-gateway
                                                    └─ outputs ─▶ Nebula-Monitoring (remote state)
                                                                   AMP · AMG · X-Ray · CloudWatch 알람(Aurora/RDS/Redis/SQS)
                                                                   └ render-gitops-values.sh <env> ─▶ nebula-gitops platform/aws/envs/<env>
                                                                        └ ArgoCD: OTel Collector + kube-state-metrics + 카나리 분석(AMP)
```

- 매니페스트(nebula-gitops)는 모든 환경이 같다. 환경마다 다른 연결 정보는 이 레포가 클러스터에
  `config-<service>` ConfigMap / `secret-<service>` Secret 으로 넣는다 (`modules/environment/services.tf`).
  변수 이름은 nebula-services 의 `src/main/resources/config/*.yml` 플레이스홀더와 1:1 이다.
- 서비스는 OTLP 로 `otel-collector.monitoring.svc:4318`(nebula-gitops `config-common`) 에 텔레메트리를 보내고,
  그 컬렉터는 `enable_aws_platform_apps = true` 일 때 ArgoCD 가 Nebula-Monitoring 차트로 설치한다.

## 환경 전략

| | Dev | Staging | Prod |
|---|---|---|---|
| 질문 | 이 설계는 말이 되나? (Assumption) | 이 가정이 실제로 깨질 수 있나? (Validation) | 사람이 아니라 시스템이 결정할 수 있는가? (Decision) |
| 로컬 | `dev/compose` — 운영 구성요소를 가볍게 복제 | `staging/vagrant` — 노드 장애·지연·경합 재현 | — |
| DB | RDS MySQL 단일 AZ | RDS MySQL **Multi-AZ** | **Aurora MySQL** writer + reader 1 (AZ 분산) |
| Redis | Cluster 1샤드, **선택** (`enable_redis`) | Cluster 1샤드, Multi-AZ | Cluster 2샤드, Multi-AZ, **캐시 전용**(백업 없음) |
| 비동기 | Kafka (Strimzi) | Kafka + **SQS**(+DLQ) | Kafka |
| 진입 | **ALB Ingress** → core-gateway | ALB → **Istio**(PERMISSIVE) → core-gateway | ALB → Istio(**STRICT mTLS**) → core-gateway |
| 노드 | Spot t3.large 계열 2~4 | t3.xlarge 3~6 | m6i.xlarge 3~**9** |
| NAT | 1개 | 1개 | AZ 별 |
| 축소 정책 | 5분 유휴 시 반납 | 기본 10분 | 15분 |
| 로그 보존 | 7일 | 14일 | 90일 |

공통: VPC 3 AZ(public / private / database 서브넷), S3 Gateway Endpoint, EKS 1.31, AWS Load Balancer Controller,
metrics-server, Cluster Autoscaler, ArgoCD, Argo Rollouts(AMP 조회 IRSA), Kyverno, Strimzi.

## 구조

```
environments/
  dev/       main.tf(환경 프로파일) terraform.tf variables.tf outputs.tf  backend.hcl.example  terraform.tfvars.example
    compose/ 로컬 복제본: MySQL · Redis Cluster · Kafka · 서비스(소스 빌드), env/*.env = ConfigMap 과 같은 변수
  staging/   (위와 같음)
    vagrant/ kubeadm 3노드 + chaos/ (latency, node-down, contention, reset)
  prod/      (위와 같음)
modules/
  environment/     환경 하나 = network · eks · data · addons · gitops · services · edge  (+ tests/ mock plan 테스트)
  data/rds         RDS MySQL (dev / staging)
  data/aurora      Aurora MySQL (prod)
  data/redis       ElastiCache Redis (Cluster 모드 지원)
charts/
  nebula-edge/     ALB Ingress (+ Istio Gateway / VirtualService / DestinationRule / PeerAuthentication)
shared/
  terraform-backend/   state 용 S3 + DynamoDB (+ 상태 저장소 CloudWatch 알람)
```

`modules/compute/eks-cluster`, `modules/storage/s3`, `shared/backend`, `shared/iam`, `shared/network` 는 이전 구조의 코드로,
현재 환경에서는 쓰지 않는다.

## 배포

```bash
# 0) state 저장소 (계정당 최초 1회) — S3 버킷 + DynamoDB 락 테이블을 Terraform 으로 만들고
#    environments/{dev,staging,prod}/backend.hcl 을 자동으로 써 준다 (Windows: init-backend.ps1)
cd shared/terraform-backend && ./init-backend.sh

# 1) 환경 (예: dev)
cd ../../environments/dev
cp terraform.tfvars.example terraform.tfvars  # (선택) Auth0·HTTPS 인증서·private gitops 토큰이 있을 때만
terraform init -backend-config=backend.hcl
terraform apply
$(terraform output -raw update_kubeconfig)

# 2) 모니터링 (Nebula-Monitoring, 환경 = workspace)
cd ../../../Nebula-Monitoring/terraform/environments/dev
terraform workspace select -or-create dev   # dev 는 default workspace 도 가능
terraform apply -var environment=dev -var enable_target_monitoring=true -var target_state_bucket=<state 버킷>
../../../scripts/render-gitops-values.sh dev ../../../../nebula-gitops   # → nebula-gitops PR → main

# 3) 모니터링 스택을 ArgoCD 로 동기화
cd ../../../../Nebula-Platform/environments/dev
terraform apply -var enable_aws_platform_apps=true
```

state 저장소를 따로 두는 이유: Terraform 은 state 를 저장할 곳이 먼저 있어야 나머지를 관리할 수 있고,
그 저장소 자신은 자기 state 안에 넣을 수 없다(닭과 달걀). 그래서 `shared/terraform-backend` 만 로컬 state 로 한 번 만들고,
이후 모든 환경은 그 버킷에 state 를 둔다. 임시가 아니라 계속 쓰는 기반 계층이며 지우면 안 된다.
`backend "s3"` 블록은 변수를 쓸 수 없어 버킷 이름을 `backend.hcl` 로 init 때 넘긴다.

apply 순서 안에서 서비스가 먼저 뜨지 않도록 의존성을 걸어 두었다:
EKS → (애드온, Strimzi, Istio) → `backend` 네임스페이스 + 서비스 ConfigMap/Secret + DB 스키마 생성 Job → ArgoCD App of Apps.

> **기존 dev state 가 있다면**: 이전 구조(클러스터 이름 `eks-cluster-<random>`, Aurora 3개)와 리소스 주소·이름이 다르다.
> 그대로 apply 하면 교체(삭제 후 생성) 계획이 나온다. 이전 리소스는 서비스가 쓰지 않던 것이므로 `terraform destroy` 후 새로 만드는 것을 권장한다.

## 서비스 연결 (`modules/environment/services.tf`)

| 리소스 | 내용 |
|---|---|
| `config-gateway`, `config-account` | `ACCOUNT_DB_*`(writer / replica), `REDIS_CLUSTER_NODE_1..6_*`, `PROFILE=kubernetes` |
| `config-order`, `config-product` | `ORDER_DB_*` / `PRODUCT_DB_*`, Redis, `KAFKA_BOOTSTRAP_SERVER1..3` = `market-message-kafka-bootstrap.backend.svc:9092` |
| `config-batch-order` | `ORDER_DB_*` |
| `secret-<service>` | DB 비밀번호, `REDIS_CLUSTER_PASSWORD`, (gateway) `AUTH0_*` |
| `nebula-system/db-bootstrap` Job | `account`, `order`, `product` 스키마 생성 (멱등) |

- replica 데이터소스: prod 는 Aurora reader endpoint, dev / staging 은 writer 와 같은 주소(standby 는 읽기 불가).
- Redis 는 ElastiCache Cluster 모드 + TLS + AUTH. 서비스 설정의 6개 노드 자리에 configuration endpoint 를 넣고 `SPRING_DATA_REDIS_SSL_ENABLED=true`.
- DB·Redis 비밀번호는 `random_password` 로 만들어 Kubernetes Secret 으로만 전달한다 (tfvars 에 비밀번호 없음).

## 목표 지표와 근거

아래 값은 **설계 목표**이고 측정 결과가 아니다. 각 항목은 근거가 되는 구성과 측정 방법을 함께 둔다.

| 지표 | 목표 | 근거가 되는 구성 | 측정 방법 |
|---|---|---|---|
| Failover time ↓ | 90%+ | Aurora reader 자동 승격, Redis Multi-AZ 자동 failover, AZ 별 NAT | `aws rds failover-db-cluster` 실행 후 AMP 에서 5xx 지속 시간 (수동 복구 시간 대비) |
| Peak traffic capacity ↑ | 2–3× | HPA(max 3) + Cluster Autoscaler(prod 노드 3 → 9) | 부하 테스트로 SLO 유지 최대 RPS 를 최소 구성 대비 비교 |
| Unnecessary scale-out ↓ | 30–50% | `least-waste` expander, 환경별 scale-down 임계값·유휴 시간 | Monitoring `05-cost` 규칙의 유휴 비용 / 노드 시간 |
| Failure impact scope ↓ | 70–90% | Istio outlier detection·connection pool, 카나리 50% + 자동 롤백 | `staging/vagrant/chaos` 주입 시 영향받은 요청 비율 |
| Cluster-critical infra ↓ | ~50% | DB·캐시를 관리형으로, 상태는 클러스터 밖 (Kafka 는 아직 클러스터 안) | 클러스터 재생성 시 복구가 필요한 상태 저장 구성요소 수 |

## 검증

```bash
# 세 환경의 plan 을 AWS 없이 검증 (mock provider)
cd modules/environment && terraform init -backend=false && terraform test
```

PR 마다 `.github/workflows/validate.yml` 이 fmt · validate(3개 환경) · test · helm lint · compose · Vagrantfile/셸 문법을 검사한다.

### 서비스 연결 확인 (dev/compose, 2026-10-06)

`env/*.env`(= Terraform 이 만드는 ConfigMap/Secret 과 같은 변수 이름)로 nebula-services `6a5f289` 를 띄우고,
OTLP 를 Nebula-Monitoring `tools/local-stack` 으로 보낸 결과:

| 확인 | 결과 |
|---|---|
| service-order / service-product / service-account 기동 (`PROFILE=kubernetes`, MySQL·Redis Cluster·Kafka) | readiness `UP`, `ddl_auto=update` 로 테이블 생성 |
| 주문 사가: 주문 8건, 재고 5 | `purchase` 발행 8 → 소비 8 → 재고 부족 거절 3 → `refund` → 주문 취소 3 (DB: PENDING 5 / CANCELED 3) |
| 텔레메트리 → Monitoring | span metrics(Kafka `purchase`/`refund` 토픽 차원 포함), `nebula_commerce_funnel_events_total` 단계별 카운터, JVM·HTTP 메트릭이 Prometheus 에 도착 |
| core-gateway | **기동 실패** — 아래 "알려진 한계" |

## 알려진 한계

- **스키마 관리**: nebula-services 에 마이그레이션 도구가 없어 `SPRING_JPA_HIBERNATE_DDL_AUTO=update` 로 테이블을 만든다.
  prod 에서는 Flyway 등으로 바꾸는 것이 다음 단계다 (`service_config.ddl_auto`).
- **DB 계정**: 서비스가 마스터 계정을 쓴다. 서비스별 최소 권한 계정은 아직 없다.
- **SQS**: staging 에 큐와 DLQ, 알람(Nebula-Monitoring)은 있지만 이 큐를 쓰는 서비스 코드는 아직 없다.
- **Vagrant 클러스터**: 플랫폼 계층(ArgoCD 동기화, Kafka, 롤백, 정책)의 실패 양상을 보는 용도다.
  DB·Redis 연결 정보가 없어 서비스 파드는 뜨지 않는다. 서비스 단위 실험은 `dev/compose` 를 함께 쓴다.
- **core-gateway 라우팅**: nebula-services 의 `route.yml` 라우트가 주석 처리되어 있어 게이트웨이가 하위 서비스로 프록시하지 않는다.
  인프라 경로(ALB → 게이트웨이)와 서비스 간 정책(Istio)은 준비되어 있고, 라우트는 서비스 레포에서 켜야 한다.
- **core-gateway 기동 실패 (서비스 코드)**: `6a5f289` 빌드는 환경과 무관하게 시작 단계에서 멈춘다
  (`okta-spring-boot` 가 Spring Boot 3.5 에서 사라진 `OAuth2ResourceServerProperties` 를 찾음). 의존성 정리가 nebula-services 에 필요하다.
- ~~존재하지 않는 상품 조회 시 500~~: `6a5f289` 에서 service-product `BizException` 의 ResourceBundle 초기화가 실패했다.
  nebula-services `36bdc86` 이 `yaml-resource-bundle` 을 2.15.0 으로 고정해 원인이 해소되었다 (이 레포에서 재실행 확인은 하지 않음).
- **EKS 버전**: 1.31 은 표준 지원이 끝나 연장 지원 요금이 붙는다. 1.32 → 1.33 순차 업그레이드가 필요하다 (`cluster_version`).
