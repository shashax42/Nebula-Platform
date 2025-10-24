terraform {
  # Backend 설정 추가 (S3 + DynamoDB)
  backend "s3" {
    # backend-config/dev.hcl 파일 사용하거나 직접 설정
    # terraform init -backend-config="../../shared/backend-config/dev.hcl"
    
    bucket         = "mycompany-terraform-state-bucket"  # 실제 버킷명으로 변경
    key            = "env/dev/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
  
  required_providers {
    time = {
      source = "hashicorp/time"
      version = "~> 0.9"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.74.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15.0"
    }
  }

  required_version = "~> 1.8"
}

provider "aws" {
  region = var.region
}

locals {
  api_version = "client.authentication.k8s.io/v1beta1"
  args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  command     = "aws"
}


provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = local.api_version
    args        = local.args
    command     = local.command
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = local.api_version
      args        = local.args
      command     = local.command
    }
  }
}
