# ==========================================================================
# Network: 3 AZ × (public / private / database) 서브넷
#   public   : ALB, NAT Gateway           (kubernetes.io/role/elb → ALB 컨트롤러가 찾는 태그)
#   private  : EKS 노드·파드              (kubernetes.io/role/internal-elb)
#   database : RDS / Aurora / ElastiCache  (인터넷 경로 없음)
# ==========================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = var.network_cidr
  azs  = local.azs

  private_subnets  = [for i in range(3) : cidrsubnet(var.network_cidr, 8, i + 1)]
  database_subnets = [for i in range(3) : cidrsubnet(var.network_cidr, 8, i + 21)]
  public_subnets   = [for i in range(3) : cidrsubnet(var.network_cidr, 8, i + 101)]

  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  enable_nat_gateway     = true
  single_nat_gateway     = !var.nat_gateway_per_az
  one_nat_gateway_per_az = var.nat_gateway_per_az

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

  tags = local.tags
}

# S3 트래픽(ECR 이미지 레이어, 로그 아카이브 등)을 NAT 대신 Gateway Endpoint 로 보낸다 (NAT 데이터 처리 비용 절감, 무료)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = distinct(concat(module.vpc.private_route_table_ids, module.vpc.database_route_table_ids))

  tags = merge(local.tags, { Name = "${local.name}-s3" })
}
