# ========================================
# Aurora Module Outputs
# ========================================

output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.aurora.id
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.aurora.arn
}

output "cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.aurora.port
}

output "cluster_master_username" {
  description = "Aurora cluster master username"
  value       = aws_rds_cluster.aurora.master_username
  sensitive   = true
}

output "cluster_database_name" {
  description = "Aurora cluster database name"
  value       = aws_rds_cluster.aurora.database_name
}

output "cluster_resource_id" {
  description = "Aurora cluster resource ID"
  value       = aws_rds_cluster.aurora.cluster_resource_id
}

output "cluster_hosted_zone_id" {
  description = "Aurora cluster hosted zone ID"
  value       = aws_rds_cluster.aurora.hosted_zone_id
}

output "security_group_id" {
  description = "Aurora security group ID"
  value       = aws_security_group.aurora.id
}

output "instance_ids" {
  description = "Aurora instance IDs"
  value       = aws_rds_cluster_instance.aurora[*].id
}

output "instance_endpoints" {
  description = "Aurora instance endpoints"
  value       = aws_rds_cluster_instance.aurora[*].endpoint
}

output "cluster_members" {
  description = "Aurora cluster members"
  value       = aws_rds_cluster.aurora.cluster_members
}
