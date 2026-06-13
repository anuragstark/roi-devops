# ROI Platform — Infrastructure & DevOps Plan

> **Author**: Anurag Stark
> **Project**: ROI Investment Platform
> **Budget**: $30–40/month (AWS Free Tier eligible)
> **Strategy**: Maximize DevOps tools & AWS services for resume. Use different tools than TeleDoc project to show breadth.

---

## Table of Contents

- [Current State](#current-state)
- [Target Architecture](#target-architecture)
- [AWS Free Tier Notes](#aws-free-tier-notes)
- [Directory Structure](#directory-structure)
- [Phase 1: Foundation (Already Done)](#phase-1-foundation-already-done)
- [Phase 2: Developer Workflow & Code Quality](#phase-2-developer-workflow--code-quality)
- [Phase 3: Container Best Practices](#phase-3-container-best-practices)
- [Phase 4: Advanced Monitoring & Alerting](#phase-4-advanced-monitoring--alerting)
- [Phase 5: Security Hardening](#phase-5-security-hardening)
- [Phase 6: AWS-Native Services](#phase-6-aws-native-services)
- [Phase 7: Serverless & Caching](#phase-7-serverless--caching)
- [Phase 8: Observability (Distributed Tracing)](#phase-8-observability-distributed-tracing)
- [Phase 9: Terraform Maturity](#phase-9-terraform-maturity)
- [Phase 10: Documentation & Architecture](#phase-10-documentation--architecture)
- [Cost Breakdown](#cost-breakdown)
- [Resume Coverage — ROI vs TeleDoc](#resume-coverage--roi-vs-teledoc)
- [Implementation Timeline](#implementation-timeline)

---

## Current State

### Infrastructure (All Working ✅)

| Component | Detail |
|---|---|
| **Compute** | EC2 t3.small, Elastic IP `3.222.210.129` |
| **Database** | RDS MySQL 8.0 (db.t4g.micro), private, not publicly accessible |
| **State** | S3 bucket `roi-platform-tf-state-974387` + DynamoDB lock table |
| **Domain** | `paisatest.online` → A record → Elastic IP |
| **SSL** | Let's Encrypt / Certbot, auto-renew, expires 2026-07-29 |
| **Reverse Proxy** | Nginx on EC2, SSL termination, proxy to Docker containers |
| **Containers** | Docker Compose: backend, frontend, roi-cron |
| **Deployment** | Blue/Green via Nginx port swap (zero-downtime) |
| **CI/CD** | GitHub Actions: `terraform-deploy.yml`, `backend-ci.yml`, `terraform-destroy.yml` |
| **Monitoring** | Prometheus, Grafana, Node Exporter |
| **Logging** | Loki + Promtail (centralized container logs) |
| **Security Scanning** | Trivy (repo scan), tfsec (IaC scan), tflint (linter) |
| **Backups** | Automated MySQL dump → S3 via Docker cron container |

### Terraform Structure

```
infra/
├── terraform/
│   ├── main.tf                 ← Provider, backend (S3 + DynamoDB locking)
│   ├── s3.tf                   ← Uploads bucket, DynamoDB lock table, lifecycle policies
│   ├── iam.tf                  ← IAM policy for backend S3 access
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── backup/                     ← DB backup Docker container
│   ├── Dockerfile
│   └── backup.sh
└── scripts/
    ├── deploy.sh
    └── push-to-ec2.sh
```

> **NOTE**: S3 state bucket (`roi-platform-tf-state-974387`) was created manually. The DynamoDB lock table, uploads bucket, and IAM policies are all managed in the main Terraform config.

---

## Target Architecture

```
                    ┌─────────────────┐
                    │   CloudFront    │  ← CDN (static assets)
                    │   + WAF         │  ← Web Application Firewall
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  paisatest.online│
                    │     (DNS)       │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Nginx (EC2)    │  ← SSL termination, rate limiting
                    │  + Certbot      │     security headers
                    └───┬─────────┬───┘
                        │         │
               ┌────────▼──┐  ┌──▼────────┐
               │ Frontend   │  │ Backend   │  ← Docker containers
               │ (Vite+React│  │(Express+  │
               │  port 3000)│  │ Prisma)   │
               └────────────┘  │ port 5000 │
                               └─────┬─────┘
                                     │
                    ┌────────────┬────┴──────────┐
                    │            │               │
              ┌─────▼──┐  ┌─────▼──┐  ┌─────────▼──────┐
              │  RDS    │  │ Redis  │  │ S3 (uploads +  │
              │ MySQL   │  │(Docker)│  │  backups)      │
              └─────────┘  └────────┘  └────────────────┘

        ┌──────────── Monitoring Stack ────────────┐
        │ Prometheus │ Grafana │ Loki │ Promtail   │
        │ Alertmanager │ Node Exporter │ Tempo     │
        └──────────────────────────────────────────┘

        ┌──────────── Serverless ──────────────────┐
        │ Lambda (ROI cron) ← EventBridge Schedule │
        └──────────────────────────────────────────┘

        ┌──────────── CI/CD Pipeline ──────────────┐
        │ GitHub Actions → Build → Trivy Scan →    │
        │ SonarCloud → Push GHCR → Deploy EC2      │
        │ (Blue/Green) → Health Check → Rollback   │
        └──────────────────────────────────────────┘
```

---

## AWS Free Tier Notes

> **Yes, RDS is free for 12 months on a new AWS account:**

| Service | Free Tier | Your Usage | Free? |
|---|---|---|---|
| **RDS** (db.t4g.micro) | 750 hrs/month for 12 months | 1 instance, 24/7 | ✅ YES (first 12 months) |
| **EC2** (t3.small) | t2.micro/t3.micro only | t3.small | ❌ NO (~$15/month) |
| **S3** | 5GB, 20K GET, 2K PUT | ~1GB | ✅ YES |
| **CloudFront** | 1TB transfer/month for 12 months | ~10GB | ✅ YES |
| **Lambda** | 1M requests/month | ~720 invocations/month | ✅ YES |
| **CloudWatch** | 10 alarms, 10 metrics free | 10 alarms | ✅ YES |
| **Secrets Manager** | 30-day free trial only | 5 secrets | ❌ ~$2/month |
| **DynamoDB** | 25GB + 25 WCU/RCU | Lock table only | ✅ YES |
| **WAF** | No free tier | Basic rules | ❌ ~$5/month |
| **Elastic IP** | Free when attached to running instance | 1 EIP | ✅ YES (when EC2 runs) |

> **If your AWS account is < 12 months old, RDS is free. Your main cost is EC2 (~$15).**

---

## Directory Structure (Target)

```
roi/
├── .github/
│   ├── workflows/
│   │   ├── terraform-deploy.yml      ← Main CI/CD pipeline
│   │   ├── terraform-destroy.yml     ← Manual infra teardown
│   │   ├── backend-ci.yml            ← Lint + test on PR
│   │   ├── drift-detection.yml       ← [NEW] Weekly terraform plan
│   │   └── dependabot.yml            ← [NEW] Auto dependency updates
│   └── CODEOWNERS                    ← [NEW] PR review rules
│
├── backend/
│   ├── Dockerfile                    ← [UPDATE] Multi-stage build
│   ├── .dockerignore
│   ├── src/
│   │   ├── middleware/
│   │   │   └── helmet.ts             ← [NEW] Security headers
│   │   ├── lib/
│   │   │   ├── logger.ts             ← [NEW] Pino structured JSON logger
│   │   │   └── redis.ts              ← [NEW] Redis client
│   │   └── tracing.ts                ← [NEW] OpenTelemetry setup
│   └── package.json                  ← [UPDATE] Add pino, helmet, ioredis, @opentelemetry/*
│
├── frontend/
│   ├── Dockerfile                    ← [UPDATE] Multi-stage build
│   └── nginx.conf                    ← [UPDATE] Security headers
│
├── infra/
│   │
│   ├── terraform/
│   │   ├── main.tf                   ← Provider + backend (S3 + DynamoDB)
│   │   ├── s3.tf                     ← Uploads bucket, DynamoDB locks, lifecycle
│   │   ├── iam.tf                    ← IAM policy for S3 access
│   │   ├── modules/                  ← [NEW] Modular Terraform
│   │   │   ├── compute/              ← EC2 + EIP + Security Group
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── outputs.tf
│   │   │   ├── database/             ← RDS + Security Group
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── outputs.tf
│   │   │   ├── monitoring/           ← CloudWatch Alarms
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── outputs.tf
│   │   │   ├── cdn/                  ← CloudFront distribution
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── outputs.tf
│   │   │   ├── security/             ← WAF, Secrets Manager
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   └── outputs.tf
│   │   │   └── serverless/           ← Lambda + EventBridge
│   │   │       ├── main.tf
│   │   │       ├── variables.tf
│   │   │       └── outputs.tf
│   │   ├── envs/                     ← [NEW] Per-environment configs
│   │   │   ├── prod.tfvars
│   │   │   └── dev.tfvars
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── backup/
│   │   ├── Dockerfile
│   │   └── backup.sh
│   │
│   └── lambda/                       ← [NEW] Lambda function code
│       └── roi-cron/
│           ├── index.ts
│           └── package.json
│
├── monitoring/
│   ├── prometheus.yml
│   ├── alertmanager.yml              ← [NEW] Alert rules + Discord/Slack
│   ├── alert-rules.yml               ← [NEW] Prometheus alert rules
│   ├── loki-config.yml
│   ├── promtail-config.yml
│   ├── tempo-config.yml              ← [NEW] Distributed tracing
│   └── grafana/
│       ├── provisioning/
│       └── dashboards/
│           ├── infrastructure.json   ← [NEW] CPU, Memory, Disk
│           └── business-kpis.json    ← [NEW] Active users, ROI generated
│
├── docker-compose.yml                ← App services (backend, frontend, roi-cron)
├── docker-compose.infra.yml          ← [UPDATE] Add Alertmanager, Tempo, Redis
├── docker-compose.dev.yml            ← Local dev environment
├── nginx-proxy.conf                  ← [UPDATE] Rate limiting + security headers
├── Makefile                          ← [NEW] Developer workflow automation
├── .sops.yaml                        ← [NEW] SOPS encryption config
├── .husky/                           ← [NEW] Pre-commit hooks
│   └── pre-commit
└── docs/
    ├── INFRASTRUCTURE_PLAN.md        ← This file
    ├── ADR/                          ← [NEW] Architecture Decision Records
    │   ├── 001-blue-green-over-rolling.md
    │   ├── 002-loki-over-cloudwatch.md
    │   ├── 003-sops-over-ssm.md
    │   └── 004-lambda-cron-migration.md
    └── ...
```

---

## Phase 1: Foundation (Already Done ✅)

**Status**: Complete. No action needed.

| Tool | What | Resume Keyword |
|---|---|---|
| Terraform | IaC — EC2, RDS, S3, EIP, Security Groups | Terraform, IaC |
| Docker + Compose | Multi-container app (backend, frontend, cron, monitoring) | Docker, Docker Compose |
| GitHub Actions | CI/CD — 4 workflows (deploy, destroy, CI, legacy) | CI/CD, GitHub Actions |
| Blue/Green Deploy | Zero-downtime via Nginx port swap + health check + auto-rollback | Blue/Green, Zero Downtime |
| Nginx | Reverse proxy, SSL termination | Nginx |
| Certbot | Let's Encrypt auto-renewal HTTPS | SSL/TLS, HTTPS |
| Prometheus | Metrics collection (backend + node exporter) | Prometheus |
| Grafana | Dashboards and visualization | Grafana |
| Loki + Promtail | Centralized container log aggregation | Loki, Centralized Logging |
| Trivy | Vulnerability scanning in CI | Trivy, DevSecOps |
| tfsec | Terraform security scanning | tfsec, IaC Security |
| tflint | Terraform linting | tflint |
| DB Backup → S3 | Automated MySQL dump cron container | Disaster Recovery |
| S3 Remote State | Terraform state in S3 with lock | Remote State |

---

## Phase 2: Developer Workflow & Code Quality

**Cost**: FREE | **Effort**: ~1.5 hours

### 2.1 — Dependabot (Auto Dependency Updates)

Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/backend"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
  - package-ecosystem: "npm"
    directory: "/frontend"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "docker"
    directory: "/backend"
    schedule:
      interval: "monthly"
```
**Resume line**: *"Automated dependency management with Dependabot for 4 ecosystems"*

### 2.2 — GitHub Branch Protection

Settings → Branches → Add rule for `main`:
- ✅ Require PR before merging
- ✅ Require status checks (backend-ci)
- ✅ Require conversation resolution
- ❌ No direct push to main

**Resume line**: *"Enforced branch protection with required CI checks before merge"*

### 2.3 — Pre-commit Hooks (Husky + lint-staged)

```bash
npx husky init
npm install --save-dev lint-staged
```

`.husky/pre-commit`:
```bash
npx lint-staged
```

`package.json`:
```json
{
  "lint-staged": {
    "backend/src/**/*.ts": ["eslint --fix", "prettier --write"],
    "frontend/src/**/*.{ts,tsx}": ["eslint --fix", "prettier --write"]
  }
}
```
**Resume line**: *"Shift-left quality enforcement with pre-commit hooks (Husky + lint-staged)"*

### 2.4 — Makefile

```makefile
.PHONY: dev deploy logs backup test lint clean

dev:                    ## Start local development
	docker compose -f docker-compose.dev.yml up --build

deploy:                 ## Deploy to production
	git push origin main

logs:                   ## View production logs
	ssh ubuntu@3.222.210.129 'docker logs roi_backend --tail 100 -f'

backup:                 ## Trigger manual DB backup
	ssh ubuntu@3.222.210.129 'docker exec roi_db_backup /backup.sh'

test:                   ## Run backend tests
	cd backend && npm test

lint:                   ## Lint all code
	cd backend && npm run lint
	cd frontend && npm run lint

infra-plan:             ## Preview Terraform changes
	cd infra/terraform && terraform plan

infra-apply:            ## Apply Terraform changes
	cd infra/terraform && terraform apply

clean:                  ## Clean Docker artifacts
	docker system prune -af
```
**Resume line**: *"Standardized developer workflow with Makefile automation"*

### 2.5 — SonarCloud (Code Quality Analysis)

Add to `backend-ci.yml`:
```yaml
- name: SonarCloud Scan
  uses: SonarSource/sonarcloud-github-action@master
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```
**Resume line**: *"Static code analysis with SonarCloud for code quality and tech debt tracking"*

---

## Phase 3: Container Best Practices

**Cost**: FREE | **Effort**: ~45 min

### 3.1 — Multi-Stage Docker Builds

`backend/Dockerfile` (optimized):
```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && cp -R node_modules /tmp/node_modules
RUN npm ci
COPY . .
RUN npx prisma generate
RUN npm run build

# Stage 2: Production
FROM node:20-alpine AS production
WORKDIR /app
RUN apk add --no-cache curl
COPY --from=builder /tmp/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package.json ./
COPY docker-entrypoint.sh ./

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

EXPOSE 5000
CMD ["sh", "-c", "chmod +x docker-entrypoint.sh && ./docker-entrypoint.sh"]
```

**Result**: Image size drops from ~1GB to ~200MB.

**Resume line**: *"Multi-stage Docker builds reducing image size by 70%, with integrated health checks"*

### 3.2 — Container Log Rotation

Add to EC2 Docker daemon config (`/etc/docker/daemon.json`):
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```
**Resume line**: *"Container log rotation to prevent disk exhaustion in production"*

---

## Phase 4: Advanced Monitoring & Alerting

**Cost**: FREE | **Effort**: ~1.5 hours

### 4.1 — Prometheus Alertmanager

Add to `docker-compose.infra.yml`:
```yaml
alertmanager:
  image: prom/alertmanager:v0.27.0
  container_name: roi_alertmanager
  restart: unless-stopped
  volumes:
    - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
  ports:
    - "9093:9093"
  networks:
    - roi_network
```

`monitoring/alertmanager.yml`:
```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'discord'
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: 'discord'
    webhook_configs:
      - url: '<DISCORD_WEBHOOK_URL>'
        send_resolved: true
```

`monitoring/alert-rules.yml`:
```yaml
groups:
  - name: infrastructure
    rules:
      - alert: HighCpuUsage
        expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU usage above 80% for 5 minutes"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning

      - alert: DiskSpaceRunningLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: critical

      - alert: BackendDown
        expr: up{job="roi-backend"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ROI Backend is DOWN"
```

**Resume line**: *"Proactive alerting with Prometheus Alertmanager — CPU, memory, disk, and service health alerts to Discord"*

### 4.2 — Structured JSON Logging (Pino)

Install in backend:
```bash
npm install pino pino-pretty
```

`backend/src/lib/logger.ts`:
```typescript
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  ...(process.env.NODE_ENV !== 'production' && {
    transport: { target: 'pino-pretty' },
  }),
});
```

**Resume line**: *"Structured JSON logging with Pino, correlation IDs, and Loki/Grafana integration"*

### 4.3 — Grafana Business KPI Dashboard

Create `monitoring/grafana/dashboards/business-kpis.json` with panels for:
- Active Users (from backend `/api/metrics`)
- Total ROI Generated
- Active Investments Count
- Server Uptime (from Prometheus)
- API Response Time p95/p99

**Resume line**: *"Custom Grafana dashboards for infrastructure metrics AND business KPIs"*

---

## Phase 5: Security Hardening

**Cost**: FREE | **Effort**: ~1 hour

### 5.1 — Nginx Rate Limiting

Add to `nginx-proxy.conf`:
```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth:10m rate=3r/s;

server {
    # ... existing config ...

    # Rate limit API endpoints
    location /api/auth/ {
        limit_req zone=auth burst=5 nodelay;
        proxy_pass http://127.0.0.1:5000;
    }

    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:5000;
    }
}
```
**Resume line**: *"API rate limiting with Nginx (10 req/s general, 3 req/s auth) for DDoS protection"*

### 5.2 — Security Headers (helmet.js)

`backend/src/middleware/helmet.ts`:
```typescript
import helmet from 'helmet';

export const securityHeaders = helmet({
  contentSecurityPolicy: true,
  crossOriginEmbedderPolicy: true,
  crossOriginOpenerPolicy: true,
  crossOriginResourcePolicy: true,
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
});
```
**Resume line**: *"OWASP security headers (CSP, HSTS, X-Frame-Options) with helmet.js"*

### 5.3 — SOPS (Encrypted Secrets in Git)

```bash
brew install sops age
age-keygen -o key.txt  # Store this securely

# Encrypt
sops --encrypt --age $(cat key.txt | grep public | awk '{print $4}') .env > .env.enc

# Decrypt in CI
sops --decrypt .env.enc > .env
```

`.sops.yaml`:
```yaml
creation_rules:
  - path_regex: \.env\.enc$
    age: 'age1xxxxxxxxx'
```
**Resume line**: *"Secrets management with SOPS + age encryption (commit encrypted secrets safely to Git)"*

---

## Phase 6: AWS-Native Services

**Cost**: ~$7/month | **Effort**: ~3 hours

### 6.1 — AWS CloudWatch Alarms (via Terraform)

Add `modules/monitoring/main.tf`:
```hcl
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "roi-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU > 80% for 10 minutes"
  dimensions = { InstanceId = var.ec2_instance_id }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "roi-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "RDS connections > 50"
  dimensions = { DBInstanceIdentifier = var.rds_instance_id }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "roi-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 3000000000  # 3GB
  alarm_description   = "RDS free storage < 3GB"
  dimensions = { DBInstanceIdentifier = var.rds_instance_id }
}
```
**Cost**: FREE (first 10 alarms) | **Resume line**: *"AWS CloudWatch alarms for EC2 CPU, RDS connections, and storage monitoring"*

### 6.2 — AWS CloudFront (CDN)

Add `modules/cdn/main.tf`:
```hcl
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["paisatest.online"]

  origin {
    domain_name = var.ec2_public_ip
    origin_id   = "roi-ec2-origin"

    custom_origin_config {
      http_port              = 3000
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "roi-ec2-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```
**Cost**: FREE (1TB/month, 12 months) | **Resume line**: *"AWS CloudFront CDN with edge caching and HTTPS enforcement"*

### 6.3 — AWS Secrets Manager

Add `modules/security/main.tf`:
```hcl
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "roi-platform/db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.rds_endpoint
    dbname   = "roi_platform"
  })
}

resource "aws_secretsmanager_secret" "jwt_secrets" {
  name = "roi-platform/jwt-secrets"
}
```
**Cost**: ~$2/month | **Resume line**: *"AWS Secrets Manager for runtime secret injection (different from TeleDoc's SSM approach)"*

### 6.4 — AWS WAF (Optional — drop if over budget)

```hcl
resource "aws_wafv2_web_acl" "roi_waf" {
  name  = "roi-platform-waf"
  scope = "CLOUDFRONT"

  default_action { allow {} }

  rule {
    name     = "rate-limit"
    priority = 1
    action { block {} }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "roi-rate-limit"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "roi-waf"
  }
}
```
**Cost**: ~$5/month | **Resume line**: *"AWS WAF with IP-based rate limiting for application-layer DDoS protection"*

### 6.5 — S3 Lifecycle Policies (Cost Optimization)

Already in `infra/terraform/s3.tf` ✅ — uploads transition to Standard-IA at 90 days, Glacier at 365 days.

Add backup lifecycle:
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"
    filter { prefix = "backups/" }

    expiration {
      days = 30
    }
  }
}
```
**Resume line**: *"S3 lifecycle policies for cost optimization — tiered storage (Standard → IA → Glacier)"*

---

## Phase 7: Serverless & Caching

**Cost**: ~$0.10/month | **Effort**: ~2 hours

### 7.1 — Lambda + EventBridge (Replace roi-cron)

`infra/lambda/roi-cron/index.ts`:
```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const handler = async () => {
  // Same logic as backend/src/scripts/cron-roi.ts
  // but runs serverless — no container running 24/7
  const activeInvestments = await prisma.investment.findMany({
    where: { status: 'ACTIVE' },
  });

  for (const inv of activeInvestments) {
    // Credit ROI logic...
  }

  return { statusCode: 200, body: `Processed ${activeInvestments.length} investments` };
};
```

Terraform (`modules/serverless/main.tf`):
```hcl
resource "aws_lambda_function" "roi_cron" {
  filename         = "lambda/roi-cron.zip"
  function_name    = "roi-platform-cron"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 60
  memory_size      = 256
}

resource "aws_scheduler_schedule" "roi_cron" {
  name       = "roi-hourly-cron"
  schedule_expression = "rate(1 hour)"
  flexible_time_window { mode = "OFF" }

  target {
    arn      = aws_lambda_function.roi_cron.arn
    role_arn = aws_iam_role.scheduler_exec.arn
  }
}
```
**Cost**: ~$0.10/month | **Resume line**: *"Migrated cron worker from always-on Docker container to serverless Lambda + EventBridge (cost reduction)"*

### 7.2 — Redis (Docker on existing EC2)

Add to `docker-compose.infra.yml`:
```yaml
redis:
  image: redis:7-alpine
  container_name: roi_redis
  restart: unless-stopped
  command: redis-server --maxmemory 128mb --maxmemory-policy allkeys-lru
  ports:
    - "6379:6379"
  volumes:
    - redis_data:/data
  networks:
    - roi_network
```

Use in backend for:
- API rate limiting (express-rate-limit with redis store)
- Session caching
- Hot data caching

**Cost**: $0 (runs on existing EC2) | **Resume line**: *"Redis caching layer for session management, rate limiting, and API response caching"*

---

## Phase 8: Observability (Distributed Tracing)

**Cost**: FREE | **Effort**: ~2 hours

### 8.1 — OpenTelemetry + Grafana Tempo

Add to `docker-compose.infra.yml`:
```yaml
tempo:
  image: grafana/tempo:latest
  container_name: roi_tempo
  restart: unless-stopped
  command: [ "-config.file=/etc/tempo.yaml" ]
  volumes:
    - ./monitoring/tempo-config.yml:/etc/tempo.yaml:ro
    - tempo_data:/tmp/tempo
  ports:
    - "4317:4317"    # OTLP gRPC
    - "4318:4318"    # OTLP HTTP
  networks:
    - roi_network
```

`backend/src/tracing.ts`:
```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http';
import { ExpressInstrumentation } from '@opentelemetry/instrumentation-express';
import { PrismaInstrumentation } from '@prisma/instrumentation';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://tempo:4318/v1/traces',
  }),
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
    new PrismaInstrumentation(),
  ],
  serviceName: 'roi-backend',
});

sdk.start();
```

**Resume line**: *"Distributed tracing with OpenTelemetry + Grafana Tempo — end-to-end request tracing from HTTP to database"*

---

## Phase 9: Terraform Maturity

**Cost**: FREE | **Effort**: ~2 hours

### 9.1 — Modular Architecture

Refactor monolithic `main.tf` into modules (see Directory Structure above):
```hcl
# infra/terraform/main.tf (after refactor)
module "compute" {
  source        = "./modules/compute"
  instance_type = var.instance_type
  key_pair_name = var.key_pair_name
  environment   = var.environment
}

module "database" {
  source      = "./modules/database"
  db_username = var.db_username
  db_password = var.db_password
  ec2_sg_id   = module.compute.security_group_id
  environment = var.environment
}

module "monitoring" {
  source          = "./modules/monitoring"
  ec2_instance_id = module.compute.instance_id
  rds_instance_id = module.database.instance_id
}

module "cdn" {
  source       = "./modules/cdn"
  ec2_public_ip = module.compute.public_ip
}

module "security" {
  source       = "./modules/security"
  db_username  = var.db_username
  db_password  = var.db_password
  rds_endpoint = module.database.endpoint
}
```
**Resume line**: *"Modular Terraform architecture with reusable infrastructure components"*

### 9.2 — Drift Detection Workflow

`.github/workflows/drift-detection.yml`:
```yaml
name: Terraform Drift Detection

on:
  schedule:
    - cron: '0 6 * * 1'  # Every Monday at 6 AM UTC
  workflow_dispatch:

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Terraform Init
        working-directory: ./infra/terraform
        run: terraform init

      - name: Terraform Plan (Drift Detection)
        working-directory: ./infra/terraform
        run: terraform plan -detailed-exitcode
        continue-on-error: true
        env:
          TF_VAR_key_pair_name: ${{ secrets.AWS_KEY_PAIR_NAME }}
          TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
```
**Resume line**: *"Infrastructure drift detection with scheduled Terraform plans"*

### 9.3 — Per-Environment tfvars

```hcl
# infra/terraform/envs/prod.tfvars
environment   = "production"
instance_type = "t3.small"
db_instance   = "db.t4g.micro"

# infra/terraform/envs/dev.tfvars
environment   = "development"
instance_type = "t3.micro"
db_instance   = "db.t4g.micro"
```
**Resume line**: *"Multi-environment Terraform configurations with per-env variable files"*

---

## Phase 10: Documentation & Architecture

**Cost**: FREE | **Effort**: ~1 hour

### 10.1 — Architecture Decision Records (ADRs)

Create `docs/ADR/` with:

| ADR | Title | Summary |
|---|---|---|
| ADR-001 | Blue/Green over Rolling Updates | Why we chose Nginx port-swap over K8s rolling updates — single server, instant rollback |
| ADR-002 | Loki over CloudWatch Logs | Why self-hosted logging — Grafana integration, no per-GB cost, already have Prometheus |
| ADR-003 | SOPS over SSM Parameter Store | Why Git-native encryption — no AWS dependency at deploy time, works offline |
| ADR-004 | Lambda Cron Migration | Why serverless cron — cost reduction from 24/7 container to ~720 invocations/month |

**Resume line**: *"Architecture Decision Records (ADRs) for engineering documentation"*

### 10.2 — GitHub Environments + Approval Gates

Settings → Environments:
- `production` — Require manual approval before deploy
- `staging` — Auto-deploy on PR merge

**Resume line**: *"Deployment gates with environment-based approval workflows"*

---

## Cost Breakdown

### If AWS Account < 12 Months (Free Tier Eligible)

| Service | Monthly Cost |
|---|---|
| EC2 t3.small | ~$15 |
| RDS db.t4g.micro | **FREE** ✅ |
| Elastic IP (attached) | **FREE** ✅ |
| S3 (state + backups + uploads) | ~$0.50 |
| CloudFront (1TB free) | **FREE** ✅ |
| CloudWatch (10 alarms) | **FREE** ✅ |
| Lambda + EventBridge | **FREE** ✅ |
| DynamoDB (lock table) | **FREE** ✅ |
| Secrets Manager (5 secrets) | ~$2 |
| WAF (optional) | ~$5 |
| Domain | ~$1 |
| **Total** | **~$23.50/month** (with WAF: ~$28.50) |

### If AWS Account > 12 Months (No Free Tier)

| Service | Monthly Cost |
|---|---|
| EC2 t3.small | ~$15 |
| RDS db.t4g.micro | ~$13 |
| Elastic IP | $3.65 |
| S3 | ~$0.50 |
| CloudFront | ~$1 |
| CloudWatch | FREE (10 alarms) |
| Lambda | ~$0.10 |
| DynamoDB | ~$0.25 |
| Secrets Manager | ~$2 |
| WAF (optional) | ~$5 |
| Domain | ~$1 |
| **Total** | **~$36.50/month** (without WAF: ~$31.50) |

> **💡 Cost Saving Tip**: Run `terraform destroy` when not demoing. Only keep S3 + DynamoDB + domain alive (~$2/month). Spin up everything before interviews.

---

## Resume Coverage — ROI vs TeleDoc

| Category | TeleDoc Uses | ROI Uses (After All Phases) |
|---|---|---|
| **Deployment** | ASG Instance Refresh | Blue/Green (Nginx swap) |
| **Container Registry** | AWS ECR | GHCR / Build on server |
| **Load Balancer** | ALB + Target Groups | Nginx reverse proxy |
| **Scaling** | Auto Scaling Group | Single EC2 (right-sized) |
| **SSL** | ACM (AWS managed) | Certbot (Let's Encrypt) |
| **Secrets** | SSM Parameter Store | SOPS + AWS Secrets Manager |
| **Alerts** | SNS (email) | Alertmanager (Discord) + CloudWatch |
| **Logging** | CloudWatch Logs | Loki + Promtail |
| **Tracing** | ❌ | OpenTelemetry + Tempo |
| **CDN** | ❌ | CloudFront |
| **WAF** | ❌ | AWS WAF |
| **Caching** | ❌ | Redis |
| **Serverless** | ❌ | Lambda + EventBridge |
| **Config Mgmt** | Ansible | Makefile + SOPS |
| **Code Quality** | ❌ | SonarCloud + Husky |
| **IaC Modules** | Flat .tf files | Terraform modules |
| **Drift Detection** | ❌ | Scheduled terraform plan |
| **Dependencies** | ❌ | Dependabot (4 ecosystems) |

### Combined Keyword Count Across Both Projects

- **AWS Services**: EC2, RDS, S3, ECR, VPC, ALB, ASG, CloudFront, CloudWatch, IAM, ACM, SNS, SSM, Secrets Manager, WAF, Lambda, EventBridge, DynamoDB = **18 services**
- **DevOps Tools**: Terraform, Ansible, Docker, Compose, GitHub Actions, Nginx, Certbot, Prometheus, Grafana, Loki, Promtail, Alertmanager, Tempo, OpenTelemetry, Trivy, tfsec, tflint, SOPS, Dependabot, Husky, SonarCloud, Pino, Redis, Makefile, Helm = **25 tools**
- **Practices**: Blue/Green, ASG Refresh, Zero Downtime, IaC, GitOps, CI/CD, DevSecOps, Centralized Logging, Distributed Tracing, Alerting, Secrets Management, Drift Detection, Branch Protection, Pre-commit Hooks, Rate Limiting, Cost Optimization = **16 practices**

---

## Implementation Timeline

| Day | Phase | Tasks | New Keywords |
|---|---|---|---|
| **1** | Phase 2 | Dependabot, Branch Protection, Makefile, Husky | +5 |
| **2** | Phase 3 | Multi-stage Docker, Health checks, Log rotation | +3 |
| **3** | Phase 4 | Alertmanager, Alert rules, Structured logging (Pino) | +3 |
| **4** | Phase 5 | Nginx rate limiting, helmet.js, SOPS | +4 |
| **5** | Phase 6 | CloudWatch alarms, CloudFront, Secrets Manager (Terraform) | +4 |
| **6** | Phase 7 | Lambda + EventBridge cron, Redis Docker | +4 |
| **7** | Phase 8 | OpenTelemetry + Tempo (distributed tracing) | +2 |
| **8** | Phase 9 | Terraform modules refactor, drift detection, per-env tfvars | +3 |
| **9** | Phase 10 | ADRs, GitHub Environments, SonarCloud, WAF (optional) | +4 |
| **10** | Polish | README update, architecture diagram, final testing | — |

> **Total: 10 days → 18 AWS services + 25 tools + 16 practices on your resume.**



# ============================================================
# Quick To-Do List 

GitHub Branch Protection — Settings → Branches → Add rule
GitHub Environments — Settings → Environments → Create production
npm install — cd backend && npm install pino pino-pretty ioredis @opentelemetry/sdk-node @opentelemetry/exporter-trace-otlp-http @opentelemetry/instrumentation-http @opentelemetry/instrumentation-express @opentelemetry/resources @opentelemetry/semantic-conventions
age key — Run age-keygen and update .sops.yaml
Discord webhook — Add URL to alertmanager.yml
terraform plan — Verify modules work before applying  

## end 