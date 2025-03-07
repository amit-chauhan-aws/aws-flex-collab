# -----------------------------------------------------------------------------
# Define required providers
# -----------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Define locals
# -----------------------------------------------------------------------------

locals {
  common_bucket_config = {
    force_destroy           = var.force_destroy
    acl                     = "private"
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
    object_ownership        = "BucketOwnerEnforced"
    versioning_enabled      = var.enable_versioning
    lifecycle_rules         = var.lifecycle_rules
    sse_algorithm           = "aws:kms"
  }

  # Default tags for all resources
  default_tags = merge(
    var.tags,
    {
      Module = "frontend"
    }
  )
}

# -----------------------------------------------------------------------------
# Define data sources
# -----------------------------------------------------------------------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    sid    = "AllowCloudFrontAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:GetObjectVersion"
    ]
    resources = [
      "${aws_s3_bucket.frontend_bucket.arn}",
      "${aws_s3_bucket.frontend_bucket.arn}/*"
    ]
  }

  # Enforce HTTPS
  statement {
    sid = "EnforceHTTPS"

    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      "${aws_s3_bucket.frontend_bucket.arn}",
      "${aws_s3_bucket.frontend_bucket.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
  statement {
    sid = "EnforceEncryptionInTransit"

    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      "${aws_s3_bucket.frontend_bucket.arn}",
      "${aws_s3_bucket.frontend_bucket.arn}/*"
    ]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

# -----------------------------------------------------------------------------
# Define resources
# -----------------------------------------------------------------------------


resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "${var.bucket_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"
  force_destroy = local.common_bucket_config.force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "frontend_bucket" {

  bucket = aws_s3_bucket.frontend_bucket.id

  versioning_configuration {
    status = local.common_bucket_config.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_encryption" {

  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.frontend_bucket_kms_key_arn
      sse_algorithm     = local.common_bucket_config.sse_algorithm
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = local.common_bucket_config.block_public_acls
  block_public_policy     = local.common_bucket_config.block_public_policy
  ignore_public_acls      = local.common_bucket_config.ignore_public_acls
  restrict_public_buckets = local.common_bucket_config.restrict_public_buckets
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend_bucket" {
  bucket = aws_s3_bucket.frontend_bucket.id

  dynamic "rule" {
    for_each = local.common_bucket_config.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"
      filter {
        prefix = ""
      }

      dynamic "transition" {
        for_each = rule.value.transitions

        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days > 0 ? [1] : []

        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions

        content {
          noncurrent_days = noncurrent_version_transition.value.days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days > 0 ? [1] : []

        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }
    }
  }
}



resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${var.bucket_name}"
}

resource "aws_cloudfront_distribution" "frontend_distribution" {
  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend_bucket.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Distribution for ${var.bucket_name}"
  default_root_object = var.index_document

  default_cache_behavior {
    target_origin_id = "S3-${aws_s3_bucket.frontend_bucket.id}"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    min_ttl     = 0
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }


  tags = local.tags
}
