# ROI Platform Infrastructure

Infrastructure as Code (IaC) for deploying the ROI Investment Platform on AWS. This repository manages the AWS resources and CI/CD pipelines required to run a highly available, cost-optimized environment.

## Architecture Highlights

- **Terraform (AWS)**: Provisions the entire infrastructure, utilizing an S3 backend for state storage and DynamoDB for state locking.
- **Spot Instances & Auto Scaling**: Uses `t3.small` Spot Instances within Auto Scaling Groups to provide ~70% cost savings. If AWS reclaims an instance, a new one is automatically spun up and configured.
- **Blue/Green Deployments**: Zero-downtime deployments via GitHub Actions (`deploy.yml`). New containers are spun up and verified before Nginx routes traffic to them.
- **Monitoring Stack**: A dedicated server runs Prometheus, Loki, Tempo, Alertmanager, and Grafana. It scrapes metrics from the Web Server entirely within the AWS private network.
- **Secrets Management**: Environment variables are encrypted securely in the repository using Mozilla SOPS and AWS KMS/Age.

## Directory Structure

```
infra/
├── terraform/              # Terraform configuration
│   ├── main.tf             # Main infrastructure (ASGs, Security Groups, EC2)
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values (IPs, URLs)
│   └── s3.tf               # Upload buckets and CORS rules
├── AWS_DEPLOYMENT.md       # Detailed deployment guide
└── README.md               # This file
```

## Quick Start

### 1. Prerequisites
- AWS CLI configured
- Terraform installed
- Mozilla SOPS and Age installed
- SSH Key Pair (`roi-platform-key.pem`) saved to `~/.ssh/`

### 2. Infrastructure Deployment
All infrastructure is provisioned through Terraform.

```bash
cd terraform
terraform init
terraform apply
```

### 3. Application Deployment
Application deployments are handled automatically by **GitHub Actions**.
Simply push your code to the `main` branch, and the workflow will:
1. Detect any Terraform drift.
2. SSH into the servers.
3. Perform a Blue/Green Docker deployment.
4. Issue Let's Encrypt SSL certificates automatically.

## Documentation

For a comprehensive breakdown of the deployment process, Secrets Management, and Troubleshooting, please refer to the [AWS Deployment Guide](./AWS_DEPLOYMENT.md).

## Cost Estimate

By utilizing Spot Instances, we've optimized the infrastructure to be incredibly cost-effective:

- **Web Server (Spot `t3.small`)**: ~$0.0063/hr
- **Monitoring Server (Spot `t3.small`)**: ~$0.0063/hr
- **RDS MySQL**: FREE (on AWS Free Tier) or ~$12/month
- **Elastic IPs**: ~$7/month (AWS flat fee for public IPv4)
- **Total Estimated Cost**: **~$20 - $35 per month**

## Clean Up

When you are finished testing, use the **3. Destroy Infrastructure** GitHub Action to safely tear down the entire environment and stop incurring costs.
