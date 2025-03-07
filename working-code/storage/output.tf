# outputs.tf - S3 Storage Module

# -----------------------------------------------------------------------------
# Input Bucket Outputs
# -----------------------------------------------------------------------------
output "input_bucket_id" {
  description = "The ID of the input bucket"
  value       = var.create_input_bucket ? aws_s3_bucket.input_bucket[0].id : null
}

output "input_bucket_arn" {
  description = "The ARN of the input bucket"
  value       = var.create_input_bucket ? aws_s3_bucket.input_bucket[0].arn : null
}

output "input_bucket_domain_name" {
  description = "The domain name of the input bucket"
  value       = var.create_input_bucket ? aws_s3_bucket.input_bucket[0].bucket_domain_name : null
}

output "input_bucket_regional_domain_name" {
  description = "The regional domain name of the input bucket"
  value       = var.create_input_bucket ? aws_s3_bucket.input_bucket[0].bucket_regional_domain_name : null
}

# -----------------------------------------------------------------------------
# Output Bucket Outputs
# -----------------------------------------------------------------------------
output "output_bucket_id" {
  description = "The ID of the output bucket"
  value       = var.create_output_bucket ? aws_s3_bucket.output_bucket[0].id : null
}

output "output_bucket_arn" {
  description = "The ARN of the output bucket"
  value       = var.create_output_bucket ? aws_s3_bucket.output_bucket[0].arn : null
}

output "output_bucket_domain_name" {
  description = "The domain name of the output bucket"
  value       = var.create_output_bucket ? aws_s3_bucket.output_bucket[0].bucket_domain_name : null
}

output "output_bucket_regional_domain_name" {
  description = "The regional domain name of the output bucket"
  value       = var.create_output_bucket ? aws_s3_bucket.output_bucket[0].bucket_regional_domain_name : null
}

# -----------------------------------------------------------------------------
# SQS Queue Outputs
# -----------------------------------------------------------------------------
output "sqs_queue_id" {
  description = "The ID of the SQS queue for input bucket events"
  value       = var.create_input_bucket && var.create_event_queue ? aws_sqs_queue.input_bucket_queue[0].id : null
}

output "sqs_queue_arn" {
  description = "The ARN of the SQS queue for input bucket events"
  value       = var.create_input_bucket && var.create_event_queue ? aws_sqs_queue.input_bucket_queue[0].arn : null
}

output "sqs_queue_url" {
  description = "The URL of the SQS queue for input bucket events"
  value       = var.create_input_bucket && var.create_event_queue ? aws_sqs_queue.input_bucket_queue[0].url : null
}

output "dlq_id" {
  description = "The ID of the dead-letter queue"
  value       = var.create_input_bucket && var.create_event_queue && var.enable_dlq ? aws_sqs_queue.input_bucket_dlq[0].id : null
}

output "dlq_arn" {
  description = "The ARN of the dead-letter queue"
  value       = var.create_input_bucket && var.create_event_queue && var.enable_dlq ? aws_sqs_queue.input_bucket_dlq[0].arn : null
}

output "dlq_url" {
  description = "The URL of the dead-letter queue"
  value       = var.create_input_bucket && var.create_event_queue && var.enable_dlq ? aws_sqs_queue.input_bucket_dlq[0].url : null
}
