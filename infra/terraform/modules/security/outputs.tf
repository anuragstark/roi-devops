output "db_secret_arn" {
  description = "ARN of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secrets"
  value       = aws_secretsmanager_secret.jwt_secrets.arn
}
