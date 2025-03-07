# variables.tf - S3 Storage Module

# -----------------------------------------------------------------------------
# General Variables
# -----------------------------------------------------------------------------
variable "name_prefix" {
  description = "Prefix to use for resource names"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Bucket Creation Variables
# -----------------------------------------------------------------------------
variable "create_input_bucket" {
  description = "Whether to create the input bucket"
  type        = bool
  default     = true
}

variable "create_output_bucket" {
  description = "Whether to create the output bucket"
  type        = bool
  default     = true
}

variable "input_bucket_name" {
  description = "Name of the input bucket. If not provided, it will be generated using the name_prefix."
  type        = string
  default     = ""
}

variable "output_bucket_name" {
  description = "Name of the output bucket. If not provided, it will be generated using the name_prefix."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Whether to force destroy the buckets even if they contain objects"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Security Variables
# -----------------------------------------------------------------------------
variable "input_bucket_kms_key_arn" {
  description = "ARN of the KMS key to use for encrypting the input bucket"
  type        = string
}

variable "output_bucket_kms_key_arn" {
  description = "ARN of the KMS key to use for encrypting the output bucket"
  type        = string
}

variable "vpc_endpoint_id" {
  description = "ID of the VPC endpoint to allow access from"
  type        = string
  default     = ""
}

variable "input_bucket_allowed_roles" {
  description = "List of IAM role ARNs that are allowed to access the input bucket"
  type        = list(string)
  default     = []
}

variable "output_bucket_allowed_roles" {
  description = "List of IAM role ARNs that are allowed to access the output bucket"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Bucket Configuration Variables
# -----------------------------------------------------------------------------
variable "enable_versioning" {
  description = "Whether to enable versioning on the buckets"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules to apply to the buckets"
  type = list(object({
    id                                 = string
    enabled                            = bool
    expiration_days                    = number
    noncurrent_version_expiration_days = number
    transitions = list(object({
      days          = number
      storage_class = string
    }))
    noncurrent_version_transitions = list(object({
      days          = number
      storage_class = string
    }))
  }))
  default = [
    {
      id                                 = "transition-to-infrequent-access"
      enabled                            = true
      expiration_days                    = 0
      noncurrent_version_expiration_days = 90
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
      noncurrent_version_transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
    }
  ]
}

# -----------------------------------------------------------------------------
# Event Notification Variables
# -----------------------------------------------------------------------------
variable "create_event_queue" {
  description = "Whether to create an SQS queue for S3 event notifications"
  type        = bool
  default     = true
}

variable "s3_event_types" {
  description = "List of S3 event types to trigger notifications for"
  type        = list(string)
  default     = ["s3:ObjectCreated:*"]
}

variable "s3_event_filter_prefix" {
  description = "Object key prefix for filtering S3 event notifications"
  type        = string
  default     = ""
}

variable "s3_event_filter_suffix" {
  description = "Object key suffix for filtering S3 event notifications"
  type        = string
  default     = ""
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout for the SQS queue in seconds"
  type        = number
  default     = 300
}

variable "sqs_message_retention_seconds" {
  description = "Message retention period for the SQS queue in seconds"
  type        = number
  default     = 1209600 # 14 days
}

variable "sqs_kms_key_arn" {
  description = "ARN of the KMS key to use for SQS queue encryption"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Dead Letter Queue Variables
# -----------------------------------------------------------------------------
variable "enable_dlq" {
  description = "Whether to create a dead-letter queue for failed messages"
  type        = bool
  default     = true
}

variable "dlq_max_receive_count" {
  description = "Number of times a message can be unsuccessfully dequeued before being moved to the dead-letter queue"
  type        = number
  default     = 5
}

variable "dlq_message_retention_seconds" {
  description = "Message retention period for the dead-letter queue in seconds"
  type        = number
  default     = 1209600 # 14 days
}
