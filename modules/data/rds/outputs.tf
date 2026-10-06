# ========================================
# RDS Module Outputs
# ========================================

output "identifier" {
  description = "DB instance identifier (CloudWatch DBInstanceIdentifier 차원)"
  value       = aws_db_instance.rds.identifier
}

output "address" {
  description = "Endpoint hostname"
  value       = aws_db_instance.rds.address
}

output "port" {
  description = "Port"
  value       = aws_db_instance.rds.port
}

output "arn" {
  description = "DB instance ARN"
  value       = aws_db_instance.rds.arn
}

output "multi_az" {
  description = "Multi-AZ enabled"
  value       = aws_db_instance.rds.multi_az
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.rds.id
}
