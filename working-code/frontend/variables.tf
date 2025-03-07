variable "enable_versioning" {
  description = "Whether to enable versioning on the buckets"
  type        = bool
  default     = true
}

variable "frontend_bucket_kms_key_arn" {
  description = "ARN of the KMS key to use for encrypting the input bucket"
  type        = string
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