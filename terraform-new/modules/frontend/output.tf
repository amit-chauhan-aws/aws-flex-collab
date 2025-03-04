output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.frontend_bucket.arn
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.frontend_distribution.id
}


output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}


output "waf_web_acl_arn" {
  description = "The ARN of the WAF Web ACL (if enabled)."
  value       = var.enable_waf ? aws_wafv2_web_acl.frontend_web_acl[0].arn : null
}
