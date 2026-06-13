# ROI Platform Infrastructure

Infrastructure as Code (IaC) for deploying the ROI Investment Platform on AWS.

## Quick Start

### Deploy to AWS (Recommended for Testing)

1. **Install Terraform**
   ```bash
   brew install terraform  # Mac
   # or download from https://www.terraform.io/downloads
   ```

2. **Create AWS Key Pair**
   - AWS Console → EC2 → Key Pairs → Create
   - Name: `roi-platform-key`
   - Save `.pem` file to `~/.ssh/`

3. **Configure & Deploy**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   terraform init
   terraform apply
   ```

4. **Setup Application**
   - SSH into EC2: `ssh -i ~/.ssh/roi-platform-key.pem ubuntu@YOUR_IP`
   - Clone repo: `git clone <your-repo> /home/ubuntu/app`
   - Create `.env` from project root `.env.production.example` (set APP_BASE_URL/APP_WEB_ORIGIN/VITE_API_URL/DATABASE_URL/JWT secrets)
   - Deploy: `bash infra/scripts/deploy.sh`

5. **Access Application**
- Frontend: `${APP_BASE_URL}`
- Backend: `${VITE_API_URL}`

📖 **Full Guide**: See [AWS_DEPLOYMENT.md](./AWS_DEPLOYMENT.md)

## Infrastructure Components

### Terraform (AWS)
- **EC2 Instance**: t3.micro (Free Tier eligible)
- **Security Group**: Ports 22, 80, 443, 3000, 5000
- **Elastic IP**: Static public IP address
- **Auto-setup**: Docker installation via user data

### Docker Containers
- **MySQL**: Database (port 3306)
- **Backend**: Node.js API (port 5000)
- **Frontend**: React app (port 3000)

### CI/CD
- **GitHub Actions**: Auto-deploy on push to main
- **Workflow**: `.github/workflows/deploy-to-aws.yml`

## Directory Structure

```
infra/
├── terraform/              # Terraform configuration
│   ├── main.tf            # Main infrastructure
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   └── terraform.tfvars.example
├── scripts/               # Deployment scripts
│   └── deploy.sh         # Auto-deployment script
├── AWS_DEPLOYMENT.md      # Detailed guide
└── README.md             # This file
```

## Cost Estimate

**Monthly Cost**: $0 - $10

- t3.micro instance: **FREE** (1st year) or ~$7.50/month
- 20 GB storage: **FREE** (included in free tier)
- Elastic IP: **FREE** (when attached)
- Data transfer: **FREE** (1 GB/month)

## GitHub Actions Setup

Add these secrets to your GitHub repository (Settings → Secrets):

| Secret | Value |
|--------|-------|
| `EC2_HOST` | Your EC2 public IP |
| `EC2_USER` | `ubuntu` |
| `EC2_SSH_KEY` | Content of your `.pem` file |

Then push to main branch - automatic deployment! 🚀

## Useful Commands

```bash
# Deploy infrastructure
cd terraform && terraform apply

# Check deployment status
ssh ubuntu@YOUR_IP 'docker compose ps'

# View application logs
ssh ubuntu@YOUR_IP 'cd /home/ubuntu/app && docker compose logs -f'

# Manual deployment
ssh ubuntu@YOUR_IP 'cd /home/ubuntu/app && bash infra/scripts/deploy.sh'

# Destroy infrastructure
cd terraform && terraform destroy
```

## Support

- 📖 [AWS Deployment Guide](./AWS_DEPLOYMENT.md)
- 🐛 Check logs: `docker compose logs`
- 💬 GitHub Issues

## Next Steps

- [ ] Setup custom domain
- [ ] Configure SSL/HTTPS
- [ ] Setup database backups
- [ ] Configure monitoring
- [ ] Setup staging environment
