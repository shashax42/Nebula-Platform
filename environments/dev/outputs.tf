output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_apiserver" {
  description = "APIServer for EKS control plane"
  value       = module.eks.cluster_endpoint
}
