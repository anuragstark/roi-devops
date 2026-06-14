# AWS Secrets Manager Module: Stores application secrets securely (different from TeleDoc's SSM). Cost: ~$0.40/secret/month.

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "roi-platform/db-credentials"
  description             = "Database credentials for ROI Platform"
  recovery_window_in_days = 7

  tags = {
    Name = "roi-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.rds_endpoint
    dbname   = "roi_platform"
    port     = 3306
  })
}

resource "aws_secretsmanager_secret" "jwt_secrets" {
  name                    = "roi-platform/jwt-secrets"
  description             = "JWT access and refresh secrets"
  recovery_window_in_days = 7

  tags = {
    Name = "roi-jwt-secrets"
  }
}

resource "aws_secretsmanager_secret" "app_config" {
  name                    = "roi-platform/app-config"
  description             = "Application configuration secrets"
  recovery_window_in_days = 7

  tags = {
    Name = "roi-app-config"
  }
}
