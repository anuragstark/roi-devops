terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "roi-platform-tf-state-974387"
    key            = "ec2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "roi-platform-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ROI-Platform"
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Security Group
resource "aws_security_group" "roi_sg" {
  name        = "roi-platform-sg"
  description = "Security group for ROI Investment Platform"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Frontend (Port 3000)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Frontend access"
  }

  # Backend API (Port 5000)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Backend API access"
  }

  # HTTP (Optional - for future nginx setup)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS (Optional - for future SSL setup)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # Outbound - Allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "roi-platform-sg"
    Environment = var.environment
  }
}

# EC2 Instance
resource "aws_instance" "roi_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.roi_sg.id]

  # User data script to install Docker and Docker Compose
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              apt-get update
              apt-get upgrade -y
              
              # Install Docker
              curl -fsSL https://get.docker.com -o get-docker.sh
              sh get-docker.sh
              
              # Install Docker Compose
              apt-get install -y docker-compose-plugin
              
              # Add ubuntu user to docker group
              usermod -aG docker ubuntu
              
              # Enable Docker service
              systemctl enable docker
              systemctl start docker
              
              # Create app directory
              mkdir -p /home/ubuntu/app
              chown ubuntu:ubuntu /home/ubuntu/app
              
              echo "Waiting for code push..." > /home/ubuntu/app/STATUS.txt
              echo "Setup completed successfully" > /home/ubuntu/setup-complete.txt
              EOF

  tags = {
    Name        = "roi-platform-server"
    Environment = var.environment
  }

  # Increase root volume size slightly for Docker images
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

# Elastic IP for stable public address
resource "aws_eip" "roi_eip" {
  domain = "vpc"

  tags = {
    Name        = "roi-platform-eip"
    Environment = var.environment
  }
}

resource "aws_eip_association" "roi_eip_assoc" {
  instance_id   = aws_instance.roi_server.id
  allocation_id = aws_eip.roi_eip.id
}

# ============================================================
# RDS Database (Free Tier db.t4g.micro)
# ============================================================

resource "aws_security_group" "rds_sg" {
  name        = "roi-platform-rds-sg"
  description = "Allow MySQL traffic from EC2"

  # Allow only the EC2 instance to talk to the database on 3306
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.roi_sg.id]
    description     = "Allow MySQL traffic from main EC2 server"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "roi-platform-rds-sg"
    Environment = var.environment
  }
}

resource "aws_db_instance" "roi_database" {
  identifier           = "roi-production-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t4g.micro"     # Free Tier Eligible
  allocated_storage    = 20                 # 20GB is free tier limit
  storage_type         = "gp2"
  
  db_name              = "roi_platform"
  username             = var.db_username
  password             = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false            # Security best practice: Not on public internet
  skip_final_snapshot    = true             # Set to false if you want backups when destroying
  
  tags = {
    Name        = "roi-production-db"
    Environment = var.environment
  }
}
