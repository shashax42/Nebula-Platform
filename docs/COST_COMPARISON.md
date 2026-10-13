# 운영 비용 비교: 리팩토링 전 vs 현재 prod

> **요약**: 같은 AWS 요금표로 계산하면 prod 인프라 비용은 시간당 **$1.73 → $1.02 (약 41% 감소)**.
> 관리형 모니터링(AMP·AMG·CloudWatch)까지 더하면 **약 32~36% 감소**.
>
> 이 숫자는 **실제 청구액이 아니라 구성(아키텍처) 기준 추정**이다. 현재 prod 는 **적정 크기 가정**이며,
> 부하 테스트 결과 노드 수나 DB 크기를 올리면 비용과 절감률이 달라진다 (아래 [5. 달라질 수 있는 조건](#5-달라질-수-있는-조건)).

## 1. 비교 대상

| | 리팩토링 전 | 현재 prod |
|---|---|---|
| 출처 | 이 레포 첫 커밋 `2fd5e6f` 의 `environments/dev` | `environments/prod/main.tf` |
| 설명 | 리팩토링 전에는 dev·staging 검증을 로컬(Docker Compose, Vagrant)에서 했고, AWS 에는 이 구성 하나만 띄웠다. 그래서 이 구성이 당시의 운영(prod) 비용이다 | Multi-AZ·reader·AZ 별 NAT 등 가용성 구조는 유지하고 인스턴스 크기만 적정 크기로 맞춘 구성 |

## 2. 단가 (AWS 서울 리전 ap-northeast-2, On-Demand, 2026-10 공개 요금표)

AWS Price List 파일(`https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/<서비스>/current/ap-northeast-2/index.csv`)에서 옮겨 적었다.

| 항목 | 단가 |
|---|---|
| EKS 클러스터 | $0.10 / 시간 |
| EC2 t3.xlarge / m6i.large (Linux) | $0.208 / $0.118 / 시간 |
| NAT Gateway | $0.059 / 시간 |
| Aurora MySQL db.t3.medium / db.t4g.medium | $0.125 / $0.113 / 시간 |
| ElastiCache Redis cache.t3.micro / cache.t4g.small | $0.025 / $0.047 / 시간 |
| Load Balancer (NLB·ALB 시간 요금) | $0.0225 / 시간, ALB LCU $0.008 / LCU-시간 |
| EBS gp3 | $0.0912 / GB-월 |
| AMP 수집 | 월 4천만 샘플 무료, 이후 $0.90 / 1천만 샘플 |
| CloudWatch Logs 수집 / 저장 | $0.76 / GB, $0.0314 / GB-월 |
| CloudWatch 커스텀 메트릭 / 알람 | $0.30 / 메트릭-월, $0.10 / 알람-월 |
| AMG Editor | $9 / 사용자-월 |
| X-Ray | 월 10만 트레이스 저장 무료 |

## 3. 인프라 비용 (시간당)

| 항목 | 리팩토링 전 | 현재 prod | 차이 |
|---|---|---|---|
| EKS | $0.100 | $0.100 | |
| 노드 | t3.xlarge × 3 = $0.624 | m6i.large × 3 = $0.354 | 크기 적정화 |
| NAT | 1개 = $0.059 | AZ 별 3개 = $0.177 | **가용성 투자** (AZ 장애 시 외부 통신 유지) |
| DB | Aurora db.t3.medium **7대** (main 2 + analytics 3 + reporting 2) = $0.875 | Aurora db.t4g.medium 2대 (writer + reader) = $0.226 | 쓰이지 않던 analytics·reporting 클러스터 제거, Graviton |
| Redis | cache.t3.micro × 2 = $0.050 | cache.t4g.small × 2 (Multi-AZ) = $0.094 | 세션 저장소라 메모리 여유 확보 |
| 로드밸런서 | NLB = $0.023 | ALB (+1 LCU) = $0.031 | L7 라우팅 |
| Kafka 볼륨 | 없음 (ephemeral) | gp3 330GB (브로커 100Gi × 3 + 컨트롤러 10Gi × 3) = $0.041 | **내구성 투자** (재시작 시 메시지 유실 방지) |
| **합계** | **$1.731** | **$1.023** | **−40.9%** |
| 30분 환산 (₩1,350/$) | 약 1,170원 | 약 690원 | |

## 4. 모니터링 비용 (현재 prod, 월 → 시간당)

리팩토링 전 모니터링은 클러스터 안에서 돌아 노드 비용에 포함돼 있다. 현재는 관리형 서비스라 따로 더한다.
데이터량은 Nebula-Monitoring `docs/OBSERVABILITY_DATA_PIPELINE.md` 의 카디널리티·샘플링 예산을 따르고,
활성 시리즈 수는 아직 측정 전이라 세 구간으로 계산한다.

| 항목 | 가정 | 월 비용 |
|---|---|---|
| AMP 수집 | 활성 시리즈 3천 / 6천 / 1만, 30초 간격 (시리즈당 월 87,600 샘플) | $20.1 / $43.7 / $75.2 |
| CloudWatch Logs | prod INFO 이상, 하루 1GB 수집, 90일 보존 | $26.0 |
| EMF 커스텀 메트릭 | SLI 3종 × (서비스 5 + 1) = 18개 | $5.4 |
| CloudWatch 알람 | 약 20개 | $2.0 |
| X-Ray | baseline 5% + 오류·지연 100% → 무료 구간 안 (월 10만 트레이스 이하 가정) | $0 |
| AMG | Editor 1명 | $9.0 |
| **합계** | | **$62.4 / $86.1 / $117.6** (시간당 $0.086 / $0.118 / $0.161) |

| | 리팩토링 전 | 현재 prod (인프라 + 모니터링) | 차이 |
|---|---|---|---|
| 시간당 | $1.731 | $1.108 / $1.141 / $1.184 | **−36.0% / −34.1% / −31.6%** |

모니터링 비용이 이 정도로 묶이는 건 수집 단계에서 데이터를 줄였기 때문이다: scrape·KSM 허용 목록, span metrics 카디널리티 상한, tail sampling, 로그 레벨 필터, 지표별 보존 범위 분리.

## 5. 달라질 수 있는 조건

- **적정 크기 가정**: m6i.large 3대(vCPU 6, 메모리 24GiB)에 서비스, Kafka(브로커·컨트롤러 6), Istio, ArgoCD 가 올라간다. 부하 테스트 전이라 충분한지 확인되지 않았다.
  노드가 상시 4대면 인프라 감소율은 약 34%, m6i.xlarge 3대면 약 20% 로 줄어든다.
- **burstable 인스턴스**: db.t4g.medium, cache.t4g.small 은 CPU 크레딧 방식이다. 꾸준히 높은 부하에서는 r 계열로 올려야 한다.
- **빠진 항목 (양쪽 모두 제외)**: 데이터 전송, NAT 처리량(GB 당), Aurora 스토리지·I/O, 노드 루트 볼륨, 백업 스토리지. 데이터 양과 트래픽에 따라 달라져 구성 비교에서 뺐다.
- **On-Demand 기준**: Savings Plans·RI·Spot 할인은 반영하지 않았다.
- **환율**: ₩1,350/$ 가정.

## 6. 실측으로 바꾸는 방법

1. prod 를 짧게 apply 하고 k6 로 목표 트래픽을 준다 → 노드 수가 3대로 유지되는지, DB CPU 크레딧이 남는지 확인
2. 같은 시간 동안의 Cost Explorer(서비스별) 금액을 이 표와 비교
3. 모니터링은 Nebula-Monitoring `docs/COST_ESTIMATE.md` 의 측정 쿼리로 활성 시리즈·로그량을 채운다
4. 측정값으로 이 문서와 README 의 숫자를 바꾸고, 측정일과 트래픽 규모를 함께 적는다
