# ========================================
# Aurora Module Variables
# ========================================

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Aurora will be deployed"
  type        = string
}

variable "db_subnet_group_name" {
  description = "DB subnet group name"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Aurora"
  type        = list(string)
  default     = []
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs"
  type        = list(string)
  default     = []
}

# ========================================
# Database Configuration
# ========================================
variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = null
}

variable "master_username" {
  description = "Master username for the DB"
  type        = string
}

variable "master_password" {
  description = "Master password for the DB"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 3306
}

# ========================================
# Engine Configuration
# ========================================
variable "engine" {
  description = "Database engine"
  type        = string
  default     = "aurora-mysql"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.04.1"
}

variable "engine_family" {
  description = "Database engine family"
  type        = string
  default     = "aurora-mysql8.0"
}

# ========================================
# Instance Configuration
# ========================================
variable "instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.t3.medium"
}

variable "instance_count" {
  description = "Number of instances (1 writer + N readers)"
  type        = number
  default     = 2
}

# ========================================
# Parameter Groups
# ========================================
variable "create_parameter_group" {
  description = "Whether to create parameter groups"
  type        = bool
  default     = true
}

variable "cluster_parameter_group_name" {
  description = "Existing cluster parameter group name"
  type        = string
  default     = null
}

variable "cluster_parameters" {
  description = "List of cluster parameters"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string)
  }))
  default = []
}

# ========================================
# Backup Configuration
# ========================================
variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

# ========================================
# Security Configuration
# ========================================
variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

# ========================================
# Monitoring Configuration
# ========================================
variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["error", "general", "slowquery"]
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval"
  type        = number
  default     = 60
}

# ========================================
# Tags
# ========================================
variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
