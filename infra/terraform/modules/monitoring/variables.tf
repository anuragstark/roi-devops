variable "ec2_instance_id" {
  description = "EC2 Instance ID to monitor"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS Instance Identifier to monitor"
  type        = string
  default     = "roi-production-db"
}
