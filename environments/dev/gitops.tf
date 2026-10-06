# GitOps / Progressive Delivery / Policy
# ArgoCD를 설치하고 nebula-gitops의 platform/apps를 App of Apps로 연결한다.
# 서비스 배포, Kyverno 정책, 롤백 분석 템플릿은 모두 nebula-gitops에서 관리된다.

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

  # 메트릭 기반 카나리 분석: 컨트롤러가 IRSA 로 AMP 에 SigV4 질의한다 (nebula-gitops platform/aws/analysis-slo-canary.yaml)
  values = [yamlencode({
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = module.argo_rollouts_irsa.iam_role_arn
      }
    }
  })]
}

# Argo Rollouts → AMP 조회 권한 (읽기 전용, 이 계정·리전의 워크스페이스로 한정)
data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "argo_rollouts_amp_query" {
  name        = "${var.cluster_name}-argo-rollouts-amp-query"
  description = "Argo Rollouts canary analysis: query Amazon Managed Prometheus"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aps:QueryMetrics", "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"]
      Resource = "arn:aws:aps:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workspace/*"
    }]
  })
}

module "argo_rollouts_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0" # v6 에서 이 하위 모듈이 iam-role-for-service-accounts 로 바뀌어 고정 필요

  role_name = "${var.cluster_name}-argo-rollouts"
  role_policy_arns = {
    amp_query = aws_iam_policy.argo_rollouts_amp_query.arn
  }

  depends_on = [data.aws_eks_cluster.cluster, time_sleep.wait_for_eks]

  oidc_providers = {
    one = {
      provider_arn               = length(data.aws_iam_openid_connect_provider.existing_oidc.arn) > 0 ? data.aws_iam_openid_connect_provider.existing_oidc.arn : aws_iam_openid_connect_provider.oidc_provider[0].arn
      namespace_service_accounts = ["argo-rollouts:argo-rollouts"]
    }
  }
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

# 기존 scripts/helm-install-kafka.sh 대체 (data-kafka 매니페스트가 사용하는 Strimzi CRD)
resource "helm_release" "strimzi" {
  depends_on = [module.eks]

  name             = "kafka"
  repository       = "https://strimzi.io/charts/"
  chart            = "strimzi-kafka-operator"
  version          = "1.2.0"
  namespace        = "backend"
  create_namespace = true
}

# nebula-gitops가 private일 때 ArgoCD가 읽을 수 있도록 레포 자격 증명 등록
resource "kubernetes_secret" "gitops_repo" {
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

# App of Apps 진입점 (nebula-gitops/platform/root.yaml과 동일)
resource "helm_release" "argocd_root" {
  depends_on = [
    helm_release.argocd,
    helm_release.argo_rollouts,
    helm_release.kyverno,
    helm_release.strimzi,
    kubernetes_secret.gitops_repo,
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
          targetRevision = "main"
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
      # AWS 계정에 묶인 플랫폼 앱 (모니터링 스택, AMP 기반 카나리 분석). kind 로컬 E2E 에는 없다.
      # Nebula-Monitoring 을 apply 하고 nebula-gitops/platform/aws 의 값을 채운 뒤 켠다.
      var.enable_aws_platform_apps ? {
        nebula-aws = {
          namespace = "argocd"
          project   = "default"
          source = {
            repoURL        = var.gitops_repo_url
            targetRevision = "main"
            path           = "platform/aws"
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
