# ========================================
# Outputs for Terraform Backend
# ========================================

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.region
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "backend_config_example" {
  description = "Example backend configuration for terraform.tf"
  value = <<EOT

# Add this to your terraform.tf file:
terraform {
  backend "s3" {
    bucket         = "${aws_s3_bucket.terraform_state.id}"
    key            = "env/YOUR_ENV/terraform.tfstate"
    region         = "${var.aws_region}"
    encrypt        = true
    dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
  }
}
EOT
}
