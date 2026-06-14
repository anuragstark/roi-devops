output "web_public_ip" {
  description = "Public IP address of the Web Server"
  value       = aws_eip.roi_eip.public_ip
}

output "monitoring_public_ip" {
  description = "Public IP address of the Monitoring Server"
  value       = aws_eip.monitoring_eip.public_ip
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = "http://${aws_eip.roi_eip.public_ip}:3000"
}

output "backend_url" {
  description = "Backend API URL"
  value       = "http://${aws_eip.roi_eip.public_ip}:5000"
}

output "ssh_command_web" {
  description = "SSH command to connect to the Web instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.roi_eip.public_ip}"
}

output "ssh_command_monitoring" {
  description = "SSH command to connect to the Monitoring instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.monitoring_eip.public_ip}"
}

output "rds_endpoint" {
  description = "RDS Database Endpoint"
  value       = aws_db_instance.roi_database.endpoint
}

# S3 Outputs

output "uploads_bucket_name" {
  description = "S3 bucket for app file uploads"
  value       = aws_s3_bucket.uploads.bucket
}

output "uploads_bucket_arn" {
  description = "ARN of the uploads bucket"
  value       = aws_s3_bucket.uploads.arn
}

