# ROI Investment Platform - DevOps & Infrastructure

This repository contains the advanced Infrastructure as Code (IaC), CI/CD pipelines, container orchestration, and observability stack for the ROI Investment Platform. 

> **Note:** The core application source code (backend APIs, frontend UI) is kept in a separate private repository for security reasons. This repository serves as a showcase of the DevOps and Platform Engineering architecture used to host the platform securely, cost-effectively, and with zero downtime.

## 🏗 Architecture & DevOps Stack

* **Infrastructure as Code:** Terraform is used to provision all AWS resources (EC2, VPC, IAM, Security Groups, S3). We use an S3 remote state with DynamoDB locking.
* **Cost Optimization:** The architecture utilizes **Auto Scaling Groups** and **EC2 Spot Instances** (`t3.small`) for both the Web and Monitoring servers, achieving roughly 70% cost savings compared to On-Demand pricing.
* **CI/CD Automation:** GitHub Actions powers the entire lifecycle. Workflows handle Continuous Integration, Infrastructure Drift Detection, full deployments, and automated teardowns.
* **Deployment Strategy:** A fully automated **Blue/Green Deployment** strategy ensures zero-downtime updates. NGINX dynamically hot-swaps traffic to new Docker containers only after they successfully pass health checks.
* **Observability (PLG Stack):** A dedicated monitoring server runs Prometheus, Grafana, Loki, Tempo, and Alertmanager. All application logs and metrics are securely scraped across the AWS private network. Alertmanager is configured to send automated email alerts if system resources hit critical thresholds.
* **Secrets Management:** Mozilla SOPS with Age encryption is used. No plain-text `.env` files are stored in the repository.

## 📂 Repository Structure

* `.github/workflows/` - CI/CD pipeline definitions (Deploy, Drift Detection, Destroy, etc.).
* `infra/` - Terraform configurations, Auto Scaling Groups, and Security Groups.
* `monitoring/` - Configuration files for Prometheus, Grafana, Promtail, Alertmanager, and Loki.
* `docker-compose*.yml` - Container orchestration for application and infrastructure tiers.
* `nginx-proxy.conf` - Reverse proxy configuration handling the Blue/Green traffic routing and SSL termination.

## 🚀 Quick Links

- 📖 **[Detailed AWS Deployment Guide](infra/AWS_DEPLOYMENT.md)** - Step-by-step documentation on how the Auto Scaling architecture is deployed and how to use the GitHub Actions pipelines.
- 📖 **[Infrastructure Setup](infra/README.md)** - Overview of the Terraform architecture and cost breakdowns.

## 🔒 Security Highlights

- **Automated SSL/TLS**: The deployment pipeline automatically triggers `certbot` to issue and renew Let's Encrypt certificates for all domains (`paisatest.online`, `grafana.paisatest.online`, `prometheus.paisatest.online`).
- **Internal VPC Routing**: The Nginx reverse proxy dynamically fetches the Monitoring Server's Private IP, ensuring that metrics and dashboards are routed securely through the internal AWS network via strict Security Groups.
- **Encrypted State**: Terraform state files are encrypted at rest in S3, and environment variables are strictly decrypted at runtime during the CI/CD pipeline execution using SOPS.
