# ============================================================
# IAM Policy for Backend S3 Access
# ============================================================
# Scoped least-privilege policy: backend can only read/write
# to the uploads bucket, nothing else.
# ============================================================

resource "aws_iam_policy" "backend_s3_uploads" {
  name        = "${var.project_name}-s3-uploads"
  description = "Allows backend to upload/download/delete from the uploads S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.uploads.arn
      },
      {
        Sid    = "ObjectOperations"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectAcl",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.uploads.arn}/*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-s3-uploads-policy"
    Environment = var.environment
  }
}

# Attach the policy to the existing IAM user (roi-platform-user)
resource "aws_iam_user_policy_attachment" "backend_s3" {
  user       = "roi-platform-user"
  policy_arn = aws_iam_policy.backend_s3_uploads.arn
}
