terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "roi-platform-tf-state-974387"
    key          = "ec2/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
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
  cidr_blocks              = ["${aws_eip.roi_eip.public_ip}/32"]
  description              = "Allow Web EIP to access Grafana"
}

resource "aws_security_group_rule" "web_to_monitoring_9090" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = aws_security_group.monitoring_sg.id
  cidr_blocks              = ["${aws_eip.roi_eip.public_ip}/32"]
  description              = "Allow Web EIP to access Prometheus"
}

resource "aws_security_group_rule" "web_to_monitoring_9093" {
  type                     = "ingress"
  from_port                = 9093
  to_port                  = 9093
  protocol                 = "tcp"
  security_group_id        = aws_security_group.monitoring_sg.id
  cidr_blocks              = ["${aws_eip.roi_eip.public_ip}/32"]
  description              = "Allow Web EIP to access Alertmanager"
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

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

# IAM Role for EC2 to associate Elastic IP
resource "aws_iam_role" "ec2_eip_role" {
  name = "roi-ec2-eip-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_eip_policy" {
  name        = "roi-ec2-eip-policy"
  description = "Allows EC2 instances to associate Elastic IPs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses",
          "ec2:DescribeInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_eip_attach" {
  role       = aws_iam_role.ec2_eip_role.name
  policy_arn = aws_iam_policy.ec2_eip_policy.arn
}

resource "aws_iam_instance_profile" "ec2_eip_profile" {
  name = "roi-ec2-eip-profile"
  role = aws_iam_role.ec2_eip_role.name
}

# Elastic IP for Web Server
resource "aws_eip" "roi_eip" {
  domain = "vpc"
  tags = {
    Name        = "roi-web-eip"
    Environment = var.environment
  }
}

# Elastic IP for Monitoring Server
resource "aws_eip" "monitoring_eip" {
  domain = "vpc"
  tags = {
    Name        = "roi-monitoring-eip"
    Environment = var.environment
  }
}

# Web Server Launch Template
resource "aws_launch_template" "web_lt" {
  name_prefix   = "roi-web-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_eip_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              export DEBIAN_FRONTEND=noninteractive
              
              # ── STEP 1: Attach Elastic IP FIRST (so SSH is reachable fast) ──
              apt-get update -qq
              apt-get install -y -qq unzip curl
              curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip -q awscliv2.zip
              ./aws/install
              
              TOKEN=$(curl -s --retry 3 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s --retry 3 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              
              # Retry EIP association up to 5 times
              for i in 1 2 3 4 5; do
                aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${aws_eip.roi_eip.id} --region ${var.aws_region} && break
                echo "EIP association attempt $i failed, retrying in 5s..."
                sleep 5
              done
              
              sleep 5
              
              # ── STEP 2: Install Docker ──
              curl -fsSL https://get.docker.com -o get-docker.sh
              sh get-docker.sh
              apt-get install -y docker-compose-plugin jq
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              mkdir -p /home/ubuntu/app
              chown ubuntu:ubuntu /home/ubuntu/app
              
              # ── STEP 3: Trigger GitHub Actions to deploy code ──
              curl -s -L -X POST \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer ${var.gh_pat}" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                https://api.github.com/repos/anuragstark/roi-devops/actions/workflows/deploy.yml/dispatches \
                -d '{"ref":"main"}' || true
              
              echo "Setup completed" > /home/ubuntu/setup-complete.txt
              EOF
  )

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "roi-web-server"
      Environment = var.environment
    }
  }
}

# Web Server Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name                = "roi-web-asg"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = data.aws_subnets.default.ids

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.web_lt.id
        version            = "$Latest"
      }
      override {
        instance_type = "t3.small"
      }
      override {
        instance_type = "t3a.small"
      }
    }
  }


  tag {
    key                 = "Name"
    value               = "roi-web-server"
    propagate_at_launch = true
  }
}

# Monitoring Server Launch Template
resource "aws_launch_template" "monitoring_lt" {
  name_prefix   = "roi-monitoring-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_eip_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.monitoring_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              export DEBIAN_FRONTEND=noninteractive
              
              # ── STEP 1: Attach Elastic IP FIRST (so SSH is reachable fast) ──
              apt-get update -qq
              apt-get install -y -qq unzip curl
              curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip -q awscliv2.zip
              ./aws/install
              
              TOKEN=$(curl -s --retry 3 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s --retry 3 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              
              for i in 1 2 3 4 5; do
                aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${aws_eip.monitoring_eip.id} --region ${var.aws_region} && break
                echo "EIP association attempt $i failed, retrying in 5s..."
                sleep 5
              done
              
              sleep 5
              
              # ── STEP 2: Install Docker ──
              curl -fsSL https://get.docker.com -o get-docker.sh
              sh get-docker.sh
              apt-get install -y docker-compose-plugin jq
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              mkdir -p /home/ubuntu/app
              chown ubuntu:ubuntu /home/ubuntu/app
              
              # ── STEP 3: Trigger GitHub Actions to deploy code ──
              curl -s -L -X POST \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer ${var.gh_pat}" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                https://api.github.com/repos/anuragstark/roi-devops/actions/workflows/deploy.yml/dispatches \
                -d '{"ref":"main"}' || true
              
              echo "Setup completed" > /home/ubuntu/setup-complete.txt
              EOF
  )

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "roi-monitoring-server"
      Environment = var.environment
    }
  }
}

# Monitoring Server Auto Scaling Group
resource "aws_autoscaling_group" "monitoring_asg" {
  name                = "roi-monitoring-asg"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = data.aws_subnets.default.ids

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.monitoring_lt.id
        version            = "$Latest"
      }
      override {
        instance_type = "t3.small"
      }
      override {
        instance_type = "t3a.small"
      }
    }
  }


  tag {
    key                 = "Name"
    value               = "roi-monitoring-server"
    propagate_at_launch = true
  }
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
