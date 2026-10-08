# ========================================
# Terraform Backend 초기 설정 스크립트 (Windows)
# ========================================

Write-Host "🚀 Terraform Backend Infrastructure 초기화 중..." -ForegroundColor Green
Write-Host ""

# 1. 고유한 S3 버킷 이름 생성
Write-Host "Step 1: S3 버킷 이름 설정" -ForegroundColor Yellow
$BUCKET_NAME = Read-Host "S3 버킷 이름을 입력하세요 (예: mycompany-terraform-state)"

if ([string]::IsNullOrEmpty($BUCKET_NAME)) {
    # 기본값: terraform-state-랜덤문자열
    $RANDOM_SUFFIX = -join ((97..122) + (48..57) | Get-Random -Count 8 | ForEach-Object {[char]$_})
    $BUCKET_NAME = "terraform-state-$RANDOM_SUFFIX"
    Write-Host "기본 버킷 이름 사용: $BUCKET_NAME" -ForegroundColor Green
}

# 2. AWS Region 설정
Write-Host "Step 2: AWS Region 설정" -ForegroundColor Yellow
$AWS_REGION = Read-Host "AWS Region을 입력하세요 (기본값: ap-northeast-2)"
if ([string]::IsNullOrEmpty($AWS_REGION)) {
    $AWS_REGION = "ap-northeast-2"
}

# 3. terraform.tfvars 파일 생성
Write-Host "Step 3: terraform.tfvars 파일 생성" -ForegroundColor Yellow
@"
state_bucket_name   = "$BUCKET_NAME"
dynamodb_table_name = "terraform-state-locks"
aws_region         = "$AWS_REGION"
"@ | Out-File -FilePath terraform.tfvars -Encoding ascii

Write-Host "✅ terraform.tfvars 파일이 생성되었습니다." -ForegroundColor Green

# 4. Backend 인프라 배포
Write-Host "Step 4: Backend 인프라 배포" -ForegroundColor Yellow
terraform init
terraform plan

Write-Host ""
Read-Host "위 계획을 확인하셨나요? 계속하려면 Enter를 누르세요"
terraform apply -auto-approve

# 5. 출력 값 저장
Write-Host "Step 5: 설정 정보 저장" -ForegroundColor Yellow
$BUCKET = terraform output -raw s3_bucket_name
$TABLE = terraform output -raw dynamodb_table_name
$REGION = terraform output -raw s3_bucket_region

# 6. 환경별 backend 설정 파일 업데이트
Write-Host "Step 6: 환경별 backend 설정 파일 업데이트" -ForegroundColor Yellow

foreach ($ENV in @("dev", "staging", "prod")) {
    $content = @"
# Backend configuration for $ENV environment
bucket         = "$BUCKET"
key            = "env/$ENV/terraform.tfstate"
region         = "$REGION"
encrypt        = true
dynamodb_table = "$TABLE"
"@
    $content | Out-File -FilePath "../../environments/$ENV/backend.hcl" -Encoding ascii
    Write-Host "✅ $ENV.hcl 파일이 업데이트되었습니다." -ForegroundColor Green
}

# 7. 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "🎉 Terraform Backend 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "다음 정보를 안전하게 보관하세요:"
Write-Host "- S3 Bucket: $BUCKET"
Write-Host "- DynamoDB Table: $TABLE"
Write-Host "- Region: $REGION"
Write-Host ""
Write-Host "각 환경에서 사용 방법:"
Write-Host '  cd environments\dev'
Write-Host '  terraform init -backend-config=backend.hcl'
Write-Host ""
Write-Host "⚠️  주의: 이 Backend 인프라는 절대 삭제하지 마세요!" -ForegroundColor Yellow
