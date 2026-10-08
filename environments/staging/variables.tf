# 환경 구성(크기, HA, 메시 등)은 main.tf 에 코드로 고정한다. 여기에는 계정·비밀 값만 둔다.

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "EKS API 엔드포인트 접근 허용 CIDR (운영자 IP 로 좁히는 것을 권장)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "gitops_token" {
  description = "nebula-gitops 읽기 토큰 (public 레포면 빈 값)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_aws_platform_apps" {
  description = "모니터링 스택(OTel Collector, kube-state-metrics)과 AMP 카나리 분석을 ArgoCD 로 동기화. Nebula-Monitoring apply 후 true"
  type        = bool
  default     = false
}

variable "ingress_certificate_arn" {
  description = "ALB HTTPS 리스너용 ACM 인증서 ARN (비우면 HTTP 만)"
  type        = string
  default     = ""
}

variable "auth0" {
  description = "core-gateway OIDC 로그인 (Auth0)"
  type = object({
    domain        = optional(string, "")
    client_id     = optional(string, "")
    client_secret = optional(string, "")
  })
  default   = {}
  sensitive = true
}
