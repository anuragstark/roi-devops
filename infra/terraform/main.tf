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

# Web Server Security Group
resource "aws_security_group" "web_sg" {
  name        = "roi-web-sg"
  description = "Security group for ROI Web App"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "roi-web-sg"
    Environment = var.environment
  }
}

# Monitoring Server Security Group
resource "aws_security_group" "monitoring_sg" {
  name        = "roi-monitoring-sg"
  description = "Security group for ROI Monitoring Stack"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "roi-monitoring-sg"
    Environment = var.environment
  }
}

# Cross-Communication Rules (Preventing Circular Dependencies)
# Web -> Monitoring (Nginx proxying to Grafana/Prometheus/Alertmanager)
resource "aws_security_group_rule" "web_to_monitoring_3001" {
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.monitoring_sg.id
  source_security_group_id = aws_security_group.web_sg.id
  description              = "Allow Web SG to access Grafana"
}

resource "aws_security_group_rule" "web_to_monitoring_9090" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = aws_security_group.monitoring_sg.id
  source_security_group_id = aws_security_group.web_sg.id
  description              = "Allow Web SG to access Prometheus"
}

resource "aws_security_group_rule" "web_to_monitoring_9093" {
  type                     = "ingress"
  from_port                = 9093
  to_port                  = 9093
  protocol                 = "tcp"
  security_group_id        = aws_security_group.monitoring_sg.id
  source_security_group_id = aws_security_group.web_sg.id
  description              = "Allow Web SG to access Alertmanager"
}

# Monitoring -> Web (Prometheus scraping Node Exporter and cAdvisor)
resource "aws_security_group_rule" "monitoring_to_web_9100" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.monitoring_sg.id
  description              = "Allow Monitoring SG to scrape Node Exporter"
}

resource "aws_security_group_rule" "monitoring_to_web_8080" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.monitoring_sg.id
  description              = "Allow Monitoring SG to scrape cAdvisor"
}

# Web Server (Spot Instance)
resource "aws_spot_instance_request" "roi_web" {
  ami                            = data.aws_ami.ubuntu.id
  instance_type                  = var.instance_type
  key_name                       = var.key_pair_name
  wait_for_fulfillment           = true
  instance_interruption_behavior = "terminate"

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # User data script to install Docker and Docker Compose
  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update
              apt-get upgrade -y
              curl -fsSL https://get.docker.com -o get-docker.sh
              sh get-docker.sh
              apt-get install -y docker-compose-plugin
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              mkdir -p /home/ubuntu/app
              chown ubuntu:ubuntu /home/ubuntu/app
              echo "Waiting for code push..." > /home/ubuntu/app/STATUS.txt
              echo "Setup completed successfully" > /home/ubuntu/setup-complete.txt
              EOF

  tags = {
    Name        = "roi-web-server"
    Environment = var.environment
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

# Monitoring Server (Spot Instance)
resource "aws_spot_instance_request" "roi_monitoring" {
  ami                            = data.aws_ami.ubuntu.id
  instance_type                  = var.instance_type
  key_name                       = var.key_pair_name
  wait_for_fulfillment           = true
  instance_interruption_behavior = "terminate"

  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update
              apt-get upgrade -y
              curl -fsSL https://get.docker.com -o get-docker.sh
              sh get-docker.sh
              apt-get install -y docker-compose-plugin
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              mkdir -p /home/ubuntu/app
              chown ubuntu:ubuntu /home/ubuntu/app
              EOF

  tags = {
    Name        = "roi-monitoring-server"
    Environment = var.environment
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

# Elastic IP for stable public address (Web Server)
resource "aws_eip" "roi_eip" {
  domain = "vpc"

  tags = {
    Name        = "roi-platform-eip"
    Environment = var.environment
  }
}

resource "aws_eip_association" "roi_eip_assoc" {
  instance_id   = aws_spot_instance_request.roi_web.spot_instance_id
  allocation_id = aws_eip.roi_eip.id
}

# RDS Database (Free Tier db.t4g.micro)

resource "aws_security_group" "rds_sg" {
  name        = "roi-platform-rds-sg"
  description = "Allow MySQL traffic from EC2"

  # Allow only the EC2 instance to talk to the database on 3306
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
    description     = "Allow MySQL traffic from Web Server"
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
