# ==========================================================================
# Nebula 환경 하나 = 네트워크 + EKS + 데이터 계층 + 트래픽 계층 + GitOps + 서비스 연결
#
#   network.tf    VPC (public / private / database 서브넷, NAT, S3 Gateway Endpoint)
#   eks.tf        EKS + 관리형 노드 그룹
#   data.tf       서비스 DB (RDS | Aurora), Redis Cluster, SQS
#   addons.tf     AWS Load Balancer Controller, metrics-server, Cluster Autoscaler, Istio
#   gitops.tf     ArgoCD, Argo Rollouts(+AMP 조회 IRSA), Kyverno, Strimzi, App of Apps
#   services.tf   nebula-services 가 읽는 ConfigMap / Secret, DB 스키마 초기화
#   edge.tf       ALB Ingress (+ Istio Gateway / VirtualService / DestinationRule)
# ==========================================================================

locals {
  name         = "nebula-${var.environment}"
  cluster_name = "nebula-eks-${var.environment}"

  tags = merge(var.tags, {
    Project     = "Nebula-Platform"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

data "aws_caller_identity" "current" {}
