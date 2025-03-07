# main.tf - S3 Storage Module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------
locals {
  input_bucket_name  = var.input_bucket_name != "" ? var.input_bucket_name : "${var.name_prefix}-inputs-${data.aws_caller_identity.current.account_id}"
  output_bucket_name = var.output_bucket_name != "" ? var.output_bucket_name : "${var.name_prefix}-outputs-${data.aws_caller_identity.current.account_id}"

  # Common bucket settings
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
      Module = "storage"
    }
  )
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# IAM policy documents
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "s3_vpc_endpoint_policy" {
  statement {
    sid = "AllowS3VpcEndpointAccess"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging"
    ]

    resources = [
      var.create_input_bucket ? "arn:aws:s3:::${local.input_bucket_name}" : "",
      var.create_input_bucket ? "arn:aws:s3:::${local.input_bucket_name}/*" : "",
      var.create_output_bucket ? "arn:aws:s3:::${local.output_bucket_name}" : "",
      var.create_output_bucket ? "arn:aws:s3:::${local.output_bucket_name}/*" : ""
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:sourceVpce"
      values   = [var.vpc_endpoint_id]
    }
  }
}

data "aws_iam_policy_document" "input_bucket_policy" {
  # Base policy allowing VPC endpoint access
  dynamic "statement" {
    for_each = var.vpc_endpoint_id != "" ? [1] : []
    content {
      sid = "AllowVPCEndpointAccess"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetObjectVersion"
      ]

      resources = [
        "arn:aws:s3:::${local.input_bucket_name}",
        "arn:aws:s3:::${local.input_bucket_name}/*"
      ]

      condition {
        test     = "StringEquals"
        variable = "aws:sourceVpce"
        values   = [var.vpc_endpoint_id]
      }
    }
  }

  # Allow specific IAM roles
  dynamic "statement" {
    for_each = length(var.input_bucket_allowed_roles) > 0 ? [1] : []
    content {
      sid = "AllowSpecificRoles"

      principals {
        type        = "AWS"
        identifiers = var.input_bucket_allowed_roles
      }

      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetObjectVersion"
      ]

      resources = [
        "arn:aws:s3:::${local.input_bucket_name}",
        "arn:aws:s3:::${local.input_bucket_name}/*"
      ]
    }
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
      "arn:aws:s3:::${local.input_bucket_name}",
      "arn:aws:s3:::${local.input_bucket_name}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Enforce encryption in transit
  statement {
    sid = "EnforceEncryptionInTransit"

    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      "arn:aws:s3:::${local.input_bucket_name}",
      "arn:aws:s3:::${local.input_bucket_name}/*"
    ]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

data "aws_iam_policy_document" "output_bucket_policy" {
  # Base policy allowing VPC endpoint access
  dynamic "statement" {
    for_each = var.vpc_endpoint_id != "" ? [1] : []
    content {
      sid = "AllowVPCEndpointAccess"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetObjectVersion"
      ]

      resources = [
        "arn:aws:s3:::${local.output_bucket_name}",
        "arn:aws:s3:::${local.output_bucket_name}/*"
      ]

      condition {
        test     = "StringEquals"
        variable = "aws:sourceVpce"
        values   = [var.vpc_endpoint_id]
      }
    }
  }

  # Allow specific IAM roles
  dynamic "statement" {
    for_each = length(var.output_bucket_allowed_roles) > 0 ? [1] : []
    content {
      sid = "AllowSpecificRoles"

      principals {
        type        = "AWS"
        identifiers = var.output_bucket_allowed_roles
      }

      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetObjectVersion"
      ]

      resources = [
        "arn:aws:s3:::${local.output_bucket_name}",
        "arn:aws:s3:::${local.output_bucket_name}/*"
      ]
    }
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
      "arn:aws:s3:::${local.output_bucket_name}",
      "arn:aws:s3:::${local.output_bucket_name}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Enforce encryption in transit
  statement {
    sid = "EnforceEncryptionInTransit"

    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      "arn:aws:s3:::${local.output_bucket_name}",
      "arn:aws:s3:::${local.output_bucket_name}/*"
    ]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

# -----------------------------------------------------------------------------
# Input Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "input_bucket" {
  count = var.create_input_bucket ? 1 : 0

  bucket        = local.input_bucket_name
  force_destroy = local.common_bucket_config.force_destroy

  tags = merge(
    local.default_tags,
    {
      Name = local.input_bucket_name
    }
  )
}

resource "aws_s3_bucket_versioning" "input_bucket_versioning" {
  count = var.create_input_bucket ? 1 : 0

  bucket = aws_s3_bucket.input_bucket[0].id

  versioning_configuration {
    status = local.common_bucket_config.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "input_bucket_encryption" {
  count = var.create_input_bucket ? 1 : 0

  bucket = aws_s3_bucket.input_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.input_bucket_kms_key_arn
      sse_algorithm     = local.common_bucket_config.sse_algorithm
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "input_bucket_public_access_block" {
  count = var.create_input_bucket ? 1 : 0

  bucket = aws_s3_bucket.input_bucket[0].id

  block_public_acls       = local.common_bucket_config.block_public_acls
  block_public_policy     = local.common_bucket_config.block_public_policy
  ignore_public_acls      = local.common_bucket_config.ignore_public_acls
  restrict_public_buckets = local.common_bucket_config.restrict_public_buckets
}

resource "aws_s3_bucket_ownership_controls" "input_bucket_ownership" {
  count = var.create_input_bucket ? 1 : 0

  bucket = aws_s3_bucket.input_bucket[0].id

  rule {
    object_ownership = local.common_bucket_config.object_ownership
  }
}

resource "aws_s3_bucket_policy" "input_bucket_policy" {
  count = var.create_input_bucket ? 1 : 0

  bucket = aws_s3_bucket.input_bucket[0].id
  policy = data.aws_iam_policy_document.input_bucket_policy.json

  depends_on = [
    aws_s3_bucket_public_access_block.input_bucket_public_access_block
  ]
}

resource "aws_s3_bucket_lifecycle_configuration" "input_bucket_lifecycle" {
  count = var.create_input_bucket && length(local.common_bucket_config.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.input_bucket[0].id

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

# -----------------------------------------------------------------------------
# SQS Queue for Input Bucket Events
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "input_bucket_queue" {
  count = var.create_input_bucket && var.create_event_queue ? 1 : 0

  name                       = "${var.name_prefix}-input-bucket-events"
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds

  # Enable encryption with KMS
  kms_master_key_id                 = var.sqs_kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  # Enable dead-letter queue if specified
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.input_bucket_dlq[0].arn
    maxReceiveCount     = var.dlq_max_receive_count
  }) : null

  tags = merge(
    local.default_tags,
    {
      Name = "${var.name_prefix}-input-bucket-events"
    }
  )
}

resource "aws_sqs_queue" "input_bucket_dlq" {
  count = var.create_input_bucket && var.create_event_queue && var.enable_dlq ? 1 : 0

  name                      = "${var.name_prefix}-input-bucket-events-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds

  # Enable encryption with KMS
  kms_master_key_id                 = var.sqs_kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(
    local.default_tags,
    {
      Name = "${var.name_prefix}-input-bucket-events-dlq"
    }
  )
}

resource "aws_sqs_queue_policy" "input_bucket_queue_policy" {
  count = var.create_input_bucket && var.create_event_queue ? 1 : 0

  queue_url = aws_sqs_queue.input_bucket_queue[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.input_bucket_queue[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.input_bucket[0].arn
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# S3 Event Notification for Input Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  count = var.create_input_bucket && var.create_event_queue ? 1 : 0

  bucket = aws_s3_bucket.input_bucket[0].id

  queue {
    queue_arn     = aws_sqs_queue.input_bucket_queue[0].arn
    events        = var.s3_event_types
    filter_prefix = var.s3_event_filter_prefix
    filter_suffix = var.s3_event_filter_suffix
  }

  depends_on = [
    aws_sqs_queue_policy.input_bucket_queue_policy
  ]
}

# -----------------------------------------------------------------------------
# Output Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "output_bucket" {
  count = var.create_output_bucket ? 1 : 0

  bucket        = local.output_bucket_name
  force_destroy = local.common_bucket_config.force_destroy

  tags = merge(
    local.default_tags,
    {
      Name = local.output_bucket_name
    }
  )
}

resource "aws_s3_bucket_versioning" "output_bucket_versioning" {
  count = var.create_output_bucket ? 1 : 0

  bucket = aws_s3_bucket.output_bucket[0].id

  versioning_configuration {
    status = local.common_bucket_config.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output_bucket_encryption" {
  count = var.create_output_bucket ? 1 : 0

  bucket = aws_s3_bucket.output_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.output_bucket_kms_key_arn
      sse_algorithm     = local.common_bucket_config.sse_algorithm
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "output_bucket_public_access_block" {
  count = var.create_output_bucket ? 1 : 0

  bucket = aws_s3_bucket.output_bucket[0].id

  block_public_acls       = local.common_bucket_config.block_public_acls
  block_public_policy     = local.common_bucket_config.block_public_policy
  ignore_public_acls      = local.common_bucket_config.ignore_public_acls
  restrict_public_buckets = local.common_bucket_config.restrict_public_buckets
}

resource "aws_s3_bucket_ownership_controls" "output_bucket_ownership" {
  count = var.create_output_bucket ? 1 : 0

  bucket = aws_s3_bucket.output_bucket[0].id

  rule {
    object_ownership = local.common_bucket_config.object_ownership
  }
}

resource "aws_s3_bucket_policy" "output_bucket_policy" {
  count = var.create_output_bucket ? 1 : 0

  bucket = aws_s3_bucket.output_bucket[0].id
  policy = data.aws_iam_policy_document.output_bucket_policy.json

  depends_on = [
    aws_s3_bucket_public_access_block.output_bucket_public_access_block
  ]
}

resource "aws_s3_bucket_lifecycle_configuration" "output_bucket_lifecycle" {
  count = var.create_output_bucket && length(local.common_bucket_config.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.output_bucket[0].id

  dynamic "rule" {
    for_each = local.common_bucket_config.lifecycle_rules

    content {
      id     = rule.value.id
      filter {
        prefix = ""
      }
      status = rule.value.enabled ? "Enabled" : "Disabled"

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
