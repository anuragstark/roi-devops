# AWS Deployment Guide - ROI Investment Platform

This guide covers the advanced, automated deployment architecture for the ROI Platform on AWS. The infrastructure is entirely managed by Terraform and GitHub Actions, featuring a highly-available Blue/Green deployment strategy and comprehensive monitoring using Grafana and Prometheus.

## Architecture Overview

- **Web Server**: Runs the Next.js Frontend and Express Backend (via Docker Compose). Uses Blue/Green deployment for zero-downtime updates.
- **Monitoring Server**: Runs Prometheus, Loki, Tempo, Alertmanager, and Grafana.
- **Database**: AWS RDS MySQL instance (Free Tier eligible).
- **Cost Optimization**: Both the Web and Monitoring servers are deployed as **EC2 Spot Instances** within Auto Scaling Groups (ASGs). This provides ~70% cost savings compared to On-Demand instances.
- **Secrets Management**: Environment variables are encrypted using Mozilla SOPS and AWS KMS/Age, and stored safely inside the repository.

---

## Prerequisites

- AWS Account
- AWS CLI installed and configured
- Terraform installed (`brew install terraform` on Mac)
- SOPS & Age installed for managing encrypted secrets
- An SSH key pair named `roi-platform-key` created in AWS (save the `.pem` file to `~/.ssh/`)

---

## Step 1: Managing Encrypted Secrets (SOPS)

We do not store plain-text `.env` files. Instead, we use Mozilla SOPS to encrypt the `.env` file before committing it.

1. Ensure you have the `SOPS_AGE_KEY` secret.
2. Edit your environment variables:
   ```bash
   # Decrypt the file for editing
   sops -d .env.enc > .env
   
   # ... Edit .env file ...
   
   # Encrypt the file back to .env.enc
   sops -e .env > .env.enc
   ```
3. Commit the updated `.env.enc` to the repository.

---

## Step 2: Configure & Deploy Infrastructure (Terraform)

All AWS infrastructure is provisioned through Terraform.

1. **Navigate to the Terraform directory:**
   ```bash
   cd infra/terraform
   ```

2. **Initialize Terraform:**
   This project uses an **S3 backend** for state storage and a **DynamoDB table** for state locking.
   ```bash
   terraform init
   ```

3. **Configure Variables:**
   Ensure `terraform.tfvars` contains your specific configuration:
   ```hcl
   key_pair_name = "roi-platform-key"
   aws_region    = "us-east-1"
   # ... other variables ...
   ```
   *Note: Sensitive variables (like `db_password` and `gh_pat`) should be passed via environment variables (e.g., `TF_VAR_db_password`).*

4. **Deploy Infrastructure:**
   ```bash
   terraform apply
   ```
   *Terraform will automatically assign Elastic IPs and trigger the initial application deployment via GitHub Actions webhooks using your `gh_pat`.*

---

## Step 3: Application Deployment (GitHub Actions)

Once the infrastructure is up, application deployments are fully automated.

1. Push your code to the `main` branch.
2. The **"Terraform Apply & Blue/Green Deploy"** workflow will trigger.
3. **The Workflow will:**
   - Verify Terraform drift.
   - SSH into the Web Server.
   - Decrypt the `.env.enc` file using SOPS.
   - Run the Blue/Green deployment script.
   - Start the new Docker containers on a new port.
   - Update Nginx to point to the new containers seamlessly.
   - Configure Certbot to secure the connections with SSL.

### Accessing the Platform
After deployment, the following domains will be secured with HTTPS:
- **Frontend**: `https://paisatest.online`
- **Grafana Dashboard**: `https://grafana.paisatest.online`
- **Prometheus**: `https://prometheus.paisatest.online`

---

## Troubleshooting & Maintenance

### Spot Instance Replacements
Because we use Spot Instances to save costs, AWS might occasionally terminate an instance if capacity drops.
- Our **Auto Scaling Group** is configured to instantly spin up a replacement instance (`t3.small`).
- The `user_data` startup script automatically re-attaches the existing Elastic IP.
- The startup script then sends a webhook to GitHub Actions, which automatically redeploys your Docker containers without any manual intervention.

### Connecting to Servers
```bash
# Connect to the Web Server
ssh -i ~/.ssh/roi-platform-key.pem ubuntu@<WEB_PUBLIC_IP>

# Connect to the Monitoring Server
ssh -i ~/.ssh/roi-platform-key.pem ubuntu@<MONITORING_PUBLIC_IP>
```

### Checking Logs
On the Web Server:
```bash
cd /home/ubuntu/app
docker compose logs -f frontend
docker compose logs -f backend
```
*Note: All application logs are automatically shipped to Loki and can be viewed beautifully in the Grafana dashboard.*

---

## Destroying Infrastructure

When you are done testing, you can tear everything down to stop incurring costs.

1. Go to the **Actions** tab in GitHub.
2. Select the **3. Destroy Infrastructure** workflow.
3. Click **Run workflow**.

**IMPORTANT:** Destroying the infrastructure will release your Elastic IPs back to AWS. The next time you deploy, AWS will assign you **new** public IPs. You MUST update your DNS provider (e.g., Hostinger) with the new IPs before the Certbot step runs, otherwise SSL generation will fail!
