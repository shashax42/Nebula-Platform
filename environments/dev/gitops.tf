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
    applications = {
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
    }
  })]
}
