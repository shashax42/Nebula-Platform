# AWS Region 및 EKS 클러스터 정보 가져오기
resource "time_sleep" "wait_for_eks" {
  depends_on = [ module.eks ]
  create_duration = "1m"
  
}
data "aws_region" "current" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [ time_sleep.wait_for_eks ]
}

locals {
  # OIDC Provider의 ARN과 CA Thumbprint를 동적으로 생성
  oidc_provider_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  eks_ca_thumbprint = substr(trimspace(data.aws_eks_cluster.cluster.certificate_authority[0].data), 0, 40)
}

# 기존 OIDC Provider가 있는지 확인
data "aws_iam_openid_connect_provider" "existing_oidc" {
  url = local.oidc_provider_url
  depends_on = [ time_sleep.wait_for_eks ]
}

# 존재하지 않을 경우 OIDC Provider 생성
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  count           = length(data.aws_iam_openid_connect_provider.existing_oidc.arn) == 0 ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.eks_ca_thumbprint]
  url             = local.oidc_provider_url
  depends_on = [ time_sleep.wait_for_eks ]

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [url, thumbprint_list]
  }
}

# AWS Load Balancer Controller용 IAM Role 생성
module "nlb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0" # v6 에서 이 하위 모듈이 iam-role-for-service-accounts 로 바뀌어 고정 필요

  role_name = "${var.cluster_name}-${var.nlb_chart.name}"

  attach_load_balancer_controller_policy = true

  depends_on = [ data.aws_eks_cluster.cluster, time_sleep.wait_for_eks ]

  oidc_providers = {
    one = {
      # OIDC Provider ARN을 조건부로 안전하게 참조
      provider_arn               = length(data.aws_iam_openid_connect_provider.existing_oidc.arn) > 0 ? data.aws_iam_openid_connect_provider.existing_oidc.arn : aws_iam_openid_connect_provider.oidc_provider[0].arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
# 사실 dev 환경에선 depends_on = [time_sleep.wait_for_eks]만 해도 될듯 
# prod, staging 환경에선 depends_on = 둘 다 필요할듯 

# Kubernetes Service Account 생성
resource "kubernetes_service_account" "nlb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.nlb_controller_irsa.iam_role_arn
    }
  }
}

# Helm을 사용하여 aws-load-balancer-controller 설치
resource "helm_release" "nlb_controller" {
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  version    = "1.10.0"

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.cluster.name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.nlb_controller.metadata[0].name
  }
  set {
    name  = "region"
    value = data.aws_region.current.name
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [kubernetes_service_account.nlb_controller]
}
