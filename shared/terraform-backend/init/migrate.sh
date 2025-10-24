#!/bin/bash
# ========================================
# Terraform State 마이그레이션 스크립트
# 로컬 State → S3 Backend 자동 마이그레이션
# ========================================

set -e

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔄 Terraform State 마이그레이션${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 설정 확인
echo -e "${YELLOW}⚠️  주의사항:${NC}"
echo "  1. 현재 로컬 state가 백업됩니다"
echo "  2. S3 버킷과 DynamoDB 테이블이 이미 생성되어 있어야 합니다"
echo "  3. AWS 자격 증명이 설정되어 있어야 합니다"
echo ""
read -p "계속하시겠습니까? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}마이그레이션이 취소되었습니다.${NC}"
    exit 1
fi

# 환경 선택
echo -e "${YELLOW}마이그레이션할 환경을 선택하세요:${NC}"
echo "  1) dev"
echo "  2) staging"
echo "  3) prod"
echo "  4) 모든 환경"
read -p "선택 (1-4): " ENV_CHOICE

case $ENV_CHOICE in
    1) ENVIRONMENTS=("dev") ;;
    2) ENVIRONMENTS=("staging") ;;
    3) ENVIRONMENTS=("prod") ;;
    4) ENVIRONMENTS=("dev" "staging" "prod") ;;
    *) echo -e "${RED}잘못된 선택입니다.${NC}" && exit 1 ;;
esac

# S3 버킷 이름 입력
read -p "S3 버킷 이름을 입력하세요: " BUCKET_NAME
if [ -z "$BUCKET_NAME" ]; then
    echo -e "${RED}버킷 이름이 필요합니다.${NC}"
    exit 1
fi

# 버킷 존재 확인
echo -e "${YELLOW}S3 버킷 확인 중...${NC}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✅ S3 버킷이 존재합니다.${NC}"
else
    echo -e "${RED}❌ S3 버킷을 찾을 수 없습니다.${NC}"
    exit 1
fi

# DynamoDB 테이블 확인
echo -e "${YELLOW}DynamoDB 테이블 확인 중...${NC}"
TABLE_NAME="terraform-state-locks"
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region ap-northeast-2 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ DynamoDB 테이블이 존재합니다.${NC}"
else
    echo -e "${RED}❌ DynamoDB 테이블을 찾을 수 없습니다.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}마이그레이션 시작...${NC}"
echo ""

# 백업 디렉토리 생성
BACKUP_DIR="../../state-backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 각 환경 마이그레이션
for ENV in "${ENVIRONMENTS[@]}"; do
    echo -e "${YELLOW}📁 $ENV 환경 마이그레이션${NC}"
    
    ENV_DIR="../../environments/$ENV"
    if [ ! -d "$ENV_DIR" ]; then
        echo -e "${RED}  ❌ 디렉토리가 존재하지 않습니다: $ENV_DIR${NC}"
        continue
    fi
    
    cd "$ENV_DIR"
    
    # 1. 현재 state 백업
    echo -e "  1️⃣ 현재 state 백업 중..."
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate "$BACKUP_DIR/${ENV}_terraform.tfstate.backup"
        echo -e "${GREEN}    ✅ 백업 완료: $BACKUP_DIR/${ENV}_terraform.tfstate.backup${NC}"
    else
        echo -e "${YELLOW}    ⚠️  로컬 state 파일이 없습니다 (신규 환경)${NC}"
    fi
    
    # 2. Backend 설정 확인
    echo -e "  2️⃣ Backend 설정 확인..."
    if grep -q 'backend "s3"' terraform.tf; then
        echo -e "${GREEN}    ✅ S3 backend 설정이 있습니다${NC}"
    else
        echo -e "${RED}    ❌ terraform.tf에 S3 backend 설정이 없습니다${NC}"
        echo -e "${YELLOW}    다음 설정을 terraform.tf에 추가하세요:${NC}"
        cat <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "env/$ENV/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "$TABLE_NAME"
  }
}
EOF
        continue
    fi
    
    # 3. terraform init 실행
    echo -e "  3️⃣ terraform init 실행 (마이그레이션)..."
    
    # Backend 설정 파일 사용 여부 확인
    BACKEND_CONFIG="../../shared/backend-config/${ENV}.hcl"
    if [ -f "$BACKEND_CONFIG" ]; then
        echo -e "${YELLOW}    Backend 설정 파일 사용: $BACKEND_CONFIG${NC}"
        terraform init -migrate-state -backend-config="$BACKEND_CONFIG" -force-copy
    else
        terraform init -migrate-state -force-copy
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}    ✅ 마이그레이션 성공!${NC}"
        
        # 4. State 확인
        echo -e "  4️⃣ Remote state 확인..."
        if terraform state list > /dev/null 2>&1; then
            RESOURCE_COUNT=$(terraform state list | wc -l)
            echo -e "${GREEN}    ✅ Remote state 확인 완료 (리소스: $RESOURCE_COUNT개)${NC}"
        else
            echo -e "${YELLOW}    ⚠️  State가 비어있습니다${NC}"
        fi
    else
        echo -e "${RED}    ❌ 마이그레이션 실패!${NC}"
        echo -e "${YELLOW}    백업 파일: $BACKUP_DIR/${ENV}_terraform.tfstate.backup${NC}"
    fi
    
    echo ""
    cd - > /dev/null
done

# 최종 확인
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}📊 마이그레이션 결과${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

for ENV in "${ENVIRONMENTS[@]}"; do
    echo -e "${YELLOW}$ENV 환경:${NC}"
    
    # S3에서 state 파일 확인
    if aws s3 ls "s3://$BUCKET_NAME/env/$ENV/terraform.tfstate" > /dev/null 2>&1; then
        STATE_SIZE=$(aws s3 ls "s3://$BUCKET_NAME/env/$ENV/terraform.tfstate" | awk '{print $3}')
        echo -e "${GREEN}  ✅ S3 state 파일 존재 (크기: $STATE_SIZE bytes)${NC}"
    else
        echo -e "${RED}  ❌ S3 state 파일 없음${NC}"
    fi
done

echo ""
echo -e "${GREEN}백업 위치: $BACKUP_DIR${NC}"
echo ""

# 정리 안내
echo -e "${YELLOW}📝 마이그레이션 후 확인 사항:${NC}"
echo "  1. 각 환경에서 terraform plan 실행하여 변경사항 없음 확인"
echo "  2. 로컬 terraform.tfstate 파일 삭제 (백업 확인 후)"
echo "  3. .gitignore에 *.tfstate* 포함 확인"
echo ""
echo -e "${BLUE}========================================${NC}"
