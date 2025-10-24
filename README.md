# **Nebula-Platform - Enterprise Terraform Infrastructure**

**Nebula-Platform**은 AWS 기반 인프라(EKS, Aurora, Redis)를 Terraform으로 관리하는 엔터프라이즈급 클라우드 플랫폼입니다.
기존 프로젝트를 전반적으로 리팩토링하여 모듈화된 아키텍처를 구현하였습니다.

## **프로젝트 구조**

```
refact_terra/
├── environments/              #  환경별 구성 파일
│   ├── dev/                  # 개발 환경
│   ├── staging/              # 스테이징 환경
│   └── prod/                 # 프로덕션 환경
│
├── modules/                  #  재사용 가능한 모듈
│   ├── compute/
│   │   └── eks-cluster/      # EKS 클러스터 모듈
│   ├── data/
│   │   ├── aurora/           # Aurora 클러스터 모듈
│   │   └── redis/            # Redis 클러스터 모듈
│   └── storage/
│       └── s3/               # S3 버킷 모듈
│
├── shared/                   #  공통 인프라
│   ├── terraform-backend/    # S3 + DynamoDB 백엔드 구성
│   └── backend-config/       # 환경별 백엔드 설정
│
└── scripts/                  #  배포 및 자동화 스크립트
```

---

## **주요 특징**

### **모듈화된 아키텍처**

* **중복 제거**: Aurora 클러스터 3개를 하나의 모듈로 통합
* **표준화**: 모든 모듈이 동일한 변수명과 태깅 규칙을 따름
* **재사용성 향상**: 환경마다 필요한 파라미터만 변경 가능

### **엔터프라이즈 보안**

* S3 + DynamoDB로 Terraform State 관리
* 모든 데이터 암호화 (KMS 적용)
* IAM 최소 권한 원칙(Least Privilege) 적용
* VPC 엔드포인트 기반 내부 통신 보장

### **환경별 최적화**

* **Dev**: 비용 효율 중심 (소형 인스턴스, 짧은 백업 주기)
* **Staging**: 프로덕션 유사 구조
* **Prod**: 고가용성(HA) 및 강화된 보안 정책

---

## **시작**


### **1. 백엔드 인프라 구축**

```bash
cd shared/terraform-backend
terraform init
terraform apply
```

### **2. 환경별 배포**

```bash
# Dev 환경
cd environments/dev
terraform init -backend-config="../../shared/backend-config/dev.hcl"
terraform apply

# Staging 환경
cd environments/staging
terraform init -backend-config="../../shared/backend-config/staging.hcl"
terraform apply
```

---

## **환경 설정 예시 (terraform.tfvars)**

```hcl
# 기본 설정
aws_region   = "ap-northeast-2"
network_cidr = "10.0.0.0/16"

# 데이터베이스 설정
rds_username = "admin"
rds_password = "your-secure-password"
rds_db_name1 = "maindb"
rds_db_name2 = "analyticsdb"
rds_db_name3 = "reportingdb"

# 공통 태그
common_tags = {
  Project     = "Nebula-Platform"
  Environment = "dev"
  Team        = "platform"
}
```

---

## **프로비저닝되는 주요 리소스**

### **Compute**

* **Amazon EKS 클러스터 (v1.31)**
* **Managed Node Group**
* **EKS 애드온 (CoreDNS, VPC-CNI, Kube-proxy)**

### **Database**

* **Aurora MySQL 클러스터** (main, analytics, reporting)
* **ElastiCache Redis** (세션/캐시 용도)

### **Network**

* **VPC (Multi-AZ 구성)**
* **Public / Private / Internal Subnet**
* **NAT / Internet Gateway**
* **보안 그룹 구성**

### **Storage**

* **S3 버킷** (암호화 및 버전 관리 활성화)

---

## **모듈 활용 예시**

### **Aurora 클러스터 추가**

```hcl
module "aurora_new" {
  source = "../../modules/data/aurora"
  
  name_prefix = "new-service"
  environment = "dev"

  instance_class  = "db.t3.large"
  instance_count  = 3
}
```

### **Redis 클러스터 추가**

```hcl
module "redis_sessions" {
  source = "../../modules/data/redis"

  name_prefix        = "sessions"
  environment        = "dev"
  node_type          = "cache.t3.small"
  num_cache_clusters = 2
}
```

---

## **개발 및 확장 가이드**

### **새 모듈 추가**

1. `modules/` 디렉터리 하위에 적절한 카테고리 생성
2. `main.tf`, `variables.tf`, `outputs.tf` 파일 작성
3. 표준 변수명(`name_prefix`, `environment`, `tags`)을 사용

### **새 환경 추가**

1. `environments/` 하위에 폴더 생성
2. 기존 환경 폴더의 파일을 복사 후 수정
3. `shared/backend-config/`에 해당 환경용 설정 파일 추가

---

## **모니터링 및 운영**

### **CloudWatch 대시보드**

* EKS 클러스터 메트릭
* Aurora 성능 지표
* Redis 캐시 히트율

### **알람 설정**

* 데이터베이스 CPU 사용률 초과
* EKS 노드 비정상 상태
* Terraform State Lock 장기 점유

---

## **보안 모범 사례**

* 모든 데이터베이스 암호화 (KMS)
* 내부 VPC 통신만 허용
* IAM 최소 권한 정책
* 정기 백업 자동화
* Terraform State 파일 암호화

---

## **문제 해결 가이드**

1. **Terraform 버전**: 1.8 이상인지 확인
2. **AWS CLI**: 올바른 프로필 및 권한 설정
3. **백엔드 상태**: S3 버킷과 DynamoDB 테이블이 정상 존재하는지 확인