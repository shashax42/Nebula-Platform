#!/usr/bin/env bash
# Vagrant 클러스터에 EKS 와 같은 플랫폼 구성(ArgoCD, Argo Rollouts, Kyverno, Strimzi)을 올리고 nebula-root 를 적용한다.
#   서비스 매니페스트는 nebula-gitops 그대로 → EKS 와 같은 배포물이 실패 주입 환경에서 어떻게 동작하는지 본다.
# 사용: GITOPS_TOKEN=<nebula-gitops 읽기 토큰> ./bootstrap.sh
set -euo pipefail
cd "$(dirname "$0")"

export KUBECONFIG="$PWD/.kubeconfig"
[ -f "$KUBECONFIG" ] || { echo "먼저 vagrant up 을 실행하세요 (.kubeconfig 없음)" >&2; exit 1; }

# 버전은 Nebula-Platform modules/environment/gitops.tf 와 같게 유지한다
ARGOCD_VERSION=10.9.6
ROLLOUTS_VERSION=2.43.5
KYVERNO_VERSION=3.9.1
STRIMZI_VERSION=1.2.0

kubectl wait --for=condition=Ready nodes --all --timeout=300s

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null
helm repo add strimzi https://strimzi.io/charts/ >/dev/null
helm repo update >/dev/null

helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --version "$ARGOCD_VERSION" --wait
helm upgrade --install argo-rollouts argo/argo-rollouts -n argo-rollouts --create-namespace --version "$ROLLOUTS_VERSION" --wait
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --version "$KYVERNO_VERSION" --wait
kubectl create namespace backend --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install kafka strimzi/strimzi-kafka-operator -n backend --version "$STRIMZI_VERSION" --wait

if [ -n "${GITOPS_TOKEN:-}" ]; then
  kubectl -n argocd create secret generic nebula-gitops-repo \
    --from-literal=type=git \
    --from-literal=url=https://github.com/shashax42/nebula-gitops.git \
    --from-literal=username=x-access-token \
    --from-literal=password="$GITOPS_TOKEN" \
    --dry-run=client -o yaml \
    | kubectl label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
    | kubectl apply -f -
fi

kubectl apply -f https://raw.githubusercontent.com/shashax42/nebula-gitops/main/platform/root.yaml

echo
echo "KUBECONFIG=$KUBECONFIG"
echo "서비스용 DB/Redis 설정(config-*, secret-*)은 이 클러스터에 없으므로 서비스 파드는 기동하지 않는다."
echo "→ 플랫폼 계층(ArgoCD 동기화, Kafka, 롤백, 정책)의 실패 양상을 보는 용도. 서비스 단위 실험은 dev/compose 를 함께 쓴다."
