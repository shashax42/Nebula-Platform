# ==========================================================================
# 클러스터 애드온
#   AWS Load Balancer Controller : Ingress → ALB (트래픽 진입 구조를 코드로 설계)
#   metrics-server               : HPA 가 읽는 CPU/메모리
#   Cluster Autoscaler           : 파드가 Pending 이면 노드 추가, 놀면 반납 (FinOps)
#   Istio (staging / prod)       : 서비스 간 트래픽 정책(재시도·타임아웃·서킷브레이커·mTLS)을 앱 밖에서 제어
# ==========================================================================

# --------------------------------------------------------------------------
# AWS Load Balancer Controller
# --------------------------------------------------------------------------
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0" # v6 에서 이 하위 모듈 이름이 바뀌어 고정

  role_name                              = "${local.cluster_name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

resource "helm_release" "aws_load_balancer_controller" {
  depends_on = [module.eks]

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.17.1" # 컨트롤러 v2.17.1. 3.x 차트는 메이저 변경이라 별도 검토 후 올린다
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = module.eks.cluster_name
    region      = var.region
    vpcId       = module.vpc.vpc_id
    serviceAccount = {
      name        = "aws-load-balancer-controller"
      annotations = { "eks.amazonaws.com/role-arn" = module.lb_controller_irsa.iam_role_arn }
    }
  })]
}

# --------------------------------------------------------------------------
# metrics-server (HPA)
# --------------------------------------------------------------------------
resource "helm_release" "metrics_server" {
  depends_on = [module.eks]

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"
  namespace  = "kube-system"
}

# --------------------------------------------------------------------------
# Cluster Autoscaler: EKS 관리형 노드 그룹 ASG 의 자동 태그(k8s.io/cluster-autoscaler/<cluster>)로 대상을 찾는다
# --------------------------------------------------------------------------
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                        = "${local.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = local.tags
}

resource "helm_release" "cluster_autoscaler" {
  depends_on = [module.eks]

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.59.0" # appVersion 1.35.0
  namespace  = "kube-system"

  values = [yamlencode({
    autoDiscovery = { clusterName = module.eks.cluster_name }
    awsRegion     = var.region
    # 오토스케일러 마이너 버전은 쿠버네티스 마이너 버전과 맞춘다
    image = { tag = "v${var.cluster_version}.0" }
    rbac = {
      serviceAccount = {
        name        = "cluster-autoscaler"
        annotations = { "eks.amazonaws.com/role-arn" = module.cluster_autoscaler_irsa.iam_role_arn }
      }
    }
    extraArgs = {
      expander                           = "least-waste" # 남는 자원이 가장 적은 노드 그룹부터
      "balance-similar-node-groups"      = true
      "skip-nodes-with-system-pods"      = false
      "scale-down-utilization-threshold" = var.autoscaling.scale_down_utilization_threshold
      "scale-down-unneeded-time"         = var.autoscaling.scale_down_unneeded_time
      "scale-down-delay-after-add"       = var.autoscaling.scale_down_delay_after_add
    }
  })]
}

# --------------------------------------------------------------------------
# Istio (staging / prod)
#   서비스 파드는 nebula-gitops 매니페스트의 라벨 sidecar.istio.io/inject: "true" 로 메시에 들어온다.
#   Istio 가 없는 dev / kind 에서는 같은 라벨이 아무 일도 하지 않는다 (매니페스트를 환경별로 나누지 않기 위해)
# --------------------------------------------------------------------------
locals {
  istio_repository = "https://istio-release.storage.googleapis.com/charts"
}

resource "helm_release" "istio_base" {
  count      = var.istio.enabled ? 1 : 0
  depends_on = [module.eks]

  name             = "istio-base"
  repository       = local.istio_repository
  chart            = "base"
  version          = var.istio.version
  namespace        = "istio-system"
  create_namespace = true
}

resource "helm_release" "istiod" {
  count      = var.istio.enabled ? 1 : 0
  depends_on = [helm_release.istio_base]

  name       = "istiod"
  repository = local.istio_repository
  chart      = "istiod"
  version    = var.istio.version
  namespace  = "istio-system"

  values = [yamlencode({
    pilot = {
      env = {
        # 사이드카를 네이티브 사이드카(initContainer, restartPolicy: Always)로 → CronJob/Job 이 사이드카 때문에 끝나지 않는 문제 방지
        ENABLE_NATIVE_SIDECARS = "true"
      }
    }
    meshConfig = {
      # 액세스 로그를 stdout(JSON) 으로 → OTel agent 가 컨테이너 로그로 수집해 CloudWatch Logs 로 보낸다
      accessLogFile     = "/dev/stdout"
      accessLogEncoding = "JSON"
      # 사이드카가 파드에 prometheus.io/scrape 어노테이션을 붙이지 않게 한다.
      # 켜 두면 Nebula-Monitoring agent 의 어노테이션 스크레이프가 Envoy 메트릭 전체를 AMP 로 보낸다 (서비스 메트릭은 이미 OTLP 로 온다)
      enablePrometheusMerge = false
    }
  })]
}

resource "helm_release" "istio_ingressgateway" {
  count      = var.istio.enabled ? 1 : 0
  depends_on = [helm_release.istiod]

  name             = "istio-ingressgateway"
  repository       = local.istio_repository
  chart            = "gateway"
  version          = var.istio.version
  namespace        = "istio-ingress"
  create_namespace = true

  values = [yamlencode({
    # ALB 가 앞단 → 게이트웨이 서비스는 클러스터 내부용(ClusterIP), ALB 는 파드 IP 로 직접 보낸다
    service = { type = "ClusterIP" }
    autoscaling = {
      enabled     = true
      minReplicas = var.istio.gateway_replicas.min
      maxReplicas = var.istio.gateway_replicas.max
    }
  })]
}
