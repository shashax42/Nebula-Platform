data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_iam_policy" "ebs_csi" {
  name = "AmazonEBSCSIDriverPolicy"
}

locals {
  cluster_name     = "eks-cluster-${random_string.suffix.result}"
  cluster_vpc_name = "eks-vpc-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length = 8

  lower   = true
  upper   = false
  numeric = true
  special = false
}

# VPC 모듈 설정
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.cluster_vpc_name

  cidr = var.network_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  # Private과 Public 서브넷을 설정합니다.
  private_subnets = [cidrsubnet(var.network_cidr, 8, 1), cidrsubnet(var.network_cidr, 8, 2)]
  public_subnets  = [cidrsubnet(var.network_cidr, 8, 101), cidrsubnet(var.network_cidr, 8, 102)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

# 별도의 internal_subnets을 정의하여 VPC에 연결
resource "aws_subnet" "internal_subnet" {
  count = length(slice(data.aws_availability_zones.available.names, 0, 3))

  vpc_id                  = module.vpc.vpc_id
  cidr_block              = cidrsubnet(var.network_cidr, 8, 3 + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.cluster_vpc_name}-internal-${count.index + 1}"
  }
}

# 내부 서브넷들을 리스트로 참조
locals {
  internal_subnets = aws_subnet.internal_subnet[*].id
}

# RDS Subnet Group에 internal_subnets 사용
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${local.cluster_name}-rds-subnet-group"
  subnet_ids = local.internal_subnets # 내부 서브넷 ID 리스트 참조

  tags = {
    Name = "${local.cluster_name}-rds-subnet-group"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  cluster_endpoint_public_access = true

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets # eks 클러스터에 private 서브넷 사용
  control_plane_subnet_ids = module.vpc.private_subnets # 컨트롤 플레인도 private 서브넷 사용

  eks_managed_node_group_defaults = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = ["t3.xlarge"]
  }

  eks_managed_node_groups = {
    main_group = {
      name           = "node-group-1"
      instance_types = ["t3.xlarge"]
      min_size       = 3
      max_size       = 5
      desired_size   = 3
    }
  }

  enable_cluster_creator_admin_permissions = true
}


# S3 버킷 생성 (프라이빗 서브넷에 연결)
resource "aws_s3_bucket" "private_s3" {
  bucket = "private-s3-${random_string.suffix.result}"

  tags = {
    Name        = "Private S3 Bucket"
    Environment = "development"
  }
}

# 버킷 소유권 제어 (ACL 설정을 위해 필요)
resource "aws_s3_bucket_ownership_controls" "private_s3" {
  bucket = aws_s3_bucket.private_s3.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# ACL 설정 (deprecated 인라인 acl 대체)
resource "aws_s3_bucket_acl" "private_s3" {
  depends_on = [aws_s3_bucket_ownership_controls.private_s3]

  bucket = aws_s3_bucket.private_s3.id
  acl    = "private"
}

# 버전 관리 설정 (deprecated 인라인 versioning 대체)
resource "aws_s3_bucket_versioning" "private_s3" {
  bucket = aws_s3_bucket.private_s3.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 수명 주기 설정 (deprecated 인라인 lifecycle_rule 대체)
resource "aws_s3_bucket_lifecycle_configuration" "private_s3" {
  bucket = aws_s3_bucket.private_s3.id

  rule {
    id     = "auto-transition"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}
