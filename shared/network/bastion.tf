# # Bastion 보안 그룹 생성
# resource "aws_security_group" "bastion_sg" {
#   name   = "${var.project_name}-bastion-sg"
#   vpc_id = module.vpc.vpc_id

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = var.allowed_ssh_cidr_blocks # SSH 접근 IP 설정
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${var.project_name}-bastion-sg"
#   }
# }

# # Bastion EC2 Instance 생성
# # resource "aws_instance" "bastion" {
# #   ami                         = var.ami_id      # Amazon AMI(리전별로 변경 필요)
# #   instance_type               = var.instance_type                 # 필요에 따라 인스턴스 타입 변경
# #   subnet_id                   = module.vpc.public_subnets[0] # public 서브넷 사용
# #   associate_public_ip_address = true
# #   key_name                    = aws_key_pair.bastion_generated_key.key_name # 생성된 Key Pair 사용
# #   security_groups             = [aws_security_group.bastion_sg.id]

# #   tags = {
# #     Name = "${var.project_name}-bastion"
# #   }
# # }

# # Key Pair Private Key 생성 및 저장
# resource "tls_private_key" "bastion_private_key" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }

# resource "aws_key_pair" "bastion_generated_key" {
#   key_name   = var.key_pair_name
#   public_key = tls_private_key.bastion_private_key.public_key_openssh
# }

# # Private Key를 file 형태로 저장
# resource "local_file" "private_key" {

#     content = tls_private_key.bastion_private_key.private_key_pem
#     filename = "${path.module}/eks_key.pem"
  
# }

# # Private Key를 출력 및 저장
# output "bastion_private_key" {
#   value     = tls_private_key.bastion_private_key.private_key_pem
#   sensitive = true
# }

# # Key Pair Name 출력
# output "bastion_key_name" {
#   value = aws_key_pair.bastion_generated_key.key_name
# }
