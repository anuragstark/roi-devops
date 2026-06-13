# AWS Deployment Guide - ROI Investment Platform

Quick guide to deploy your ROI platform on AWS EC2 with Docker.

## Prerequisites

- AWS Account
- AWS CLI installed (optional but helpful)
- Terraform installed (`brew install terraform` on Mac)
- SSH key pair created in AWS

## Step 1: Create SSH Key Pair in AWS

1. Go to AWS Console → EC2 → Key Pairs
2. Click "Create key pair"
3. Name: `roi-platform-key`
4. Type: RSA
5. Format: `.pem`
6. Save the downloaded file to `~/.ssh/roi-platform-key.pem`
7. Set permissions: `chmod 400 ~/.ssh/roi-platform-key.pem`

## Step 2: Configure Terraform

```bash
cd infra/terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit variables (update your settings)
nano terraform.tfvars
```

Update `terraform.tfvars`:
```hcl
key_pair_name = "roi-platform-key"
aws_region    = "us-east-1"
github_repo   = "https://github.com/YOUR_USERNAME/roi"
```

## Step 3: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes (creates EC2 instance)
terraform apply
```

**Save the outputs!** You'll see:
- Public IP address
- Frontend URL
- Backend URL
- SSH command

## Step 4: Initial Server Setup

```bash
# SSH into your server (replace IP)
ssh -i ~/.ssh/roi-platform-key.pem ubuntu@YOUR_PUBLIC_IP

# Wait for Docker installation (check status)
cat /home/ubuntu/setup-complete.txt

# If Docker is installed, verify
docker --version
docker compose version

# Create app directory and clone repo
cd /home/ubuntu/app
git clone https://github.com/YOUR_USERNAME/roi.git .

# Create production environment file from template (root)
cp .env.production.example .env
nano .env
```

Copy content from `.env.production.example` (project root) and update:
- `APP_BASE_URL` / `APP_WEB_ORIGIN` (e.g., `https://your-domain.com`)
- `VITE_API_URL` (e.g., `https://api.your-domain.com/api`)
- `DATABASE_URL` (point to RDS or container DB)
- JWT secrets and admin credentials

## Step 5: Deploy Application

```bash
# Make deploy script executable
chmod +x infra/scripts/deploy.sh

# Run deployment
bash infra/scripts/deploy.sh
```

Wait for containers to start. You should see:
- ✅ MySQL container running
- ✅ Backend container running  
- ✅ Frontend container running

## Step 6: Access Your Application

Open in browser:
- **Frontend**: value from `APP_BASE_URL`
- **Backend API**: `${VITE_API_URL}/health` (or configured health endpoint)

Login with admin credentials from `.env` file.

## Step 7: Setup GitHub Actions (Auto-Deploy)

1. Go to GitHub → Your Repository → Settings → Secrets and variables → Actions

2. Add these secrets:
   - `EC2_HOST`: Your public IP address
   - `EC2_USER`: `ubuntu`
   - `EC2_SSH_KEY`: Content of your `.pem` file

3. Push to main branch - deployment happens automatically!

```bash
git add .
git commit -m "Deploy to AWS"
git push origin main
```

Check GitHub Actions tab to see deployment progress.

## Useful Commands

### On Your Local Machine
```bash
# SSH into server
ssh -i ~/.ssh/roi-platform-key.pem ubuntu@YOUR_IP

# Destroy infrastructure (when done testing)
cd infra/terraform
terraform destroy
```

### On EC2 Server
```bash
# View logs
docker compose logs -f

# Restart containers
docker compose restart

# Stop all
docker compose down

# Start all
docker compose up -d

# Check container status
docker compose ps

# Manual redeploy
cd /home/ubuntu/app
bash infra/scripts/deploy.sh
```

## Troubleshooting

### Can't connect to frontend
```bash
# Check if container is running
docker compose ps

# Check frontend logs
docker compose logs frontend

# Verify port is open
curl ${APP_BASE_URL:-http://localhost:3000}
```

### Backend API not responding
```bash
# Check backend logs
docker compose logs backend

# Check database connection
docker compose logs mysql

# Restart backend
docker compose restart backend
```

### Database connection errors
```bash
# Check MySQL is healthy
docker compose ps mysql

# Check MySQL logs
docker compose logs mysql

# Verify environment variables
cat .env
```

### GitHub Actions failing
1. Verify GitHub secrets are correct
2. Check EC2 security group allows SSH (port 22)
3. Verify SSH key has correct permissions on EC2

## Cost Optimization

This setup uses:
- **t3.micro** instance (~$7.50/month or FREE on free tier)
- **20 GB storage** (included)
- **Elastic IP** (FREE when attached)

**Total: $0-10/month**

To minimize costs:
- Stop instance when not in use: `terraform destroy`
- Use AWS Free Tier (12 months free for new accounts)

## Next Steps

- [ ] Setup domain name and point to EC2 IP
- [ ] Configure nginx reverse proxy for cleaner URLs
- [ ] Setup SSL certificate (Let's Encrypt)
- [ ] Configure automated backups for database
- [ ] Setup CloudWatch monitoring
- [ ] Configure auto-scaling (for production)

## Support

If you encounter issues:
1. Check container logs: `docker compose logs`
2. Verify `.env` file has correct values
3. Ensure ports 3000 and 5000 are open in security group
4. Check GitHub Actions logs for deployment errors
