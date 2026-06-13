# ROI Investment Platform - DevOps & Infrastructure

This repository contains the infrastructure as code (IaC), CI/CD pipelines, container orchestration, and observability stack for the ROI Investment Platform. 

> **Note:** The core application source code (backend APIs, frontend UI, smart contracts) is kept in a separate private repository for security reasons. This repository showcases the DevOps and Platform Engineering work.

## 🏗 Architecture & DevOps Stack

* **Infrastructure as Code:** Terraform (AWS EC2, VPC, IAM, RDS, S3) with S3 remote state and DynamoDB locking.
* **CI/CD:** GitHub Actions (4 workflows: CI, Deployment, Drift Detection, Teardown).
* **Containerization:** Docker & Docker Compose (Multi-stage builds).
* **Deployment Strategy:** Blue/Green Zero-Downtime Deployment with NGINX hot-swapping.
* **Observability (PLG Stack):** Prometheus, Grafana, Loki, Tempo, and OpenTelemetry distributed tracing.
* **Secrets Management:** Mozilla SOPS with age encryption.

## 📂 Repository Structure

* `.github/workflows/` - CI/CD pipeline definitions.
* `infra/` - Terraform modules and configurations.
* `monitoring/` - Configuration for Prometheus, Grafana, Promtail, and Loki.
* `docker-compose*.yml` - Container orchestration for app and infra tiers.
* `nginx-proxy.conf` - Reverse proxy config handling the Blue/Green traffic routing.
* `Makefile` - Automation shortcuts for deployment and monitoring.
