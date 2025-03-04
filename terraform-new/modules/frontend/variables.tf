variable "bucket_name" {
  description = "The name of the S3 bucket. (Must be globally unique)"
  type        = string
  default     = "my-unique-frontend-bucket-1234"  # Change as needed
}

variable "index_document" {
  description = "The index document for website hosting."
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "The error document for website hosting."
  type        = string
  default     = "error.html"
}

variable "force_destroy" {
  description = "Force destroy S3 bucket (allow deleting non-empty buckets)."
  type        = bool
  default     = false
}

variable "default_ttl" {
  description = "Default TTL (in seconds) for CloudFront cache."
  type        = number
  default     = 3600
}

variable "max_ttl" {
  description = "Max TTL (in seconds) for CloudFront cache."
  type        = number
  default     = 86400
}

variable "price_class" {
  description = "CloudFront price class. Options: PriceClass_All, PriceClass_100, PriceClass_200."
  type        = string
  default     = "PriceClass_All"
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "FrontendTest"
  }
}

variable "enable_waf" {
  description = "Enable WAF integration for CloudFront."
  type        = bool
  default     = true
}
