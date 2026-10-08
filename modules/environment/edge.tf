# ==========================================================================
# 트래픽 진입 구조 (charts/nebula-edge)
#   dev            : ALB ─────────────────────────────────────▶ core-gateway (backend)
#   staging / prod : ALB ─▶ istio-ingressgateway ─▶ VirtualService ─▶ core-gateway ─▶ service-*
#                    (재시도·타임아웃·서킷브레이커·mTLS 를 DestinationRule / PeerAuthentication 으로 중앙 관리)
# ==========================================================================

resource "helm_release" "edge" {
  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.istio_ingressgateway,
    kubernetes_namespace_v1.backend,
  ]

  name      = "nebula-edge"
  chart     = "${path.module}/../../charts/nebula-edge"
  namespace = kubernetes_namespace_v1.backend.metadata[0].name

  values = [yamlencode({
    environment = var.environment
    ingress = {
      enabled        = true
      scheme         = var.ingress.scheme
      certificateArn = var.ingress.certificate_arn
      allowedCidrs   = var.ingress.allowed_cidrs
    }
    istio = {
      enabled  = var.istio.enabled
      mtlsMode = var.istio.mtls_mode
    }
  })]
}

# ALB 주소는 컨트롤러가 비동기로 채운다 (apply 직후에는 비어 있을 수 있음)
data "kubernetes_ingress_v1" "edge" {
  depends_on = [helm_release.edge]

  metadata {
    name      = "nebula-edge"
    namespace = var.istio.enabled ? "istio-ingress" : "backend"
  }
}
