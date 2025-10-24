# ========================================
# Redis Module Variables
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
  description = "VPC ID where Redis will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Redis"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Redis"
  type        = list(string)
  default     = []
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs"
  type        = list(string)
  default     = []
}

# ========================================
# Redis Configuration
# ========================================
variable "node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_clusters" {
  description = "Number of cache clusters"
  type        = number
  default     = 2
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

# ========================================
# Subnet and Parameter Groups
# ========================================
variable "create_subnet_group" {
  description = "Whether to create subnet group"
  type        = bool
  default     = true
}

variable "subnet_group_name" {
  description = "Existing subnet group name"
  type        = string
  default     = null
}

variable "create_parameter_group" {
  description = "Whether to create parameter group"
  type        = bool
  default     = true
}

variable "parameter_group_name" {
  description = "Existing parameter group name"
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "redis7"
}

variable "parameters" {
  description = "List of parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# ========================================
# Backup Configuration
# ========================================
variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "Snapshot window"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:05:00-sun:07:00"
}

# ========================================
# Security Configuration
# ========================================
variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "Auth token for Redis"
  type        = string
  default     = null
  sensitive   = true
}

# ========================================
# High Availability
# ========================================
variable "multi_az_enabled" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = true
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover"
  type        = bool
  default     = true
}

# ========================================
# Logging
# ========================================
variable "log_destination" {
  description = "Log destination"
  type        = string
  default     = null
}

variable "log_destination_type" {
  description = "Log destination type"
  type        = string
  default     = "cloudwatch-logs"
}

variable "log_format" {
  description = "Log format"
  type        = string
  default     = "text"
}

# ========================================
# Tags
# ========================================
variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
