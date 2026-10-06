# Nebula-Monitoring(terraform/environments/dev/target-infrastructure.tf)이 이 상태 파일의 output 을 remote state 로 읽는다.
# 이름을 바꾸면 Monitoring 쪽도 같이 바꿔야 한다.

output "environment" {
  value = module.platform.environment
}

output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.platform.cluster_name
}

output "cluster_apiserver" {
  description = "EKS API 엔드포인트"
  value       = module.platform.cluster_endpoint
}

output "aurora_cluster_identifiers" {
  description = "Aurora 클러스터 ID (Monitoring: Aurora CPU·데드락·복제 지연 알람)"
  value       = module.platform.aurora_cluster_identifiers
}

output "rds_instance_identifiers" {
  description = "RDS 인스턴스 ID (Monitoring: RDS CPU·스토리지·연결 수 알람)"
  value       = module.platform.rds_instance_identifiers
}

output "redis_replication_group_ids" {
  description = "ElastiCache Redis replication group ID (Monitoring: Redis CPU·메모리·eviction 알람)"
  value       = module.platform.redis_replication_group_ids
}

output "sqs_queue_names" {
  description = "SQS 큐 이름 (Monitoring: 메시지 적체·DLQ 알람)"
  value       = module.platform.sqs_queue_names
}

output "db_writer_endpoint" {
  value = module.platform.db_writer_endpoint
}

output "db_reader_endpoint" {
  value = module.platform.db_reader_endpoint
}

output "redis_endpoint" {
  value = module.platform.redis_endpoint
}

output "alb_hostname" {
  description = "서비스 진입 ALB 주소"
  value       = module.platform.alb_hostname
}

output "update_kubeconfig" {
  description = "kubeconfig 등록 명령"
  value       = "aws eks update-kubeconfig --name ${module.platform.cluster_name} --region ${var.region} --alias ${module.platform.cluster_name}"
}
