# ========================================
# EKS Cluster Module - 재사용 가능한 EKS 모듈
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

locals {
  cluster_name = "${var.name_prefix}-eks-${var.environment}"
  
  common_tags = merge(
    var.tags,
    {
      Module      = "compute/eks-cluster"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# ========================================
# EKS Cluster
# ========================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # 클러스터 엔드포인트 설정
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # 로깅 설정
  cluster_enabled_log_types = var.cluster_enabled_log_types

  # 애드온 설정
  cluster_addons = var.cluster_addons

  # 네트워크 설정
  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # 노드 그룹 기본 설정
  eks_managed_node_group_defaults = var.eks_managed_node_group_defaults

  # 노드 그룹 설정
  eks_managed_node_groups = var.eks_managed_node_groups

  # IRSA 설정
  enable_irsa = var.enable_irsa

  # 클러스터 보안 그룹 설정
  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules
  node_security_group_additional_rules    = var.node_security_group_additional_rules

  # 태그
  tags = local.common_tags
}

# ========================================
# EBS CSI Driver IRSA (선택적)
# ========================================
module "ebs_csi_irsa" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}

# ========================================
# EBS CSI Driver 애드온
# ========================================
resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_version
  service_account_role_arn = module.ebs_csi_irsa[0].iam_role_arn
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    module.eks.eks_managed_node_groups
  ]

  tags = local.common_tags
}
