output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.roi_server.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.roi_server.public_ip
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = "http://${aws_instance.roi_server.public_ip}:3000"
}

output "backend_url" {
  description = "Backend API URL"
  value       = "http://${aws_instance.roi_server.public_ip}:5000"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.roi_server.public_ip}"
}

output "rds_endpoint" {
  description = "RDS Database Endpoint"
  value       = aws_db_instance.roi_database.endpoint
}

output "deployment_instructions" {
  description = "Quick deployment instructions"
  value       = <<-EOT
    
    🚀 ROI Platform Deployment Complete!
    
    📌 Server Details:
       Instance ID: ${aws_instance.roi_server.id}
       Public IP:   ${aws_instance.roi_server.public_ip}
    
    🗄️ Database (RDS):
       Endpoint:    ${aws_db_instance.roi_database.endpoint}
    
    🌐 Access URLs:
       Frontend:    http://${aws_instance.roi_server.public_ip}:3000
       Backend API: http://${aws_instance.roi_server.public_ip}:5000/api
    
    🔐 SSH Access:
       ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.roi_server.public_ip}
    
    📋 Next Steps:
       1. SSH into the server
       2. Clone your repository (since it is private, use a Personal Access Token):
          cd /home/ubuntu/app && git clone https://<YOUR_GITHUB_PAT>@github.com/anuragstark/Roi-project.git .
       3. Create .env file with production variables
          IMPORTANT: Update DATABASE_URL in .env to point to the RDS endpoint!
          DATABASE_URL="mysql://${var.db_username}:<YOUR_DB_PASSWORD>@${aws_db_instance.roi_database.endpoint}/roi_platform"
       4. Run: docker compose -f docker-compose.yml up -d
       5. Check logs: docker compose logs -f
    
    ⚙️  GitHub Actions will auto-deploy on push to main branch
  EOT
}

# ============================================================
# S3 Outputs
# ============================================================

output "uploads_bucket_name" {
  description = "S3 bucket for app file uploads"
  value       = aws_s3_bucket.uploads.bucket
}

output "uploads_bucket_arn" {
  description = "ARN of the uploads bucket"
  value       = aws_s3_bucket.uploads.arn
}

