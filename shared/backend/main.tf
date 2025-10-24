provider "aws" {
    region = "${var.region}"
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
  
}

# VPC 생성
resource "aws_vpc" "rds" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "rds-vpc"
  }
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "rds-public" {
  vpc_id     = aws_vpc.rds.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "rds-public-subnet"
  }
}

# 프라이빗 서브넷 생성
resource "aws_subnet" "rds-private" {
  vpc_id     = aws_vpc.rds.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "rds-private-subnet"
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "rds-igw" {
  vpc_id = aws_vpc.rds.id

  tags = {
    Name = "rds-igw"
  }
}

# 라우팅 테이블 생성
resource "aws_route_table" "rds-public" {
  vpc_id = aws_vpc.rds.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rds-igw.id
  }

  tags = {
    Name = "rds-public-rt"
  }
}

# 퍼블릭 서브넷에 라우팅 테이블 연결
resource "aws_route_table_association" "rds-asso" {
  subnet_id      = aws_subnet.rds-public.id
  route_table_id = aws_route_table.rds-public.id
}

# EC2 보안 그룹 생성
# resource "aws_security_group" "rds-ec2_sg" {
#   name        = "rds-ec2-sg"
#   description = "Security group for EC2 instance"
#   vpc_id      = aws_vpc.rds.id

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# RDS 보안 그룹 생성
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.rds.id
  

  # ingress {
  #   from_port       = 3316
  #   to_port         = 3316
  #   protocol        = "tcp"
  #   # security_groups = ["0.0.0.0/0"]
  #   security_groups = [aws_security_group.rds-ec2_sg.id]
  # }
  ingress {
    from_port       = 3316
    to_port         = 3316
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # security_groups = [aws_security_group.rds-ec2_sg.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


}

# EC2 인스턴스 생성
# resource "aws_instance" "rds-ec2" {
#   ami           = "ami-0de20b1c8590e09c5"  # Amazon Linux 2 AMI
#   instance_type = "t2.micro"
#   key_name      = "${var.my_key}"  # 여기에 실제 키 페어 이름을 입력하세요

#   vpc_security_group_ids = [aws_security_group.rds-ec2_sg.id]
#   subnet_id              = aws_subnet.rds-public.id

#   tags = {
#     Name = "rds-ec2"
#   }

#   user_data = <<-EOF
#               #!/bin/bash
#               sudo yum update -y
#               sudo dnf install -y mariadb105
#               # mysql -h ${local.rds_master_endpoint_without_port} -u ${var.mysql_user} -p -e 'create database product;'
#               "${var.mysql_password}"
#               EOF

# }

# RDS 서브넷 그룹 생성
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.rds-private.id, aws_subnet.rds-public.id]

  tags = {
    Name = "My DB subnet group"
  }
  
}

# ... (이전 코드는 그대로 유지) ...

# RDS 인스턴스 생성 (마스터)
resource "aws_db_instance" "master1" {
  allocated_storage    = 6
  port = 3316
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  db_name              = var.mysql_db1
  username             = var.mysql_user
  password             = var.mysql_password  # 여기에 실제 비밀번호를 입력하세요
  # parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  multi_az             = false
  publicly_accessible = true
  backup_retention_period = 7  # Read Replica 생성을 위해 백업 보존 기간 설정
  availability_zone = "${var.region}a"

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
}

# RDS Read Replica 생성
resource "aws_db_instance" "replica1" {
  instance_class       = "db.t3.micro"
  replicate_source_db  = aws_db_instance.master1.identifier
  multi_az = false
  publicly_accessible  = true
  skip_final_snapshot  = true
  port = 3316
  availability_zone = "${var.region}a"

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  # Read Replica는 마스터와 같은 서브넷 그룹을 사용합니다
  #db_subnet_group_name /  = aws_db_subnet_group.default.name

  tags = {
    Name = "mysql-read-replica1"
  }
}

# RDS 인스턴스 생성 (마스터)
resource "aws_db_instance" "master2" {
  allocated_storage    = 6
  port = 3316
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  db_name              = var.mysql_db2
  username             = var.mysql_user
  password             = var.mysql_password  # 여기에 실제 비밀번호를 입력하세요
  # parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  multi_az             = false
  publicly_accessible = true
  backup_retention_period = 7  # Read Replica 생성을 위해 백업 보존 기간 설정
  availability_zone = "${var.region}a"

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
}

# RDS Read Replica 생성
resource "aws_db_instance" "replica2" {
  instance_class       = "db.t3.micro"
  replicate_source_db  = aws_db_instance.master2.identifier
  multi_az = false
  publicly_accessible  = true
  skip_final_snapshot  = true
  port = 3316
  availability_zone = "${var.region}a"

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  # Read Replica는 마스터와 같은 서브넷 그룹을 사용합니다
  #db_subnet_group_name /  = aws_db_subnet_group.default.name

  tags = {
    Name = "mysql-read-replica2"
  }
}

# RDS 인스턴스 생성 (마스터)
resource "aws_db_instance" "master3" {
  allocated_storage    = 6
  port = 3316
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  db_name              = var.mysql_db3
  username             = var.mysql_user
  password             = var.mysql_password  # 여기에 실제 비밀번호를 입력하세요
  # parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  multi_az             = false
  publicly_accessible = true
  backup_retention_period = 7  # Read Replica 생성을 위해 백업 보존 기간 설정
  availability_zone = "${var.region}a"

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
}

# RDS Read Replica 생성
resource "aws_db_instance" "replica3" {
  instance_class       = "db.t3.micro"
  replicate_source_db  = aws_db_instance.master3.identifier
  multi_az = false
  publicly_accessible  = true
  skip_final_snapshot  = true
  port = 3316
  availability_zone = "${var.region}a"

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  # Read Replica는 마스터와 같은 서브넷 그룹을 사용합니다
  #db_subnet_group_name /  = aws_db_subnet_group.default.name

  tags = {
    Name = "mysql-read-replica3"
  }
}




# 출력

# locals {
#   rds_master_endpoint_without_port = element(split(":", aws_db_instance.master1.endpoint), 0)
#   rds_replica_endpoint_without_port = element(split(":", aws_db_instance.replica1.endpoint), 0)
 
# }

# locals {
#   rds_master_endpoint_without_port = element(split(":", aws_db_instance.master2.endpoint), 0)
#   rds_replica_endpoint_without_port = element(split(":", aws_db_instance.replica2.endpoint), 0)
 
# }

# locals {
#   rds_master_endpoint_without_port = element(split(":", aws_db_instance.master3.endpoint), 0)
#   rds_replica_endpoint_without_port = element(split(":", aws_db_instance.replica3.endpoint), 0)
 
# }

# output "ec2_public_ip" {
#   description = "Public IP of EC2 instance"
#   value       = aws_instance.rds-ec2.public_ip
# }

output "rds_master_endpoint1" {
  description = "Endpoint of RDS master instance"
  value       = aws_db_instance.master1.endpoint
}

output "rds_replica_endpoint1" {
  description = "Endpoint of RDS read replica instance"
  value       = aws_db_instance.replica1.endpoint
}

output "endpoint1" {
  value = element(split(":", aws_db_instance.master1.endpoint), 0)
  depends_on = [ aws_db_instance.master1 ]
}

output "rds_master_endpoint2" {
  description = "Endpoint of RDS master instance"
  value       = aws_db_instance.master2.endpoint
}

output "rds_replica_endpoint2" {
  description = "Endpoint of RDS read replica instance"
  value       = aws_db_instance.replica2.endpoint
}

output "endpoint2" {
  value = element(split(":", aws_db_instance.master2.endpoint), 0)
  depends_on = [ aws_db_instance.master2 ]
}

output "rds_master_endpoint3" {
  description = "Endpoint of RDS master instance"
  value       = aws_db_instance.master3.endpoint
}

output "rds_replica_endpoint3" {
  description = "Endpoint of RDS read replica instance"
  value       = aws_db_instance.replica3.endpoint
}

output "endpoint3" {
  value = element(split(":", aws_db_instance.master3.endpoint), 0)
  depends_on = [ aws_db_instance.master3 ]
}


