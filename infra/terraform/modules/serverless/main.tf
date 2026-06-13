# ============================================================
# Lambda + EventBridge — Serverless ROI Cron
# ============================================================
# Replaces 24/7 roi-cron Docker container with serverless
# Cost: ~$0.10/month (720 invocations × 256MB × 60s)
# ============================================================

data "archive_file" "roi_cron" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/roi-cron"
  output_path = "${path.module}/roi-cron.zip"
}

resource "aws_lambda_function" "roi_cron" {
  filename         = data.archive_file.roi_cron.output_path
  source_code_hash = data.archive_file.roi_cron.output_base64sha256
  function_name    = "roi-platform-cron"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      DATABASE_URL = var.database_url
      NODE_ENV     = "production"
    }
  }

  tags = {
    Name = "roi-cron-function"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "roi-platform-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# EventBridge Schedule — every hour
resource "aws_scheduler_schedule" "roi_hourly_cron" {
  name       = "roi-hourly-cron"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(1 hour)"

  target {
    arn      = aws_lambda_function.roi_cron.arn
    role_arn = aws_iam_role.scheduler_exec.arn
  }
}

# IAM Role for EventBridge Scheduler
resource "aws_iam_role" "scheduler_exec" {
  name = "roi-platform-scheduler-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "roi-invoke-lambda"
  role = aws_iam_role.scheduler_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.roi_cron.arn
    }]
  })
}
