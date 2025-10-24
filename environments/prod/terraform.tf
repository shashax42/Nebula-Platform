terraform {
  # Backend 설정 (S3 + DynamoDB)
  backend "s3" {
    # backend-config/prod.hcl 파일 사용하거나 직접 설정
    # terraform init -backend-config="../../shared/backend-config/prod.hcl"
    
    bucket         = "mycompany-terraform-state-bucket"  # 실제 버킷명으로 변경 필요
    key            = "env/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
    
    # Production 추가 보안 설정 (선택)
    # kms_key_id = "arn:aws:kms:ap-northeast-2:ACCOUNT_ID:key/KEY_ID"  # KMS 암호화
    # role_arn   = "arn:aws:iam::PROD_ACCOUNT_ID:role/TerraformRole"   # Cross-account
  }
  
  required_providers {
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
