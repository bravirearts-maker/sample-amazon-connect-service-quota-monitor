data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id               = data.aws_caller_identity.current.account_id
  region                   = data.aws_region.current.name
  metrics_bucket_base_name = "${var.name_prefix}-metrics-${local.account_id}-${local.region}"
  metrics_bucket_name      = var.enable_s3_storage ? (var.metrics_bucket_name != "" ? var.metrics_bucket_name : local.metrics_bucket_base_name) : ""
  create_metrics_bucket    = var.enable_s3_storage && var.metrics_bucket_name == ""
  logs_bucket_name         = "${var.name_prefix}-access-logs-${local.account_id}-${local.region}"

  deployment_bucket_base_name = "${var.name_prefix}-deploy-${local.account_id}-${local.region}"
  deployment_bucket_name      = var.enable_deployment_bucket ? (var.deployment_bucket_name != "" ? var.deployment_bucket_name : local.deployment_bucket_base_name) : var.deployment_bucket_name
  create_deployment_bucket    = var.enable_deployment_bucket
}

resource "aws_s3_bucket" "logs" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = local.logs_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "metrics" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = local.metrics_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metrics" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = aws_s3_bucket.metrics[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "metrics" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = aws_s3_bucket.metrics[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "metrics" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = aws_s3_bucket.metrics[0].id

  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "metrics" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = aws_s3_bucket.metrics[0].id

  rule {
    id     = "ExpireOldReports"
    status = "Enabled"

    filter {
      prefix = "connect-reports/"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "ExpireOldMetrics"
    status = "Enabled"

    filter {
      prefix = "connect-metrics/"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket" "deployment" {
  count  = local.create_deployment_bucket ? 1 : 0
  bucket = local.deployment_bucket_name
  tags   = merge(var.tags, { Purpose = "ConnectQuotaMonitorDeployment" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deployment" {
  count  = local.create_deployment_bucket ? 1 : 0
  bucket = aws_s3_bucket.deployment[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "deployment" {
  count  = local.create_deployment_bucket ? 1 : 0
  bucket = aws_s3_bucket.deployment[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "deployment" {
  count  = local.create_deployment_bucket ? 1 : 0
  bucket = aws_s3_bucket.deployment[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "deployment" {
  count  = local.create_deployment_bucket ? 1 : 0
  bucket = aws_s3_bucket.deployment[0].id

  rule {
    id     = "DeleteOldDeploymentPackages"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

