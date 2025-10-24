# ========================================
# Terraform Backend Infrastructure
# S3 + DynamoDB for State Management
# ========================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ========================================
# S3 Bucket for Terraform State
# ========================================
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true  # State 버킷 실수 삭제 방지
  }

  tags = {
    Name        = "Terraform State Store"
    Environment = "shared"
    ManagedBy   = "terraform"
    Purpose     = "terraform-state"
  }
}

# S3 버킷 버저닝 (State 히스토리 관리)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 암호화 (보안)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 버킷 퍼블릭 액세스 차단 (보안)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 버킷 라이프사이클 정책 (비용 최적화)
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90  # 90일 이상된 이전 버전 삭제
    }
  }
}

# ========================================
# DynamoDB Table for State Locking
# ========================================
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"  # 온디맨드 요금제 (비용 효율적)
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true  # Lock 테이블 실수 삭제 방지
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "shared"
    ManagedBy   = "terraform"
    Purpose     = "terraform-state-lock"
  }
}

# ========================================
# IAM Policy for Backend Access
# ========================================
resource "aws_iam_policy" "terraform_backend_policy" {
  name        = "TerraformBackendAccess"
  path        = "/"
  description = "Policy for accessing Terraform backend resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_locks.arn
      }
    ]
  })
}
