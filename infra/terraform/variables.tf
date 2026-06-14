variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  # default     = "t3.medium" # 4GB RAM for Docker builds
  default     = "t3.small" # 2GB RAM (optimized for cost, adequate for deployment)
}

variable "db_username" {
  description = "RDS Database master username"
  type        = string
  default     = "roi_admin"
}

variable "db_password" {
  description = "RDS Database master password"
  type        = string
  sensitive   = true
  default     = "ChangeThisSecurePassword123!" # Override this via TF_VAR_db_password in production
}

variable "key_pair_name" {
  description = "Name of AWS key pair for SSH access"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "github_repo" {
  description = "GitHub repository URL"
  type        = string
  # default     = "https://github.com/your-username/roi"
  default     = "https://github.com/anuragstark/Roi-project.git"
}

variable "github_branch" {
  description = "GitHub branch to deploy"
  type        = string
  default     = "main"
}

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "roi-platform"
}

variable "account_suffix" {
  description = "Short suffix for globally unique S3 bucket names"
  type        = string
  default     = "974387"
}

variable "gh_pat" {
  description = "GitHub Personal Access Token for triggering webhooks"
  type        = string
  sensitive   = true
}
