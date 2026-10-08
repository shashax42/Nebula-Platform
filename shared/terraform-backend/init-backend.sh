#!/bin/bash
# ========================================
# Terraform Backend 초기 설정 스크립트
# ========================================

set -e

echo "🚀 Terraform Backend Infrastructure 초기화 중..."
echo ""

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 고유한 S3 버킷 이름 생성
echo -e "${YELLOW}Step 1: S3 버킷 이름 설정${NC}"
read -p "S3 버킷 이름을 입력하세요 (예: mycompany-terraform-state): " BUCKET_NAME

if [ -z "$BUCKET_NAME" ]; then
    # 기본값: 회사명-terraform-state-랜덤문자열
    RANDOM_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
    BUCKET_NAME="terraform-state-${RANDOM_SUFFIX}"
    echo -e "${GREEN}기본 버킷 이름 사용: $BUCKET_NAME${NC}"
fi

# 2. AWS Region 설정
echo -e "${YELLOW}Step 2: AWS Region 설정${NC}"
read -p "AWS Region을 입력하세요 (기본값: ap-northeast-2): " AWS_REGION
AWS_REGION=${AWS_REGION:-ap-northeast-2}

# 3. terraform.tfvars 파일 생성
echo -e "${YELLOW}Step 3: terraform.tfvars 파일 생성${NC}"
cat > terraform.tfvars <<EOF
state_bucket_name   = "${BUCKET_NAME}"
dynamodb_table_name = "terraform-state-locks"
aws_region         = "${AWS_REGION}"
EOF

echo -e "${GREEN}✅ terraform.tfvars 파일이 생성되었습니다.${NC}"

# 4. Backend 인프라 배포
echo -e "${YELLOW}Step 4: Backend 인프라 배포${NC}"
terraform init
terraform plan
echo ""
read -p "위 계획을 확인하셨나요? 계속하려면 Enter를 누르세요..."
terraform apply -auto-approve

# 5. 출력 값 저장
echo -e "${YELLOW}Step 5: 설정 정보 저장${NC}"
BUCKET=$(terraform output -raw s3_bucket_name)
TABLE=$(terraform output -raw dynamodb_table_name)
REGION=$(terraform output -raw s3_bucket_region)

# 6. 환경별 backend 설정 파일 업데이트
echo -e "${YELLOW}Step 6: 환경별 backend 설정 파일 업데이트${NC}"

for ENV in dev staging prod; do
    cat > ../../environments/${ENV}/backend.hcl <<EOF
# Backend configuration for ${ENV} environment
bucket         = "${BUCKET}"
key            = "env/${ENV}/terraform.tfstate"
region         = "${REGION}"
encrypt        = true
dynamodb_table = "${TABLE}"
EOF
    echo -e "${GREEN}✅ environments/${ENV}/backend.hcl 생성${NC}"
done

# 7. 완료 메시지
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Terraform Backend 설정이 완료되었습니다!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "다음 정보를 안전하게 보관하세요:"
echo "- S3 Bucket: ${BUCKET}"
echo "- DynamoDB Table: ${TABLE}"
echo "- Region: ${REGION}"
echo ""
echo "각 환경에서 사용 방법:"
echo "  cd environments/dev"
echo "  terraform init -backend-config=backend.hcl"
echo ""
echo -e "${YELLOW}⚠️  주의: 이 Backend 인프라는 절대 삭제하지 마세요!${NC}"
