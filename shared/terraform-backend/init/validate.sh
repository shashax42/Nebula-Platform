#!/bin/bash
# ========================================
# Terraform 코드 검증 스크립트
# ========================================

set -e

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔍 Terraform 코드 검증 시작${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 검증 대상 디렉토리
TERRAFORM_DIRS=(
  "shared/terraform-backend"
  "environments/dev"
  "environments/staging"
  "environments/prod"
)

# 전체 결과 저장
TOTAL_ERRORS=0
VALIDATION_RESULTS=""

# 각 디렉토리 검증
for DIR in "${TERRAFORM_DIRS[@]}"; do
  echo -e "${YELLOW}📁 검증 중: $DIR${NC}"
  
  if [ ! -d "../../$DIR" ]; then
    echo -e "${RED}  ❌ 디렉토리가 존재하지 않습니다${NC}"
    ((TOTAL_ERRORS++))
    continue
  fi
  
  cd "../../$DIR"
  
  # 1. Terraform 초기화
  echo -e "  1️⃣ terraform init 실행..."
  if terraform init -backend=false -upgrade > /dev/null 2>&1; then
    echo -e "${GREEN}    ✅ 초기화 성공${NC}"
  else
    echo -e "${RED}    ❌ 초기화 실패${NC}"
    ((TOTAL_ERRORS++))
  fi
  
  # 2. Terraform Format 검사
  echo -e "  2️⃣ terraform fmt 검사..."
  FMT_OUTPUT=$(terraform fmt -check -recursive -diff 2>&1)
  if [ -z "$FMT_OUTPUT" ]; then
    echo -e "${GREEN}    ✅ 포맷 검사 통과${NC}"
  else
    echo -e "${RED}    ❌ 포맷 수정 필요:${NC}"
    echo "$FMT_OUTPUT"
    ((TOTAL_ERRORS++))
  fi
  
  # 3. Terraform Validate 검사
  echo -e "  3️⃣ terraform validate 실행..."
  VALIDATE_OUTPUT=$(terraform validate 2>&1)
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}    ✅ 구문 검증 통과${NC}"
  else
    echo -e "${RED}    ❌ 구문 오류 발견:${NC}"
    echo "$VALIDATE_OUTPUT"
    ((TOTAL_ERRORS++))
  fi
  
  # 4. tflint 검사 (설치되어 있는 경우)
  if command -v tflint &> /dev/null; then
    echo -e "  4️⃣ tflint 검사..."
    TFLINT_OUTPUT=$(tflint --init 2>&1 && tflint 2>&1)
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}    ✅ Lint 검사 통과${NC}"
    else
      echo -e "${YELLOW}    ⚠️  Lint 경고:${NC}"
      echo "$TFLINT_OUTPUT"
    fi
  else
    echo -e "${YELLOW}  4️⃣ tflint가 설치되지 않음 (선택사항)${NC}"
  fi
  
  # 5. 보안 검사 (tfsec 설치되어 있는 경우)
  if command -v tfsec &> /dev/null; then
    echo -e "  5️⃣ tfsec 보안 검사..."
    TFSEC_OUTPUT=$(tfsec . --no-color 2>&1)
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}    ✅ 보안 검사 통과${NC}"
    else
      echo -e "${YELLOW}    ⚠️  보안 이슈 발견:${NC}"
      echo "$TFSEC_OUTPUT"
    fi
  else
    echo -e "${YELLOW}  5️⃣ tfsec이 설치되지 않음 (선택사항)${NC}"
  fi
  
  echo ""
  cd - > /dev/null
done

# 최종 결과
echo -e "${BLUE}========================================${NC}"
if [ $TOTAL_ERRORS -eq 0 ]; then
  echo -e "${GREEN}✅ 모든 검증 통과!${NC}"
  echo -e "${GREEN}코드를 커밋할 준비가 되었습니다.${NC}"
else
  echo -e "${RED}❌ 총 ${TOTAL_ERRORS}개의 오류 발견${NC}"
  echo -e "${RED}위의 오류를 수정한 후 다시 실행해주세요.${NC}"
  exit 1
fi
echo -e "${BLUE}========================================${NC}"

# 추가 권장사항
echo ""
echo -e "${YELLOW}📚 추가 도구 설치 권장:${NC}"
echo "  • tflint: https://github.com/terraform-linters/tflint"
echo "  • tfsec: https://github.com/aquasecurity/tfsec"
echo "  • checkov: pip install checkov"
