output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_apiserver" {
  description = "APIServer for EKS control plane"
  value       = module.eks.cluster_endpoint
}

# Nebula-Monitoring 이 remote state 로 읽어 데이터 스토어 알람 대상을 자동으로 정한다
output "aurora_cluster_identifiers" {
  description = "Aurora cluster identifiers (main, analytics, reporting)"
  value       = [module.aurora_main.cluster_id, module.aurora_analytics.cluster_id, module.aurora_reporting.cluster_id]
}

output "redis_replication_group_ids" {
  description = "ElastiCache Redis replication group IDs"
  value       = [module.redis_cache.replication_group_id]
}
