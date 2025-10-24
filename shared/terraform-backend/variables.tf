# ========================================
# Variables for Terraform Backend
# ========================================

variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "mycompany-terraform-state-bucket"  # 고유한 이름으로 변경 필요!
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-locks"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Infrastructure"
    ManagedBy   = "Terraform"
    Environment = "Shared"
  }
}
