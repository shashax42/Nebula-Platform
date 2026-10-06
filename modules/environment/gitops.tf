# ==========================================================================
# GitOps / Progressive Delivery / Policy — 모든 환경 공통
#   ArgoCD 가 nebula-gitops 의 platform/apps 를 App of Apps 로 동기화한다.
#   서비스 배포, Kyverno 정책, 롤백 분석 템플릿은 모두 nebula-gitops 에서 관리된다.
#   서비스 이미지는 nebula-ci-templates 파이프라인이 빌드·서명하고 nebula-gitops 의 태그를 올린다.
# ==========================================================================

resource "helm_release" "argocd" {
  depends_on = [module.eks]

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.9.6"
  namespace        = "argocd"
  create_namespace = true
}

resource "helm_release" "argo_rollouts" {
  depends_on = [module.eks]

  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = "2.43.5"
  namespace        = "argo-rollouts"
  create_namespace = true

  # 메트릭 기반 카나리 분석: 컨트롤러가 IRSA 로 AMP 에 SigV4 질의한다 (nebula-gitops platform/aws/base/analysis-slo-canary.yaml)
  values = [yamlencode({
    serviceAccount = {
      annotations = { "eks.amazonaws.com/role-arn" = module.argo_rollouts_irsa.iam_role_arn }
    }
  })]
}

# Argo Rollouts → AMP 조회 권한 (읽기 전용, 이 계정·리전의 워크스페이스로 한정)
resource "aws_iam_policy" "argo_rollouts_amp_query" {
  name        = "${local.cluster_name}-argo-rollouts-amp-query"
  description = "Argo Rollouts canary analysis: query Amazon Managed Prometheus"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aps:QueryMetrics", "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"]
      Resource = "arn:aws:aps:${var.region}:${data.aws_caller_identity.current.account_id}:workspace/*"
    }]
  })

  tags = local.tags
}

module "argo_rollouts_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-argo-rollouts"
  role_policy_arns = {
    amp_query = aws_iam_policy.argo_rollouts_amp_query.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["argo-rollouts:argo-rollouts"]
    }
  }

  tags = local.tags
}

resource "helm_release" "kyverno" {
  depends_on = [module.eks]

  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = "3.9.1"
  namespace        = "kyverno"
  create_namespace = true
}

# Strimzi 오퍼레이터 (nebula-gitops data-kafka 의 Kafka CR 을 실제 브로커로 만든다)
resource "helm_release" "strimzi" {
  depends_on = [module.eks, kubernetes_namespace_v1.backend]

  name       = "kafka"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = "1.2.0"
  namespace  = kubernetes_namespace_v1.backend.metadata[0].name
}

# nebula-gitops 가 private 일 때 ArgoCD 가 읽을 수 있도록 레포 자격 증명 등록
resource "kubernetes_secret_v1" "gitops_repo" {
  count      = var.gitops_token == "" ? 0 : 1
  depends_on = [helm_release.argocd]

  metadata {
    name      = "nebula-gitops-repo"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.gitops_repo_url
    username = "x-access-token"
    password = var.gitops_token
  }
}

# App of Apps 진입점 (nebula-gitops/platform/root.yaml 과 동일).
# 서비스가 뜨기 전에 서비스 설정(services.tf)과 정책 엔진·오퍼레이터가 먼저 준비되도록 의존성을 건다
resource "helm_release" "argocd_root" {
  depends_on = [
    helm_release.argocd,
    helm_release.argo_rollouts,
    helm_release.kyverno,
    helm_release.strimzi,
    helm_release.istio_ingressgateway,
    kubernetes_secret_v1.gitops_repo,
    kubernetes_config_map_v1.service,
    kubernetes_secret_v1.service,
    kubernetes_job_v1.db_bootstrap,
  ]

  name       = "argocd-root"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.6"
  namespace  = "argocd"

  values = [yamlencode({
    applications = merge({
      nebula-root = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_revision
          path           = "platform/apps"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
      },
      # AWS 계정에 묶인 플랫폼 앱 (모니터링 스택, AMP 기반 카나리 분석). 환경마다 값이 달라 envs/<env> 오버레이를 쓴다.
      # Nebula-Monitoring 을 apply 하고 render-gitops-values.sh <env> 로 값을 채운 뒤 켠다.
      var.enable_aws_platform_apps ? {
        nebula-aws = {
          namespace = "argocd"
          project   = "default"
          source = {
            repoURL        = var.gitops_repo_url
            targetRevision = var.gitops_revision
            path           = "platform/aws/envs/${var.environment}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
          }
          syncPolicy = {
            automated = { prune = true, selfHeal = true }
          }
        }
      } : {}
    )
  })]
}
