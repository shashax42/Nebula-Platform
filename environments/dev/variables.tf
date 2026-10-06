# AWS 공통 설정
variable "region" {
  description = "AWS region"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

# VPC CIDR 설정
variable "network_cidr" {
  description = "Network CIDR"
  type        = string
}

# RDS 설정
variable "rds_instance_class" {
  description = "The instance class for the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "rds_storage_type" {
  description = "Storage type for RDS"
  type        = string
  default     = "gp3"
}

variable "rds_engine" {
  description = "Database engine for RDS"
  type        = string
  default     = "mysql"
}

variable "rds_engine_version" {
  description = "Database engine version for RDS"
  type        = string
  default     = "8.0.mysql_aurora.3.04.1"
}

variable "rds_db_name1" {
  description = "Name of the RDS database"
  type        = string
}

variable "rds_db_name2" {
  description = "Name of the RDS database"
  type        = string
}

variable "rds_db_name3" {
  description = "Name of the RDS database"
  type        = string
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
}

variable "rds_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "rds_port" {
  description = "Port for RDS mysql"
  type        = number
  
}

# NLB 설정
variable "nlb_chart" {
  description = "NLB Controller Helm chart settings"
  type = object({
    name       = string
    namespace  = string
    repository = string
    chart      = string
    version    = string
  })
  default = {
    name       = "aws-load-balancer-controller"
    namespace  = "kube-system"
    repository = "https://aws.github.io/eks-charts"
    chart      = "aws-load-balancer-controller"
    version    = "1.10.0"
  }
}

# S3, EKS 및 환경 설정
variable "eks_role_name" {
  description = "IAM Role name for EKS integration"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}


# IAM 그룹 설정
variable "iam_groups" {
  description = "Map of IAM groups with their respective users and policies"
  type = map(object({
    users    = list(string)   # 그룹에 속한 사용자 목록
    policies = list(string)   # 그룹에 연결된 정책 ARN 목록
  }))
}

# 프로젝트 이름
variable "project_name" {
  description = "Project name to prefix all resources"
  type        = string
  default     = "nebula-platform"
}

# SSH 설정
# variable "allowed_ssh_cidr_blocks" {
#   description = "List of CIDR blocks allowed to access the bastion via SSH"
#   type        = list(string)
#   sensitive   = true
# }

# Bastion 설정
variable "ami_id" {
  description = "AMI ID for the bastion instance"
  type        = string
  sensitive   = true
}

variable "public_subnet_id" {
  description = "Public subnet ID where the bastion instance will be deployed"
  type        = string
  sensitive   = true
}

variable "key_pair_name" {
  description = "SSH key pair name for accessing the bastion instance"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "Instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

# redis 설정 

variable "redis_port1" {
  description = "Port for Redis"
  type        = number
  
}

variable "redis_port2" {
  description = "Port for Redis"
  type        = number
  
}

variable "redis_port3" {
  description = "Port for Redis"
  type        = number
  
}

# GitOps 설정
variable "gitops_repo_url" {
  description = "ArgoCD가 동기화할 GitOps 레포"
  type        = string
  default     = "https://github.com/shashax42/nebula-gitops.git"
}

variable "gitops_token" {
  description = "GitOps 레포 읽기 토큰 (public 레포면 빈 값)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_aws_platform_apps" {
  description = "nebula-gitops platform/aws (모니터링 스택, AMP 카나리 분석)를 ArgoCD 로 동기화. Nebula-Monitoring apply 및 값 기록 후 true"
  type        = bool
  default     = false
}
