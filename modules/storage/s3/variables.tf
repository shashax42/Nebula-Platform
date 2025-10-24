# ========================================
# S3 Module Variables
# ========================================

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name (if null, auto-generated)"
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow bucket to be destroyed even if it contains objects"
  type        = bool
  default     = false
}

# ========================================
# Versioning Configuration
# ========================================
variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

# ========================================
# Encryption Configuration
# ========================================
variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm"
  type        = string
  default     = "AES256"
  
  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "SSE algorithm must be either AES256 or aws:kms."
  }
}

variable "kms_master_key_id" {
  description = "KMS key ID for encryption (required if sse_algorithm is aws:kms)"
  type        = string
  default     = null
}

variable "bucket_key_enabled" {
  description = "Enable S3 bucket key for KMS encryption"
  type        = bool
  default     = true
}

# ========================================
# Public Access Block
# ========================================
variable "block_public_acls" {
  description = "Block public ACLs"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies"
  type        = bool
  default     = true
}

# ========================================
# Lifecycle Rules
# ========================================
variable "lifecycle_rules" {
  description = "List of lifecycle rules"
  type = list(object({
    id      = string
    enabled = bool
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    expiration = optional(object({
      days                         = optional(number)
      date                         = optional(string)
      expired_object_delete_marker = optional(bool)
    }))
    noncurrent_version_expiration = optional(object({
      days = number
    }))
    transitions = optional(list(object({
      days          = optional(number)
      date          = optional(string)
      storage_class = string
    })))
    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })))
  }))
  default = []
}

# ========================================
# Notification Configuration
# ========================================
variable "notification_configuration" {
  description = "S3 bucket notification configuration"
  type = object({
    lambda_functions = optional(list(object({
      lambda_function_arn = string
      events              = list(string)
      filter_prefix       = optional(string)
      filter_suffix       = optional(string)
    })), [])
    topics = optional(list(object({
      topic_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })), [])
    queues = optional(list(object({
      queue_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })), [])
  })
  default = null
}

# ========================================
# CORS Configuration
# ========================================
variable "cors_rules" {
  description = "List of CORS rules"
  type = list(object({
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []
}

# ========================================
# Tags
# ========================================
variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
