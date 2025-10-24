# ========================================
# EKS Cluster Module Variables
# ========================================

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

# ========================================
# Cluster Configuration
# ========================================
variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks that can access the public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
}

# ========================================
# Network Configuration
# ========================================
variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS cluster"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Subnet IDs for EKS control plane"
  type        = list(string)
  default     = null
}

# ========================================
# Addons Configuration
# ========================================
variable "cluster_addons" {
  description = "Map of cluster addon configurations"
  type        = any
  default = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_version" {
  description = "EBS CSI driver version"
  type        = string
  default     = null
}

# ========================================
# Node Groups Configuration
# ========================================
variable "eks_managed_node_group_defaults" {
  description = "Default settings for EKS managed node groups"
  type        = any
  default = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    
    min_size     = 1
    max_size     = 3
    desired_size = 2
    
    disk_size = 50
    
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions"
  type        = any
  default = {
    default = {
      name = "default"
      
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      min_size     = 1
      max_size     = 3
      desired_size = 2
      
      disk_size = 50
      
      labels = {
        role = "default"
      }
      
      taints = []
      
      update_config = {
        max_unavailable_percentage = 25
      }
    }
  }
}

# ========================================
# IRSA Configuration
# ========================================
variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

# ========================================
# Security Groups
# ========================================
variable "cluster_security_group_additional_rules" {
  description = "Additional security group rules for cluster"
  type        = any
  default     = {}
}

variable "node_security_group_additional_rules" {
  description = "Additional security group rules for nodes"
  type        = any
  default     = {}
}

# ========================================
# Tags
# ========================================
variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
