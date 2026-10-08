# ==========================================================================
# EKS: 노드 그룹 하나, 크기는 Cluster Autoscaler 가 [min_size, max_size] 안에서 조절한다
# (desired_size 는 최초 생성값. 이후 변경은 모듈이 무시하고 오토스케일러에 맡긴다)
# ==========================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = { before_compute = true }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    main = {
      name           = "${local.name}-main"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_group.instance_types
      capacity_type  = var.node_group.capacity_type

      min_size     = var.node_group.min_size
      max_size     = var.node_group.max_size
      desired_size = var.node_group.desired_size

      labels = { "nebula.io/pool" = "main" }
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = local.tags
}

locals {
  oidc_provider_arn = module.eks.oidc_provider_arn
}
