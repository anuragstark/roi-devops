# S3 Buckets: Note that TF state bucket and DynamoDB lock table were created manually. Only the uploads bucket is managed here.

# 2. Application Uploads Bucket (KYC docs, screenshots, etc.)
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-uploads-${var.account_suffix}"

  tags = {
    Name        = "${var.project_name}-uploads"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration for browser-based uploads
resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["http://localhost:3000", "https://paisatest.online"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# Lifecycle rule: move old uploads to cheaper storage
resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "archive-old-uploads"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}
