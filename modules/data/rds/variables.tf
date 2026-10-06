# ========================================
# RDS Module Variables
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
  description = "VPC ID"
  type        = string
}

variable "db_subnet_group_name" {
  description = "DB subnet group name"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect"
  type        = list(string)
  default     = []
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs"
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "MySQL engine version (major.minor 를 주면 최신 minor 를 고른다)"
  type        = string
  default     = "8.4"
}

variable "parameter_group_family" {
  description = "Parameter group family (engine_version 과 맞아야 한다)"
  type        = string
  default     = "mysql8.4"
}

variable "parameters" {
  description = "DB parameters"
  type        = list(map(string))
  default = [
    { name = "character_set_server", value = "utf8mb4" },
    { name = "collation_server", value = "utf8mb4_unicode_ci" },
  ]
}

variable "instance_class" {
  description = "Instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Initial storage (GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling upper bound (GB)"
  type        = number
  default     = 100
}

variable "kms_key_id" {
  description = "KMS key for storage encryption (null 이면 AWS 관리형 키)"
  type        = string
  default     = null
}

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = null
}

variable "master_username" {
  description = "Master username"
  type        = string
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "MySQL port"
  type        = number
  default     = 3306
}

variable "multi_az" {
  description = "Multi-AZ 동기 standby"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention (days)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window (UTC)"
  type        = string
  default     = "18:00-19:00"
}

variable "maintenance_window" {
  description = "Maintenance window (UTC)"
  type        = string
  default     = "sun:19:00-sun:20:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Deletion protection"
  type        = bool
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Log types exported to CloudWatch"
  type        = list(string)
  default     = ["error", "slowquery"]
}

variable "performance_insights_enabled" {
  description = "Performance Insights"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply modifications immediately"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
