output "environment" {
  description = "환경 이름"
  value       = var.environment
}

output "cluster_name" {
  description = "EKS 클러스터 이름 (Nebula-Monitoring 이 remote state 로 읽는다)"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS CA"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_arn" {
  description = "EKS 클러스터 ARN"
  value       = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  description = "IRSA OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# ---- Nebula-Monitoring 데이터 스토어 알람 대상 ----
output "aurora_cluster_identifiers" {
  description = "Aurora 클러스터 ID (prod). 없으면 빈 목록"
  value       = [for a in module.aurora : a.cluster_id]
}

output "rds_instance_identifiers" {
  description = "RDS 인스턴스 ID (dev / staging). 없으면 빈 목록"
  value       = [for r in module.rds : r.identifier]
}

output "redis_replication_group_ids" {
  description = "ElastiCache Redis replication group ID"
  value       = [for r in module.redis : r.replication_group_id]
}

output "sqs_queue_names" {
  description = "SQS 큐 이름 (staging). DLQ 포함"
  value       = concat([for q in aws_sqs_queue.order_events : q.name], [for q in aws_sqs_queue.order_events_dlq : q.name])
}

# ---- 서비스 연결 ----
output "db_writer_endpoint" {
  description = "서비스 DB writer 엔드포인트"
  value       = local.db_writer_host
}

output "db_reader_endpoint" {
  description = "서비스 DB reader 엔드포인트 (Aurora reader, RDS 는 writer 와 같음)"
  value       = local.db_reader_host
}

output "redis_endpoint" {
  description = "Redis configuration endpoint (Redis 를 끄면 빈 값)"
  value       = try(module.redis[0].endpoint_address, "")
}

output "alb_hostname" {
  description = "서비스 진입 ALB DNS (생성 직후에는 비어 있을 수 있음 → 다시 apply 또는 kubectl get ingress)"
  value       = try(data.kubernetes_ingress_v1.edge.status[0].load_balancer[0].ingress[0].hostname, "")
}
