# 🎯 DevOps Interview Prep — ROI Platform

> **Level**: 0–3 Years | **Domain**: DevOps Engineer
> **Context**: Every question below maps to a real tool/service used in the ROI Platform project.
> Total Tools: **24** | Total Questions: **150+**

---

## 📋 Complete Tool Inventory

| # | Tool/Service | Category | Where Used in ROI |
|---|---|---|---|
| 1 | Docker | Containerization | `backend/Dockerfile`, `frontend/Dockerfile` |
| 2 | Docker Compose | Container Orchestration | `docker-compose.yml`, `docker-compose.dev.yml`, `docker-compose.infra.yml` |
| 3 | Nginx | Reverse Proxy | `nginx-proxy.conf` |
| 4 | Terraform | Infrastructure as Code | `infra/terraform/` |
| 5 | AWS EC2 | Compute | `t3.small` production server |
| 6 | AWS S3 | Object Storage | `roi-platform-uploads-974387`, `roi-platform-tf-state-974387` |
| 7 | AWS DynamoDB | NoSQL Database | `roi-platform-tf-locks` |
| 8 | AWS IAM | Identity & Access | `infra/terraform/iam.tf` |
| 9 | AWS VPC | Networking | `infra/terraform/main.tf` |
| 10 | GitHub Actions | CI/CD | `.github/workflows/` (5 workflows) |
| 11 | Dependabot | Dependency Management | `.github/dependabot.yml` |
| 12 | Prometheus | Metrics | `monitoring/prometheus.yml` |
| 13 | Grafana | Visualization | `monitoring/grafana/` |
| 14 | Loki | Log Aggregation | `monitoring/loki-config.yml` |
| 15 | Promtail | Log Shipping | `monitoring/promtail-config.yml` |
| 16 | Tempo | Distributed Tracing | `monitoring/tempo-config.yml` |
| 17 | Alertmanager | Alert Routing | `monitoring/alertmanager.yml` |
| 18 | Node Exporter | Host Metrics | `docker-compose.infra.yml` |
| 19 | Redis | Caching | `docker-compose.infra.yml` |
| 20 | SOPS | Secret Encryption | `.sops.yaml` |
| 21 | Makefile | Workflow Automation | `Makefile` (17 targets) |
| 22 | Certbot / Let's Encrypt | SSL Certificates | EC2 server setup |
| 23 | Prisma | Database ORM | `backend/prisma/schema.prisma` |
| 24 | Blue/Green Deployment | Deployment Strategy | `docs/ADR/001-blue-green-over-rolling.md` |

---

# Part 1 — Containerization & Reverse Proxy

---

## 🐳 1. Docker

### What is it?
Docker is a **containerization platform** that packages your application code + dependencies + runtime into a single portable unit called a **container**.

### Why do we use it in ROI?
- Our backend (Express.js) and frontend (React/Vite) run inside Docker containers on an EC2 instance.
- Without Docker, you'd need to install Node.js, npm, build tools, etc. manually on the server — **"works on my machine"** problem.
- Docker guarantees **identical environments** from your laptop to production.

### Key Components

| Component | What it Does | ROI Example |
|---|---|---|
| **Dockerfile** | Blueprint to build an image | `backend/Dockerfile`, `frontend/Dockerfile` |
| **Image** | Read-only template (like a class) | `roi_backend:latest`, `roi_frontend:latest` |
| **Container** | Running instance of an image (like an object) | `roi_backend`, `roi_frontend` |
| **Registry** | Storage for images | Docker Hub, AWS ECR |
| **Layer** | Each instruction in Dockerfile creates a cached layer | `COPY package*.json` → separate layer for caching |
| **Volume** | Persistent storage that survives container restarts | `prometheus_data`, `grafana_data` |
| **Network** | Virtual network for container-to-container communication | `roi_global_network` |

### Multi-Stage Builds (Used in ROI)
```dockerfile
# Stage 1: Build (heavy — has node_modules, dev tools)
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production (lightweight — only compiled output)
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/index.js"]
```
**Why?** The final image is **~80% smaller**. Build tools stay in Stage 1 and are discarded.

### Interview Questions (0–3 Years)

**Q1: What is Docker and why do we use it?**
**A:** Docker is a containerization platform that packages applications with all their dependencies into isolated units called containers. We use it because:
- **Consistency**: Same environment from dev laptop → staging → production.
- **Isolation**: Each service (backend, frontend, Redis) runs in its own container with no conflicts.
- **Portability**: Containers run on any machine with Docker installed — AWS, GCP, your laptop.
- **Efficiency**: Containers share the host OS kernel, unlike VMs which need a full OS.

**Q2: What is the difference between a Docker Image and a Container?**
**A:**
| Image | Container |
|---|---|
| Read-only template (like a **class** in OOP) | Running instance (like an **object**) |
| Built from a Dockerfile | Created from an image using `docker run` |
| Can exist without a container | Cannot exist without an image |
| Stored in registry | Lives on the host machine |
| Example: `node:20-alpine` | Example: `roi_backend` running on port 5000 |

**Q3: What is a multi-stage build and why is it important?**
**A:** A multi-stage build uses multiple `FROM` statements in a single Dockerfile. Each `FROM` starts a new build stage. You copy only the artifacts you need from one stage to the next.

**Why it matters in ROI:** Our `t3.small` EC2 has only **2 GB RAM**. Without multi-stage builds, our images would include `node_modules`, TypeScript compiler, build tools — wasting ~500 MB per image. Multi-stage keeps only the compiled `dist/` folder → final image is ~150 MB instead of ~800 MB.

**Q4: What is the difference between `CMD` and `ENTRYPOINT`?**
**A:**
| CMD | ENTRYPOINT |
|---|---|
| Default command, can be **overridden** at runtime | Main command, **always runs** |
| `docker run myimg /bin/sh` replaces CMD | `docker run myimg /bin/sh` passes `/bin/sh` as argument to ENTRYPOINT |
| Use for: default behavior | Use for: making container behave like an executable |

In ROI we use: `CMD ["node", "dist/index.js"]` because we want the default to run the app, but allow overriding for debugging.

**Q5: What is the difference between `COPY` and `ADD`?**
**A:**
- `COPY` — Simple file copy from host to image. **Use this by default.**
- `ADD` — Same as COPY + can auto-extract `.tar` files and download URLs.
- **Best practice**: Always use `COPY` unless you specifically need extraction. `ADD` has hidden behavior that can cause bugs.

**Q6: What is a Docker Volume? Why not just store data inside the container?**
**A:** A volume is a persistent storage mechanism managed by Docker. Container filesystems are **ephemeral** — when a container is deleted, all data inside is lost.

In ROI, we use named volumes for:
- `prometheus_data` — metrics history (survives `docker compose down`)
- `grafana_data` — dashboards and settings
- `redis_data` — cached data with `appendonly yes`
- `loki_data` — log storage

Without volumes, every restart would wipe all monitoring history.

**Q7: What is Docker Networking? How do containers talk to each other?**
**A:** Docker creates virtual networks. Containers on the same network can communicate using **container names as hostnames**.

In ROI: All services join `roi_global_network`. So the backend reaches Redis via `redis:6379`, not `localhost:6379`. This works because Docker's built-in DNS resolves container names.

```yaml
networks:
  roi_network:
    name: roi_global_network
    external: true
```
We use `external: true` because multiple compose files share the same network.

**Q8: What does `docker system prune -af` do? When would you use it?**
**A:** It removes **all** unused Docker resources:
- `-a` = remove all unused images (not just dangling ones)
- `-f` = force (no confirmation prompt)

Cleans up: stopped containers, unused networks, dangling images, build cache.

In ROI's Makefile: `make clean` runs this to free disk space on the EC2 instance (which has limited storage).

**Q9: Explain the `.dockerignore` file.**
**A:** Like `.gitignore` but for Docker builds. It prevents specified files from being sent to the Docker daemon's build context.

ROI's `.dockerignore` excludes `node_modules`, `.git`, `.env` — this makes builds **faster** (smaller context) and **safer** (no secrets leaked into images).

**Q10: What is the difference between `docker stop` and `docker kill`?**
**A:**
- `docker stop` — Sends `SIGTERM` first, waits 10 seconds, then sends `SIGKILL`. Graceful shutdown.
- `docker kill` — Sends `SIGKILL` immediately. Forceful termination.

**Production rule**: Always use `stop` to allow the app to close DB connections, flush logs, and finish in-flight requests.

---

## 🐙 2. Docker Compose

### What is it?
Docker Compose is a tool for **defining and running multi-container Docker applications** using a single YAML file.

### Why do we use it in ROI?
ROI has **12+ containers** (backend, frontend, cron, Redis, Prometheus, Grafana, Loki, Promtail, Tempo, Alertmanager, Node Exporter, db-backup). Managing each with individual `docker run` commands would be chaos. Compose lets us define everything in YAML and start with one command.

### ROI's Compose Architecture

| File | Purpose | Containers |
|---|---|---|
| `docker-compose.yml` | **Core application** | backend, frontend, roi-cron |
| `docker-compose.dev.yml` | **Local development** | Same + hot-reload volumes |
| `docker-compose.infra.yml` | **Monitoring + Caching** | Prometheus, Grafana, Loki, Promtail, Tempo, Alertmanager, Node Exporter, Redis, db-backup |

### Key Compose Concepts

| Concept | Explanation | ROI Example |
|---|---|---|
| **Service** | A container definition | `backend`, `frontend`, `prometheus` |
| **depends_on** | Start order (not readiness) | `frontend` depends on `backend` |
| **restart: unless-stopped** | Auto-restart on crash, not on manual stop | All services use this |
| **external network** | Shared network across compose files | `roi_global_network` |
| **named volumes** | Persistent data with explicit names | `roi_prometheus_data` |
| **healthcheck** | Container health verification | Redis: `redis-cli ping` |

### Interview Questions (0–3 Years)

**Q1: What is Docker Compose and how is it different from Docker?**
**A:**
| Docker | Docker Compose |
|---|---|
| Manages **single containers** | Manages **multi-container apps** |
| Uses `docker run` commands | Uses `docker-compose.yml` file |
| Manual networking | Automatic networking |
| No dependency management | `depends_on` for start order |

Docker Compose is not a replacement — it **uses Docker underneath**. It's an orchestration wrapper.

**Q2: What does `docker compose up --build` do?**
**A:** Two things:
1. `--build` — Rebuilds all images from their Dockerfiles (picks up code changes).
2. `up` — Creates and starts all containers defined in the compose file.

Without `--build`, Compose uses cached images — meaning your latest code changes won't be included.

**Q3: Why does ROI use 3 separate compose files instead of 1?**
**A:** **Separation of concerns**:
- `docker-compose.yml` — Core app. Always runs in production.
- `docker-compose.dev.yml` — Dev only. Adds hot-reload, debug ports.
- `docker-compose.infra.yml` — Monitoring stack. Can be started/stopped independently.

This means you can restart monitoring without affecting the app: `docker compose -f docker-compose.infra.yml restart`.

**Q4: What is `restart: unless-stopped`? How does it differ from `always`?**
**A:**
| Policy | Behavior |
|---|---|
| `no` | Never restart |
| `on-failure` | Restart only if exit code ≠ 0 |
| `always` | Always restart, even after manual `docker stop` |
| `unless-stopped` | Always restart EXCEPT when manually stopped |

ROI uses `unless-stopped` so containers auto-recover from crashes but respect manual stops during maintenance.

**Q5: What is an external network in Compose?**
**A:** A network created outside of any compose file, shared across multiple compose files.

```yaml
networks:
  roi_network:
    name: roi_global_network
    external: true
```

In ROI, `roi_global_network` is created once with `docker network create roi_global_network`. Then all 3 compose files reference it. This lets the backend (in `docker-compose.yml`) talk to Prometheus (in `docker-compose.infra.yml`).

Without this, each compose file would create isolated networks and containers couldn't communicate.

**Q6: What is a healthcheck in Docker Compose?**
**A:** A command that Docker runs periodically to check if a container is working correctly.

```yaml
redis:
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 3s
    retries: 3
```

If Redis stops responding to `ping`, Docker marks it as `unhealthy`. Other services using `depends_on: redis: condition: service_healthy` will wait until Redis is healthy before starting.

**Q7: How does `depends_on` work? Does it wait for the service to be "ready"?**
**A:** **No!** `depends_on` only controls **start order**, not readiness.

```yaml
frontend:
  depends_on:
    - backend   # Starts backend FIRST, but doesn't wait for it to be ready
```

For readiness, you need `condition: service_healthy` combined with a `healthcheck`. In ROI, the backend uses an entrypoint script (`docker-entrypoint.sh`) that runs migrations before starting the app — this handles readiness internally.

**Q8: What is `docker compose logs -f`? What does the `-f` flag do?**
**A:**
- `docker compose logs` — Shows logs from all containers.
- `-f` (follow) — Streams logs in real-time (like `tail -f`).
- `--tail 100` — Shows only the last 100 lines.

In ROI's Makefile: `make logs` runs `docker logs roi_backend --tail 100 -f` to stream production logs.

---

## 🌐 3. Nginx

### What is it?
Nginx is a **high-performance web server** that also functions as a **reverse proxy**, load balancer, and HTTP cache.

### Why do we use it in ROI?
Nginx sits **in front of** our Docker containers on the EC2 instance and handles:
1. **Reverse proxy** — Routes traffic to backend (port 5000) or frontend (port 3000).
2. **SSL termination** — Handles HTTPS via Certbot/Let's Encrypt.
3. **Rate limiting** — DDoS protection (3 req/s for auth, 10 req/s for API).
4. **Security headers** — OWASP-recommended headers (XSS, clickjacking protection).

### ROI's Nginx Architecture

```
Internet → Nginx (:80/:443)
               ├── /api/auth/*  →  backend:5000  (3 req/s limit)
               ├── /api/*       →  backend:5000  (10 req/s limit)
               └── /*           →  frontend:3000 (30 req/s limit)
```

### Key Components from `nginx-proxy.conf`

| Component | What it Does | ROI Config |
|---|---|---|
| **limit_req_zone** | Defines rate limit buckets | `api:10m rate=10r/s`, `auth:10m rate=3r/s` |
| **proxy_pass** | Forwards request to upstream server | `http://127.0.0.1:5000` |
| **Security Headers** | OWASP protection | `X-Frame-Options`, `X-Content-Type-Options`, `HSTS` |
| **proxy_set_header** | Passes client info to backend | `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` |
| **client_max_body_size** | Max upload size | `10m` for API (KYC document uploads) |

### Interview Questions (0–3 Years)

**Q1: What is a Reverse Proxy? How is it different from a Forward Proxy?**
**A:**
| Forward Proxy | Reverse Proxy |
|---|---|
| Sits in front of **clients** | Sits in front of **servers** |
| Client knows it's using a proxy | Client doesn't know about the proxy |
| Use case: bypass geo-restrictions, anonymity | Use case: load balancing, SSL, security |
| Example: VPN, corporate proxy | Example: Nginx, HAProxy |

In ROI, Nginx is a reverse proxy. Users hit `paisatest.online` → Nginx → routes to backend or frontend containers.

**Q2: What is rate limiting and why is it important?**
**A:** Rate limiting controls how many requests a client can make in a given time window.

In ROI:
```nginx
limit_req_zone $binary_remote_addr zone=auth:10m rate=3r/s;
```
- `$binary_remote_addr` — Track per IP address.
- `zone=auth:10m` — 10 MB memory to store IP tracking data.
- `rate=3r/s` — Max 3 requests per second.

**Why different rates?**
- Auth (`3r/s`) — Stricter to prevent brute-force login attacks.
- API (`10r/s`) — Moderate for normal operations.
- Frontend (`30r/s`) — Generous because pages load many assets.

**Q3: What is the `burst` parameter in rate limiting?**
**A:** Burst allows a temporary spike above the rate limit.

```nginx
limit_req zone=api burst=20 nodelay;
```
- `burst=20` — Allow up to 20 excess requests to queue.
- `nodelay` — Process burst requests immediately instead of queuing.

Without burst, a page loading 15 resources simultaneously would hit the rate limit and fail. Burst handles legitimate traffic spikes.

**Q4: What are security headers? Name 3 and explain them.**
**A:**

| Header | What it Prevents | ROI Value |
|---|---|---|
| `X-Frame-Options: SAMEORIGIN` | **Clickjacking** — prevents your site from being loaded in an iframe on another site | Only allows iframes from same origin |
| `X-Content-Type-Options: nosniff` | **MIME sniffing** — prevents browser from guessing content types | Forces browser to respect declared content type |
| `Strict-Transport-Security` (HSTS) | **Downgrade attacks** — forces HTTPS for all future visits | `max-age=31536000` = 1 year |
| `X-XSS-Protection: 1; mode=block` | **XSS attacks** — enables browser's built-in XSS filter | Blocks the page if XSS detected |
| `Referrer-Policy` | **Information leakage** — controls what URL info is sent when navigating | `strict-origin-when-cross-origin` |

**Q5: What is SSL termination?**
**A:** SSL termination means Nginx handles the HTTPS encryption/decryption, and talks to backend containers over plain HTTP.

```
Client ──(HTTPS)──> Nginx ──(HTTP)──> backend:5000
```

**Why?** 
- Backend doesn't need to manage SSL certificates.
- Reduces CPU load on the application.
- Certbot auto-renews certificates on Nginx — zero downtime.

**Q6: What does `proxy_set_header X-Real-IP $remote_addr` do?**
**A:** When Nginx proxies a request, the backend sees the request coming from Nginx's IP (127.0.0.1), not the client's real IP.

`X-Real-IP` passes the **original client IP** to the backend. This is critical for:
- Rate limiting at the application level
- Logging (knowing who made the request)
- Geo-location based features
- Fraud detection

**Q7: What is `client_max_body_size` and why is it set to `10m` for the API?**
**A:** It limits the maximum size of the request body. Default in Nginx is only 1 MB.

In ROI, users upload KYC documents (ID photos, bank statements) via the API to S3 (`roi-platform-uploads-974387`). These files can be several MBs, so we set `10m` (10 megabytes) on the `/api` location.

The frontend location doesn't need this because it only serves static files (HTML, CSS, JS).

**Q8: What happens if Nginx goes down? How would you make it highly available?**
**A:** If Nginx goes down, the entire site goes offline because it's the single entry point.

For high availability:
1. **Systemd service** — Auto-restart on crash (`systemctl enable nginx`).
2. **AWS ALB** — Put an Application Load Balancer in front, run multiple Nginx instances.
3. **Keepalived + VRRP** — Floating IP that switches to a standby Nginx.
4. **Health checks** — Monitor Nginx status and alert via Alertmanager.

In ROI (budget project), we rely on systemd auto-restart + Alertmanager alerts.

---

*— End of Part 1. Part 2 covers Terraform, EC2, S3, DynamoDB, IAM, VPC →*


---

# Part 2 — Infrastructure as Code & AWS Cloud

---

## 🏗️ 4. Terraform

### What is it?
Terraform is an **Infrastructure as Code (IaC)** tool by HashiCorp that lets you define cloud resources (servers, networks, databases) in human-readable `.tf` files and create/modify/destroy them with CLI commands.

### Why do we use it in ROI?
Instead of clicking through the AWS Console to create an EC2 instance, VPC, security groups, and IAM roles, we define everything in code:
- **Version controlled** — Infrastructure changes are tracked in Git like application code.
- **Reproducible** — Run `terraform apply` to recreate the entire infra from scratch.
- **Reviewable** — Team reviews infra changes via Pull Requests.
- **Destroyable** — `terraform destroy` tears down everything cleanly (no orphaned resources).

### ROI's Terraform Structure

```
infra/terraform/
├── main.tf              # EC2, VPC, Security Groups
├── variables.tf         # Input variables
├── terraform.tfvars     # Variable values
├── outputs.tf           # Output values (IP, DNS)
├── iam.tf               # IAM roles and policies
├── s3.tf                # S3 bucket policies
├── modules/
│   ├── monitoring/      # CloudWatch alarms
│   ├── security/        # WAF, Shield rules
│   └── serverless/      # Lambda functions
└── envs/                # Environment-specific configs
```

### Terraform Lifecycle

```
terraform init    →  Downloads providers (AWS), sets up backend
terraform plan    →  Shows what WILL change (dry run)
terraform apply   →  Creates/modifies resources
terraform destroy →  Tears down everything
```

### Key Concepts

| Concept | Explanation | ROI Example |
|---|---|---|
| **Provider** | Plugin for a cloud platform | `provider "aws" { region = "us-east-1" }` |
| **Resource** | A cloud object to create | `resource "aws_instance" "roi_server"` |
| **State** | JSON file tracking what exists | Stored in S3: `roi-platform-tf-state-974387` |
| **State Locking** | Prevents concurrent modifications | DynamoDB: `roi-platform-tf-locks` |
| **Module** | Reusable group of resources | `modules/monitoring/`, `modules/security/` |
| **Variable** | Input parameter | `var.instance_type = "t3.small"` |
| **Output** | Exposed value after apply | `output "public_ip"` |
| **Backend** | Where state is stored | S3 backend with DynamoDB locking |

### Interview Questions (0–3 Years)

**Q1: What is Infrastructure as Code (IaC)? Why is it better than manual provisioning?**
**A:** IaC means managing infrastructure (servers, networks, databases) through code files instead of manual UI clicks.

| Manual (AWS Console) | IaC (Terraform) |
|---|---|
| Click through UI, no record | Code in Git, full history |
| Can't reproduce exactly | `terraform apply` recreates everything |
| No peer review | PR review for infra changes |
| Hard to audit changes | `terraform plan` shows exact diff |
| One-off, error-prone | Idempotent and repeatable |

**Q2: What is Terraform State? Why is it important?**
**A:** State is a JSON file (`terraform.tfstate`) that maps your `.tf` code to real cloud resources.

Example: When you write `resource "aws_instance" "server" {}` and apply, Terraform creates an EC2 instance and records its ID (`i-0abc123`) in state. Next time you run `plan`, Terraform compares your code to state to determine what changed.

**Without state**: Terraform wouldn't know what already exists and would try to create duplicates.

In ROI, state is stored **remotely** in S3 (`roi-platform-tf-state-974387`) so the whole team and CI/CD can access it.

**Q3: Why do we store Terraform state in S3 instead of locally?**
**A:**
| Local State | Remote State (S3) |
|---|---|
| Only on your laptop | Accessible by team + CI/CD |
| Lost if laptop dies | Durable (S3 has 99.999999999% durability) |
| No locking — concurrent runs corrupt state | DynamoDB locking prevents conflicts |
| Can't use in GitHub Actions | CI/CD pipeline reads/writes state |

```hcl
backend "s3" {
  bucket         = "roi-platform-tf-state-974387"
  key            = "terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "roi-platform-tf-locks"
  encrypt        = true
}
```

**Q4: What is State Locking with DynamoDB?**
**A:** When two people (or CI/CD + a developer) run `terraform apply` simultaneously, both read the same state, make changes, and one overwrites the other — **state corruption**.

DynamoDB locking:
1. Before `apply`, Terraform writes a lock record to `roi-platform-tf-locks`.
2. If another process tries to apply, it sees the lock and **waits or fails**.
3. After apply completes, the lock is released.

This ensures only ONE Terraform operation runs at a time.

**Q5: What is `terraform plan`? Why should you always run it before `apply`?**
**A:** `terraform plan` is a **dry run** that shows exactly what Terraform will create, modify, or destroy — without actually doing it.

Output looks like:
```
+ aws_instance.server     (create)
~ aws_security_group.web  (modify: add port 443)
- aws_s3_bucket.old       (destroy)
```

**Why always plan first?**
- Catches unintended destroys (a typo could delete your database).
- Shows the blast radius of a change.
- Can be saved to a file and used by `apply` to guarantee exact execution.
- In ROI's CI/CD, `plan` runs on PR, `apply` runs on merge to main.

**Q6: What is a Terraform Module?**
**A:** A module is a **reusable package** of Terraform resources. Instead of copy-pasting the same VPC + subnet + security group code for every project, you create a module once and call it.

ROI uses modules:
```
modules/
├── monitoring/   # CloudWatch alarms, SNS topics
├── security/     # WAF rules, Shield config
└── serverless/   # Lambda functions, API Gateway
```

Usage:
```hcl
module "monitoring" {
  source = "./modules/monitoring"
  alarm_email = var.alert_email
}
```

**Q7: What is `terraform init` and when do you need to run it?**
**A:** `terraform init` initializes a Terraform working directory:
1. Downloads **provider plugins** (e.g., AWS provider).
2. Configures the **backend** (S3 + DynamoDB).
3. Downloads **modules** from registries.

You run it:
- First time setting up the project.
- After adding a new provider or module.
- After changing backend configuration.
- After cloning the repo on a new machine.

**Q8: What is Terraform Drift? How does ROI detect it?**
**A:** Drift happens when someone changes infrastructure **manually** (via AWS Console) but Terraform state still shows the old config.

Example: Someone adds port 8080 to a security group via Console → Terraform doesn't know about it.

ROI detects drift with a **scheduled GitHub Action** (`drift-detection.yml`):
```yaml
schedule:
  - cron: '0 6 * * *'  # Runs daily at 6 AM
```
It runs `terraform plan` and if there's drift (planned changes ≠ 0), it alerts the team.

**Q9: What is the difference between `terraform.tfvars` and `variables.tf`?**
**A:**
| `variables.tf` | `terraform.tfvars` |
|---|---|
| **Declares** variables (name, type, description, default) | **Assigns** values to variables |
| Committed to Git | May contain secrets, may be gitignored |
| Like a function signature | Like calling the function with arguments |

```hcl
# variables.tf
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# terraform.tfvars
instance_type = "t3.small"
```

**Q10: What happens if you accidentally delete the Terraform state file?**
**A:** Terraform loses all knowledge of existing resources. Next `apply` would try to **create everything from scratch** — resulting in duplicate resources or errors.

Recovery options:
1. **S3 versioning** — If enabled, restore the previous version of the state file.
2. `terraform import` — Manually re-import each resource by its cloud ID.
3. **Backups** — This is why ROI stores state in S3 with versioning enabled.

**Prevention**: Never delete state manually. Use `terraform state rm` to remove specific resources.

### Terraform CLI Cheat Sheet

| Command | What it Does | Example |
|---|---|---|
| `terraform init` | Initialize working dir, download providers | `terraform init -backend-config=backend.hcl` |
| `terraform plan` | Dry run — show what will change | `terraform plan -out=tfplan` |
| `terraform apply` | Create/modify resources | `terraform apply tfplan` |
| `terraform destroy` | Tear down all resources | `terraform destroy -auto-approve` |
| `terraform validate` | Check syntax and internal consistency | `terraform validate` |
| `terraform fmt` | Auto-format `.tf` files | `terraform fmt -recursive` |
| `terraform state list` | List all resources in state | `terraform state list` |
| `terraform state show` | Show details of one resource | `terraform state show aws_instance.roi_server` |
| `terraform state rm` | Remove resource from state (not from cloud) | `terraform state rm aws_s3_bucket.old` |
| `terraform import` | Import existing cloud resource into state | `terraform import aws_instance.server i-0abc123` |
| `terraform taint` | Mark resource for recreation on next apply | `terraform taint aws_instance.roi_server` |
| `terraform untaint` | Undo taint | `terraform untaint aws_instance.roi_server` |
| `terraform refresh` | Sync state with real cloud (deprecated, use `plan -refresh-only`) | `terraform plan -refresh-only` |
| `terraform workspace` | Manage multiple environments | `terraform workspace new staging` |
| `terraform output` | Show output values | `terraform output public_ip` |
| `terraform graph` | Generate dependency graph (DOT format) | `terraform graph \| dot -Tpng > graph.png` |
| `terraform console` | Interactive expression evaluator | `terraform console` → `var.instance_type` |

**Q11: Someone made a manual change in AWS Console. How do you import it into Terraform state?**
**A:** This is a **3-step process**:

**Step 1: Identify what was changed manually.**
Run `terraform plan` — it will show drift (differences between state and real infra).
```bash
terraform plan
# Output: ~ aws_security_group.web will be updated
#   + ingress rule: port 8080 (exists in AWS but not in state)
```

**Step 2: If it's a NEW resource (not in your `.tf` files), write the resource block first.**
```hcl
# main.tf — add this block
resource "aws_security_group_rule" "manual_8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
}
```

**Step 3: Import the real resource into state.**
```bash
# Syntax: terraform import <resource_type>.<name> <cloud_id>
terraform import aws_security_group_rule.manual_8080 sg-0abc123_ingress_tcp_8080_8080_0.0.0.0/0
```

**Step 4: Verify — run plan again.**
```bash
terraform plan
# Output: No changes. Infrastructure is up-to-date.
```

**Common import commands:**
```bash
# EC2 instance
terraform import aws_instance.server i-0abc123def456

# S3 bucket
terraform import aws_s3_bucket.uploads roi-platform-uploads-974387

# Security Group
terraform import aws_security_group.web sg-0abc123

# IAM Role
terraform import aws_iam_role.ec2_role roi-ec2-role

# VPC
terraform import aws_vpc.main vpc-0abc123
```

**Q12: Explain `terraform.tfvars` vs `variables.tf` vs `.auto.tfvars` vs `TF_VAR_` in detail.**
**A:** Terraform has **4 ways** to set variable values, with a clear precedence order:

| Method | File/Syntax | Use Case | Precedence |
|---|---|---|---|
| `variables.tf` | `variable "name" { default = "x" }` | Declare + default value | Lowest |
| `terraform.tfvars` | `name = "y"` | Override defaults | Medium |
| `*.auto.tfvars` | `name = "z"` (auto-loaded) | Environment-specific | Medium |
| `TF_VAR_name` | `export TF_VAR_name="w"` | CI/CD, secrets | Medium |
| `-var` flag | `terraform apply -var="name=v"` | One-off overrides | **Highest** |

**Precedence order** (highest wins):
```
-var flag > TF_VAR_ env > *.auto.tfvars > terraform.tfvars > variable default
```

**Multi-environment pattern:**
```
envs/
├── dev.tfvars      # instance_type = "t3.micro"
├── staging.tfvars  # instance_type = "t3.small"
└── prod.tfvars     # instance_type = "t3.medium"

# Usage:
terraform apply -var-file="envs/prod.tfvars"
```

**CI/CD pattern (GitHub Actions):**
```yaml
env:
  TF_VAR_instance_type: "t3.small"
  TF_VAR_alert_email: ${{ secrets.ALERT_EMAIL }}
```

**Q13: What is `terraform validate`? How is it different from `plan`?**
**A:**
| `validate` | `plan` |
|---|---|
| Checks **syntax** and **internal consistency** | Checks **what will change** in the cloud |
| Does NOT contact AWS | Contacts AWS to compare state vs real |
| Fast (< 1 second) | Slow (5-30 seconds) |
| Catches: missing variables, type errors, bad references | Catches: drift, unintended destroys |
| Run in: pre-commit hooks, CI early stage | Run in: CI before apply, PR reviews |

```bash
terraform validate
# Success! The configuration is valid.

# Common errors it catches:
# - Referencing a variable that doesn't exist
# - Wrong attribute type (string vs number)
# - Missing required arguments in a resource
```

**Q14: What are Terraform Workspaces?**
**A:** Workspaces let you manage **multiple environments** (dev, staging, prod) with the same `.tf` code but separate state files.

```bash
terraform workspace new staging     # Create workspace
terraform workspace new production
terraform workspace select staging  # Switch to staging
terraform workspace list            # Show all workspaces
```

Each workspace has its own state file in S3:
```
s3://roi-platform-tf-state-974387/
├── env:/dev/terraform.tfstate
├── env:/staging/terraform.tfstate
└── env:/production/terraform.tfstate
```

Use `terraform.workspace` in code:
```hcl
resource "aws_instance" "server" {
  instance_type = terraform.workspace == "production" ? "t3.small" : "t3.micro"
  tags = {
    Environment = terraform.workspace
  }
}
```

**When NOT to use workspaces**: When environments have significantly different infrastructure (e.g., prod has a load balancer, dev doesn't). Use separate directories instead.

---

## ☁️ 5. AWS EC2

### What is it?
**Elastic Compute Cloud** — Virtual servers in the cloud. You rent computing power by the hour.

### ROI's Setup
- **Instance type**: `t3.small` (2 vCPU, 2 GB RAM)
- **OS**: Ubuntu (via AMI)
- **Region**: `us-east-1` (N. Virginia)
- **Access**: SSH via key pair
- All Docker containers run on this single instance.

### Interview Questions (0–3 Years)

**Q1: What is an EC2 instance? What is an AMI?**
**A:** An EC2 instance is a virtual server in AWS cloud. An AMI (Amazon Machine Image) is a pre-configured template that includes the OS and software — like a Docker image but for VMs.

When you launch an instance, you pick an AMI (e.g., Ubuntu 22.04) and an instance type (e.g., `t3.small`).

**Q2: What is the difference between `t3.small`, `t3.micro`, `t3.medium`?**
**A:**
| Type | vCPU | RAM | Use Case | Cost (~) |
|---|---|---|---|---|
| `t3.micro` | 2 | 1 GB | Free tier, testing | ~$8/mo |
| `t3.small` | 2 | 2 GB | Small production apps | ~$15/mo |
| `t3.medium` | 2 | 4 GB | Medium workloads | ~$30/mo |

The `t` family uses **burstable performance** — you get a baseline CPU and can burst higher for short periods using CPU credits. Good for workloads that don't need constant high CPU.

ROI uses `t3.small` because 2 GB is the minimum to run 12+ Docker containers with aggressive memory limits.

**Q3: What is a Security Group?**
**A:** A Security Group is a **virtual firewall** for your EC2 instance. It controls inbound and outbound traffic.

ROI's security group allows:
| Port | Source | Purpose |
|---|---|---|
| 22 | Your IP only | SSH access |
| 80 | 0.0.0.0/0 | HTTP (redirects to HTTPS) |
| 443 | 0.0.0.0/0 | HTTPS |
| 3001 | Your IP only | Grafana dashboard |

**Key rule**: Security groups are **stateful** — if you allow inbound traffic on port 443, the response is automatically allowed out.

**Q4: What is an Elastic IP? Why does ROI use one?**
**A:** An Elastic IP is a **static public IP** address that doesn't change when you stop/start your instance.

Without it: Every time the EC2 instance reboots, it gets a new IP → DNS records break, SSH configs break, CI/CD scripts fail.

With Elastic IP: `3.222.210.129` stays the same forever → DNS always points to the right server.

**Q5: What is a Key Pair? How does SSH authentication work?**
**A:** A key pair is a set of cryptographic keys:
- **Public key** — Stored on the EC2 instance (in `~/.ssh/authorized_keys`)
- **Private key** — Kept on your laptop (`.pem` file)

When you `ssh ubuntu@3.222.210.129`, your laptop proves identity using the private key. No password needed — much more secure.

**Q6: How would you reduce costs on an EC2 instance?**
**A:**
1. **Right-size** — Use the smallest instance that works (ROI: `t3.small` not `t3.large`).
2. **Reserved Instances** — Commit to 1-3 years for ~40-60% savings.
3. **Spot Instances** — Up to 90% discount, but can be terminated with 2 min notice (good for CI/CD runners, not production).
4. **Auto-stop** — Shut down dev instances at night via Lambda.
5. **Monitor CPU credits** — `t3` instances can throttle if credits run out.

### EC2 Instance Families (Know for Interviews)

| Family | Type | Optimized For | Example Instances | Use Case |
|---|---|---|---|---|
| **T** (Burstable) | General | Variable workloads | `t3.micro`, `t3.small`, `t3.medium` | Dev servers, small apps (ROI) |
| **M** (General) | General | Balanced compute/memory | `m5.large`, `m6i.xlarge` | Production APIs, databases |
| **C** (Compute) | Compute | High CPU | `c5.large`, `c6i.2xlarge` | Batch processing, CI/CD runners, encoding |
| **R** (Memory) | Memory | High RAM | `r5.large`, `r6i.xlarge` | In-memory caches (Redis), analytics |
| **I** (Storage) | Storage | High IOPS | `i3.large`, `i3en.xlarge` | Databases (Cassandra, Elasticsearch) |
| **D** (Dense) | Storage | HDD throughput | `d2.xlarge` | Data warehousing, Hadoop |
| **P** (GPU) | Accelerated | GPU compute | `p3.2xlarge`, `p4d.24xlarge` | ML training, deep learning |
| **G** (Graphics) | Accelerated | GPU graphics | `g4dn.xlarge` | Video rendering, game streaming |
| **A** (ARM) | General | Cost-effective ARM | `a1.medium`, `m6g.large` | ARM workloads, 20% cheaper |

**Naming convention**: `t3.small` → `t` = family, `3` = generation, `small` = size.

**Q7: What are EC2 CPU Credits (T-family burstable)?**
**A:** T-family instances earn CPU credits when idle and spend them when bursting above baseline.

| Instance | Baseline CPU | Credits/hr | Max Credit Balance |
|---|---|---|---|
| `t3.micro` | 10% | 6 | 144 |
| `t3.small` | 20% | 12 | 288 |
| `t3.medium` | 20% | 24 | 576 |

If credits run out → CPU is throttled to baseline → app becomes slow.

**Two modes:**
- `standard` — Throttle when credits exhausted (safe, predictable cost).
- `unlimited` — Burst beyond credits, pay extra per vCPU-hour (risky for cost).

ROI uses `t3.small` in `standard` mode. Monitor via CloudWatch: `CPUCreditBalance` alarm.

**Q8: What is User Data in EC2?**
**A:** A bash script that runs **once** when the instance first boots. Used for initial setup.

```bash
#!/bin/bash
apt update && apt install -y docker.io docker-compose
systemctl enable docker
usermod -aG docker ubuntu
```

In ROI's Terraform:
```hcl
resource "aws_instance" "roi_server" {
  user_data = file("scripts/setup.sh")
}
```

User Data runs as `root` and logs to `/var/log/cloud-init-output.log` — check this file if the instance doesn't set up correctly.

---

## 📦 6. AWS S3

### What is it?
**Simple Storage Service** — Object storage that stores any amount of data. Files are stored as "objects" in "buckets."

### ROI's S3 Buckets

| Bucket | Purpose |
|---|---|
| `roi-platform-uploads-974387` | **Application data** — KYC documents, user uploads |
| `roi-platform-tf-state-974387` | **Terraform state** — infrastructure state file |

### Interview Questions (0–3 Years)

**Q1: What is S3? What is an Object vs a File System?**
**A:** S3 is object storage — fundamentally different from a file system.

| File System (EBS) | Object Storage (S3) |
|---|---|
| Hierarchical (folders) | Flat (prefix-based, folders are illusion) |
| Edit in place | Replace entire object |
| Attached to one server | Accessible from anywhere via HTTP |
| Limited size | Virtually unlimited |

In ROI, KYC uploads go to S3 (not the EC2 disk) because S3 is durable (99.999999999%), scalable, and accessible by any service.

**Q2: What is an S3 Bucket Policy vs IAM Policy?**
**A:**
| Bucket Policy | IAM Policy |
|---|---|
| Attached to the **bucket** | Attached to the **user/role** |
| Controls who can access THIS bucket | Controls what THIS user can access |
| Written in JSON, on the bucket | Written in JSON, on the IAM entity |

ROI uses **IAM policies** to grant the backend's IAM role `PutObject`/`GetObject` on `roi-platform-uploads-974387`. The bucket itself doesn't have a public policy.

**Q3: What are S3 Storage Classes?**
**A:**
| Class | Use Case | Cost |
|---|---|---|
| **Standard** | Frequently accessed (ROI uploads) | $$$ |
| **Standard-IA** | Infrequent access | $$ |
| **Glacier** | Archival (30-day retrieval) | $ |
| **Glacier Deep** | Long-term archival (12-hr retrieval) | ¢ |

ROI uses Standard for uploads (need instant access) and could use lifecycle rules to move old KYC docs to IA after 90 days.

**Q4: What is S3 Versioning? Why is it critical for Terraform state?**
**A:** Versioning keeps every version of every object. If you overwrite a file, the old version is preserved.

For `roi-platform-tf-state-974387`: If a Terraform apply corrupts state, you can restore the previous version. Without versioning, corrupted state = manual re-import of every resource.

**Q5: What is a Pre-signed URL?**
**A:** A temporary URL that grants access to a private S3 object without making it public.

In ROI, when a user uploads a KYC document:
1. Backend generates a pre-signed URL (valid for 15 minutes).
2. Frontend uploads directly to S3 using the URL.
3. URL expires — no permanent public access.

This offloads upload bandwidth from the backend to S3.

**Q6: How does ROI use S3 in its application code?**
**A:** The backend uses AWS SDK to interact with `roi-platform-uploads-974387`:
- `PutObject` — Upload KYC documents.
- `GetObject` — Retrieve documents for admin review.
- Environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET` configure access.

**Q7: How to create a Pre-signed URL? (with code)**
**A:** Here's the complete flow used in ROI for KYC document uploads:

**Backend — Generate pre-signed URL (Node.js + AWS SDK v3):**
```javascript
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({ region: 'us-east-1' });

// For UPLOADS (frontend → S3 directly)
async function getUploadUrl(fileName, contentType) {
  const command = new PutObjectCommand({
    Bucket: 'roi-platform-uploads-974387',
    Key: `kyc/${Date.now()}-${fileName}`,
    ContentType: contentType,
  });
  const url = await getSignedUrl(s3, command, { expiresIn: 900 }); // 15 min
  return url;
}

// For DOWNLOADS (view uploaded document)
async function getDownloadUrl(key) {
  const command = new GetObjectCommand({
    Bucket: 'roi-platform-uploads-974387',
    Key: key,
  });
  const url = await getSignedUrl(s3, command, { expiresIn: 3600 }); // 1 hour
  return url;
}
```

**Frontend — Upload using the pre-signed URL:**
```javascript
// 1. Get URL from backend
const { uploadUrl } = await fetch('/api/kyc/upload-url', {
  method: 'POST',
  body: JSON.stringify({ fileName: 'id-card.jpg', contentType: 'image/jpeg' })
}).then(r => r.json());

// 2. Upload directly to S3 (bypasses backend)
await fetch(uploadUrl, {
  method: 'PUT',
  body: file,
  headers: { 'Content-Type': 'image/jpeg' }
});
```

**Why pre-signed URLs?**
- **Backend offloading** — File goes directly from browser → S3 (doesn't consume backend bandwidth/memory).
- **Security** — URL expires after 15 minutes, no permanent public access.
- **Size limits** — S3 handles files up to 5 TB, backend doesn't need `client_max_body_size` increase.

**Q8: What is S3 Lifecycle Policy?**
**A:** Automatically transitions objects between storage classes or deletes them based on age.

```json
{
  "Rules": [{
    "ID": "Archive old KYC docs",
    "Status": "Enabled",
    "Transitions": [
      { "Days": 90, "StorageClass": "STANDARD_IA" },
      { "Days": 365, "StorageClass": "GLACIER" }
    ],
    "Expiration": { "Days": 2555 }  // Delete after 7 years
  }]
}
```

For ROI: KYC documents are accessed frequently for the first 90 days → move to IA → move to Glacier after 1 year → delete after 7 years (regulatory compliance).

---

## 🗄️ 7. AWS DynamoDB

### What is it?
**Fully managed NoSQL key-value database** by AWS. Scales automatically, no servers to manage.

### ROI's Usage
- **Table**: `roi-platform-tf-locks`
- **Purpose**: Terraform state locking (prevents concurrent applies)
- **NOT used** for application data (application uses PostgreSQL via Prisma)

### Interview Questions (0–3 Years)

**Q1: What is DynamoDB? How is it different from RDS?**
**A:**
| DynamoDB | RDS |
|---|---|
| NoSQL (key-value/document) | Relational (SQL) |
| Schema-less | Fixed schema |
| Scales horizontally (auto) | Scales vertically (bigger instance) |
| Pay per request or provisioned | Pay per instance hour |
| Best for: config, sessions, locks | Best for: structured data, joins |

ROI uses DynamoDB only for Terraform locking because it needs simple key-value storage with strong consistency.

**Q2: What is a Partition Key in DynamoDB?**
**A:** The partition key is the primary key that DynamoDB uses to distribute data across partitions.

For `roi-platform-tf-locks`:
- Partition key: `LockID`
- Value: The Terraform state file path

DynamoDB hashes the partition key to decide which physical partition stores the item. Good partition key = even distribution = good performance.

**Q3: What is the difference between On-Demand and Provisioned capacity?**
**A:**
| On-Demand | Provisioned |
|---|---|
| Pay per read/write request | Pay for reserved capacity (RCU/WCU) |
| Auto-scales | Manual scaling |
| Higher per-request cost | Lower per-request cost |
| Best for: unpredictable traffic | Best for: steady traffic |

ROI's lock table uses On-Demand because Terraform runs infrequently — paying per request is cheaper than reserving capacity.

**Q4: How does DynamoDB provide state locking for Terraform?**
**A:** When `terraform apply` starts:
1. It writes a **lock item** to `roi-platform-tf-locks` with its process ID.
2. DynamoDB uses **conditional writes** — if a lock already exists, the write fails.
3. The second Terraform process sees the lock and exits with "state locked" error.
4. When apply finishes, the lock item is deleted.

This is an implementation of a **distributed lock** using DynamoDB's strong consistency.

**Q5: Is DynamoDB free on AWS Free Tier?**
**A:** Yes — AWS Free Tier includes:
- 25 GB of storage
- 25 RCU (Read Capacity Units) and 25 WCU (Write Capacity Units)
- Enough for ~200 million requests/month

ROI's lock table uses almost nothing — just a few writes per Terraform run. Effectively free.

---

## 🔐 8. AWS IAM

### What is it?
**Identity and Access Management** — Controls WHO can do WHAT on which AWS resources.

### ROI's IAM Setup (`iam.tf`)
- IAM roles for EC2 (to access S3 without hardcoded keys)
- IAM policies following **least privilege** principle
- Service-linked roles for monitoring

### Interview Questions (0–3 Years)

**Q1: What is the difference between IAM Users, Roles, and Policies?**
**A:**
| Concept | What it Is | Example |
|---|---|---|
| **User** | A person or service with credentials | `anurag` (your AWS account) |
| **Role** | A set of permissions that can be assumed | `roi-ec2-role` (assumed by EC2) |
| **Policy** | A JSON document defining permissions | `AllowS3Upload` (PutObject on specific bucket) |

**Relationship**: A Policy is attached to a User or Role. A Role can be assumed by a service (EC2, Lambda) or another user.

**Q2: What is the Principle of Least Privilege?**
**A:** Give only the **minimum permissions** needed to perform a task — nothing more.

Bad:
```json
{ "Effect": "Allow", "Action": "s3:*", "Resource": "*" }
```

Good (ROI):
```json
{ "Effect": "Allow", "Action": ["s3:PutObject", "s3:GetObject"], "Resource": "arn:aws:s3:::roi-platform-uploads-974387/*" }
```

**Why?** If the backend is compromised, the attacker can only read/write to the uploads bucket — not delete everything in your AWS account.

**Q3: What is an IAM Role vs Access Keys?**
**A:**
| Access Keys | IAM Role |
|---|---|
| Long-lived credentials | Temporary credentials (auto-rotated) |
| Stored in `.env` files | Assigned to EC2 instance (no secrets to manage) |
| If leaked, attacker has permanent access | Credentials expire in 1-12 hours |
| Bad practice for production | AWS recommended best practice |

ROI currently uses access keys in Docker env vars but the ideal setup is an **Instance Profile** (IAM role attached to EC2).

**Q4: What is an IAM Policy Document? Explain the structure.**
**A:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",           // Allow or Deny
      "Action": ["s3:PutObject"],  // What action
      "Resource": "arn:aws:s3:::roi-platform-uploads-974387/*"  // On what resource
    }
  ]
}
```

Key elements:
- **Effect**: `Allow` or `Deny` (Deny always wins)
- **Action**: The API call (e.g., `s3:PutObject`, `ec2:TerminateInstances`)
- **Resource**: ARN of the specific resource
- **Condition**: Optional — restrict by IP, time, MFA, etc.

**Q5: What is MFA and why should it be enabled on the root account?**
**A:** MFA (Multi-Factor Authentication) requires two forms of identity:
1. Something you **know** (password)
2. Something you **have** (phone authenticator code)

The root account has **unlimited access** to everything in AWS. If compromised without MFA, an attacker can delete all resources, create expensive instances for crypto mining, and lock you out.

**Q6: What is an Instance Profile?**
**A:** An Instance Profile is a container for an IAM role that allows EC2 instances to assume that role automatically.

Instead of putting `AWS_ACCESS_KEY_ID` in the container's environment, you attach an Instance Profile with the right permissions → the AWS SDK on EC2 automatically gets temporary credentials.

**Q7: What is the difference between Inline Policies and Managed Policies?**
**A:**
| Inline Policy | Managed Policy |
|---|---|
| Embedded directly in a user/role | Standalone policy, can be attached to many users/roles |
| Deleted when the user/role is deleted | Exists independently |
| 1:1 relationship | Many-to-many relationship |
| Use for: unique, one-off permissions | Use for: standard, reusable permissions |

**Best practice**: Use **managed policies** (reusable). Use inline only when a permission is truly unique to one role.

AWS provides **AWS Managed Policies** (e.g., `AmazonS3ReadOnlyAccess`) and you can create **Customer Managed Policies**.

**Q8: How does IAM Policy Evaluation work? (Deny vs Allow)**
**A:** AWS evaluates policies in this order:

```
1. Explicit DENY    → Always wins (even if Allow exists)
2. Explicit ALLOW   → Grants access (if no Deny)
3. Implicit DENY    → Default — everything is denied unless explicitly allowed
```

**Example scenario:**
- Policy A: `Allow s3:*` on all buckets.
- Policy B: `Deny s3:DeleteObject` on all buckets.
- Result: User can read/write but **cannot delete** (Deny wins over Allow).

**Key rule**: If you ever need to revoke access quickly, add an explicit **Deny** — it overrides everything.

**Q9: What is a Permissions Boundary?**
**A:** A permissions boundary sets the **maximum permissions** a user or role can have. Even if a policy grants `s3:*`, the boundary can limit it to `s3:GetObject` only.

```
Effective permissions = Granted permissions ∩ Boundary
```

Use case: Let developers create their own IAM roles, but restrict them with a boundary so they can't escalate privileges (e.g., can't grant themselves admin access).

**Q10: What is Cross-Account Access?**
**A:** Allowing a user/service in Account A to access resources in Account B.

**How it works:**
1. Account B creates a role: `TrustRole` with trust policy allowing Account A.
2. Account A's user assumes `TrustRole` using `sts:AssumeRole`.
3. User gets temporary credentials for Account B.

```json
// Trust policy in Account B
{
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::123456789:root" },
  "Action": "sts:AssumeRole"
}
```

Use case: ROI's CI/CD (GitHub Actions) assumes a role in your AWS account to run Terraform. The trust relationship is between GitHub's OIDC provider and your IAM role.

---

## 🌐 9. AWS VPC

### What is it?
**Virtual Private Cloud** — Your own isolated network in AWS where you launch resources.

### ROI's VPC Setup
- Custom VPC with public subnets
- Internet Gateway for public internet access
- Security Groups acting as firewalls
- Route tables directing traffic

### Interview Questions (0–3 Years)

**Q1: What is a VPC? Why not just launch EC2 directly?**
**A:** A VPC is a logically isolated section of AWS cloud. Without it, all your resources would be on a shared network with other AWS customers.

VPC gives you:
- **Isolation** — Your own private network
- **Control** — Define IP ranges, subnets, route tables
- **Security** — Security groups + NACLs
- **Segmentation** — Public subnet (web servers) vs Private subnet (databases)

**Q2: What is a Subnet? Public vs Private?**
**A:**
| Public Subnet | Private Subnet |
|---|---|
| Has route to Internet Gateway | No direct internet access |
| Resources get public IPs | Resources only have private IPs |
| Use for: web servers, load balancers | Use for: databases, internal services |
| Example: EC2 with Nginx | Example: RDS PostgreSQL |

In ROI, the EC2 instance is in a **public subnet** (needs to serve web traffic). If we had RDS, it would go in a **private subnet**.

**Q3: What is a CIDR block? Explain `10.0.0.0/16`.**
**A:** CIDR (Classless Inter-Domain Routing) defines an IP address range.

`10.0.0.0/16` means:
- First 16 bits are fixed (`10.0.`)
- Remaining 16 bits can vary
- = 65,536 IP addresses (10.0.0.0 to 10.0.255.255)

Common VPC CIDRs:
- `/16` = 65,536 IPs (large VPC)
- `/24` = 256 IPs (single subnet)
- `/28` = 16 IPs (tiny subnet)

**Q4: What is an Internet Gateway?**
**A:** An Internet Gateway (IGW) connects your VPC to the public internet. Without it, nothing in your VPC can reach the internet, and the internet can't reach your VPC.

Steps:
1. Create IGW → Attach to VPC
2. Add route in route table: `0.0.0.0/0 → IGW`
3. EC2 in that subnet can now send/receive internet traffic

**Q5: What is the difference between Security Groups and NACLs?**
**A:**
| Security Group | NACL |
|---|---|
| **Instance level** firewall | **Subnet level** firewall |
| **Stateful** (return traffic auto-allowed) | **Stateless** (must allow return traffic explicitly) |
| Only **Allow** rules | **Allow** and **Deny** rules |
| Applied to specific instances | Applied to all instances in subnet |
| First line of defense | Second line of defense |

ROI uses Security Groups (simpler, sufficient for our setup). NACLs add defense-in-depth for enterprise environments.

**Q6: What is a NAT Gateway? When would you need one?**
**A:** A NAT Gateway lets instances in a **private subnet** access the internet (for updates, API calls) without being accessible FROM the internet.

Flow: Private EC2 → NAT Gateway (in public subnet) → Internet Gateway → Internet

ROI doesn't need one currently (single EC2 in public subnet), but if we moved the backend to a private subnet, we'd need NAT for npm installs and S3 API calls.

**Cost note**: NAT Gateway costs ~$32/month — significant for a budget project.

**Q7: 🚨 SITUATION: What happens if you delete the Internet Gateway?**
**A:** 
- **All public internet access stops** — no one can reach your website.
- EC2 instances can't reach the internet (no `apt update`, no `docker pull`).
- SSH access from your laptop also stops.
- **Internal VPC communication still works** (containers can talk to each other).

**Recovery:**
1. Create a new IGW: `aws ec2 create-internet-gateway`
2. Attach it to the VPC: `aws ec2 attach-internet-gateway --vpc-id vpc-xxx --internet-gateway-id igw-xxx`
3. Verify route table has `0.0.0.0/0 → igw-xxx`.

**Q8: 🚨 SITUATION: What happens if you delete the NAT Gateway?**
**A:**
- Instances in **private subnets** lose internet access.
- Instances in **public subnets** are NOT affected (they use IGW directly).
- Private instances can't: install packages, call AWS APIs, pull Docker images.
- Private instances CAN still: talk to other instances in the VPC, access S3 via VPC endpoint.

**Q9: 🚨 SITUATION: What happens if a Security Group allows `0.0.0.0/0` on port 22 (SSH)?**
**A:** **Every IP in the world can attempt SSH access to your server.** This is a critical security risk:
- Bots constantly scan for open SSH ports.
- Brute-force attacks will start within minutes.
- If your key pair is compromised, instant access.

**Fix:** Restrict SSH to your IP only:
```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["203.0.113.50/32"]  # Your IP only
}
```

**Q10: 🚨 SITUATION: You launched an EC2 instance but can't SSH into it. What do you check?**
**A:** Troubleshooting checklist (in order):

1. **Security Group** — Is port 22 open for your IP? (`0.0.0.0/0` for testing)
2. **Key Pair** — Are you using the correct `.pem` file? Permissions `chmod 400 key.pem`?
3. **Public IP** — Does the instance have a public IP or Elastic IP?
4. **Subnet** — Is it in a public subnet with route to Internet Gateway?
5. **NACL** — Is the Network ACL blocking port 22?
6. **Instance state** — Is it `running`? Check system status checks in console.
7. **OS firewall** — Is `ufw` or `iptables` blocking SSH inside the instance?
8. **Username** — Ubuntu = `ubuntu`, Amazon Linux = `ec2-user`, CentOS = `centos`.

```bash
ssh -i key.pem -v ubuntu@3.222.210.129
# -v flag shows verbose debug output
```

**Q11: 🚨 SITUATION: Two subnets in the same VPC can't communicate. Why?**
**A:** Check these:
1. **Route tables** — Each subnet needs a route for the other subnet's CIDR.
2. **NACLs** — Both inbound AND outbound rules must allow traffic (stateless!).
3. **Security Groups** — Source must allow the other subnet's CIDR or security group.
4. **CIDR overlap** — Subnets must have non-overlapping CIDR blocks.

**Q12: How to create a VPC manually in AWS Console? (Step-by-step)**
**A:**

```
Step 1: Create VPC
   → VPC Console → Create VPC
   → Name: roi-vpc
   → CIDR: 10.0.0.0/16

Step 2: Create Subnets
   → Public Subnet:  10.0.1.0/24  (AZ: us-east-1a)
   → Private Subnet: 10.0.2.0/24  (AZ: us-east-1b)

Step 3: Create Internet Gateway
   → Create IGW → Attach to roi-vpc

Step 4: Configure Route Tables
   → Public Route Table:
      → Add route: 0.0.0.0/0 → igw-xxx
      → Associate with Public Subnet
   → Private Route Table:
      → No internet route (or NAT Gateway)
      → Associate with Private Subnet

Step 5: Enable Auto-assign Public IP
   → Public Subnet → Edit → Enable auto-assign public IPv4

Step 6: Create Security Groups
   → Web-SG: Inbound 80, 443 from 0.0.0.0/0
   → SSH-SG: Inbound 22 from your IP
   → DB-SG:  Inbound 5432 from Web-SG only

Step 7: Launch EC2 in Public Subnet
   → Select roi-vpc → Public Subnet → Attach Web-SG + SSH-SG
```

**Q13: What is VPC Peering?**
**A:** A network connection between two VPCs that allows them to communicate using private IPs.

| Feature | VPC Peering |
|---|---|
| Crosses regions | Yes (inter-region peering) |
| Crosses accounts | Yes |
| Transitive? | **No** (A↔B and B↔C does NOT mean A↔C) |
| Cost | Free within same AZ, $0.01/GB cross-AZ |

Use case: Your production VPC peers with a monitoring VPC so Prometheus can scrape targets without going over the internet.

**Q14: What is a VPC Endpoint? Why use it instead of going through the internet?**
**A:** A VPC Endpoint lets you connect to AWS services (S3, DynamoDB) **privately** without going through the internet, NAT, or IGW.

| Type | Gateway Endpoint | Interface Endpoint |
|---|---|---|
| Services | S3, DynamoDB only | Almost all AWS services |
| Cost | **Free** | $0.01/hour + per GB |
| How | Route table entry | ENI in your subnet |

For ROI: A **Gateway Endpoint for S3** would let the backend upload KYC docs to S3 without internet traffic → faster, cheaper, more secure.

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
}
```

---

*— End of Part 2. Part 3 covers CI/CD, Observability & DevOps Practices →*


---

# Part 3 — CI/CD, Observability & DevOps Practices

---

## ⚙️ 10. GitHub Actions

### What is it?
GitHub's built-in **CI/CD platform** that automates workflows — build, test, deploy — triggered by Git events (push, PR, schedule).

### ROI's Workflows

| Workflow | Trigger | What it Does |
|---|---|---|
| `backend-ci.yml` | PR to main | Lint + test backend |
| `deploy-to-aws.yml` | Push to main | SSH into EC2, pull latest, rebuild containers |
| `terraform-deploy.yml` | Push to main (infra changes) | `terraform plan` → `apply` |
| `terraform-destroy.yml` | Manual dispatch | Tears down all Terraform resources |
| `drift-detection.yml` | Cron (daily) | Detects manual infra changes |

### Key Concepts

| Concept | What it Is |
|---|---|
| **Workflow** | A YAML file in `.github/workflows/` |
| **Job** | A set of steps that run on the same runner |
| **Step** | A single task (run command, use action) |
| **Runner** | The machine that executes jobs (GitHub-hosted or self-hosted) |
| **Secret** | Encrypted variable (e.g., AWS keys) stored in repo settings |
| **Environment** | Named target (staging, production) with protection rules |

### Interview Questions (0–3 Years)

**Q1: What is CI/CD? Explain CI vs CD.**
**A:**
| CI (Continuous Integration) | CD (Continuous Delivery/Deployment) |
|---|---|
| Automatically **build and test** on every commit | Automatically **deploy** to production |
| Catches bugs early | Reduces manual deployment effort |
| Runs on PRs | Runs on merge to main |
| Example: `backend-ci.yml` | Example: `deploy-to-aws.yml` |

CI = "Does it work?" → CD = "Ship it!"

**Q2: What is a GitHub Actions Workflow? Explain the YAML structure.**
**A:**
```yaml
name: Backend CI              # Workflow name
on:                            # Trigger
  pull_request:
    branches: [main]
jobs:                          # What to run
  test:
    runs-on: ubuntu-latest     # Runner OS
    steps:                     # Individual tasks
      - uses: actions/checkout@v4   # Clone code
      - run: npm ci                 # Install deps
      - run: npm test               # Run tests
```

Hierarchy: Workflow → Jobs → Steps

**Q3: What are GitHub Secrets? Why not put AWS keys in the YAML file?**
**A:** Secrets are encrypted environment variables stored in GitHub repo settings. They're exposed to workflows as `${{ secrets.AWS_ACCESS_KEY_ID }}`.

Never put secrets in YAML because:
- YAML files are committed to Git — anyone with repo access sees them.
- Git history is permanent — even if deleted, secrets remain in old commits.
- Secrets are **masked in logs** — GitHub replaces them with `***`.

**Q4: What is `runs-on`? GitHub-hosted vs Self-hosted runners?**
**A:**
| GitHub-hosted | Self-hosted |
|---|---|
| Managed by GitHub | Your own machine |
| Fresh VM every run | Persistent machine |
| Free (2000 min/month) | You pay for hardware |
| Limited customization | Full control |
| Use for: most projects | Use for: custom hardware, GPU, private network |

ROI uses `ubuntu-latest` (GitHub-hosted) — free and sufficient.

**Q5: What is a matrix strategy in GitHub Actions?**
**A:** Run the same job with different configurations simultaneously.

```yaml
strategy:
  matrix:
    node-version: [18, 20, 22]
    os: [ubuntu-latest, macos-latest]
```
This runs 6 jobs (3 versions × 2 OS) in parallel. Useful for testing compatibility.

**Q6: What is the difference between `push` and `pull_request` triggers?**
**A:**
| `push` | `pull_request` |
|---|---|
| Runs when code is pushed to branch | Runs when PR is opened/updated |
| Use for: deployment | Use for: testing before merge |
| Runs on the pushed code | Runs on the **merge result** |

ROI: `backend-ci.yml` triggers on `pull_request` (test before merge), `deploy-to-aws.yml` triggers on `push` to main (deploy after merge).

**Q7: What is `actions/checkout`? Why is it always the first step?**
**A:** `actions/checkout@v4` clones your repository into the runner's workspace. Without it, the runner has an empty directory — no code to build or test.

It's always step 1 because every subsequent step needs access to the code.

**Q8: How does ROI's deployment pipeline work end-to-end?**
**A:**
1. Developer pushes to feature branch → Opens PR.
2. `backend-ci.yml` triggers → Runs lint + tests → PR shows ✅ or ❌.
3. Code review → Merge to `main`.
4. `deploy-to-aws.yml` triggers → SSHs into EC2 → `git pull` → `docker compose up --build -d`.
5. If infra files changed → `terraform-deploy.yml` triggers → `plan` → `apply`.
6. Daily → `drift-detection.yml` runs → Alerts if someone changed infra manually.

**Q9: What are GitHub Actions Artifacts?**
**A:** Artifacts let you **persist files** between jobs or after a workflow completes. Jobs run on fresh VMs — without artifacts, files created in Job 1 are lost before Job 2 runs.

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/

# In another job:
- uses: actions/download-artifact@v4
  with:
    name: build-output
```

Use cases: Build output, test reports, coverage reports, Terraform plan files.

**Q10: What is dependency caching in GitHub Actions?**
**A:** Caching stores `node_modules` between runs so `npm ci` doesn't download everything every time.

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: ${{ runner.os }}-npm-
```

If `package-lock.json` hasn't changed → cache hit → `npm ci` takes 5 seconds instead of 30.

**Q11: What is `concurrency` in GitHub Actions?**
**A:** Prevents multiple workflow runs from executing simultaneously.

```yaml
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true
```

If you push 3 commits quickly:
- Without concurrency: 3 deployments run simultaneously → race conditions.
- With concurrency: Only the latest push deploys, previous runs are cancelled.

**Q12: What are Reusable Workflows?**
**A:** A workflow that other workflows can call, like a function.

```yaml
# .github/workflows/reusable-deploy.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string

# .github/workflows/deploy-prod.yml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production
```

Avoids duplicating deployment logic across staging and production workflows.

---

## 🤖 11. Dependabot

### What is it?
GitHub's automated **dependency update** tool. It checks your dependencies for newer versions and security patches, then opens PRs automatically.

### ROI's Config
```yaml
# .github/dependabot.yml
updates:
  - package-ecosystem: "npm"
    directory: "/backend"
    schedule:
      interval: "weekly"
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Interview Questions (0–3 Years)

**Q1: What is Dependabot and why is it important?**
**A:** Dependabot automatically opens PRs when dependencies have newer versions or known security vulnerabilities (CVEs).

**Why?** 95% of security breaches exploit **known, patched vulnerabilities**. If you're running an old version of a library with a published CVE, attackers have a ready-made exploit. Dependabot ensures you patch quickly.

**Q2: What is the difference between version updates and security updates?**
**A:**
| Version Updates | Security Updates |
|---|---|
| New features, bug fixes | Patches for CVEs |
| Scheduled (weekly/monthly) | Triggered immediately on CVE publication |
| Optional to merge | Critical to merge |
| Configured in `dependabot.yml` | Enabled by default |

**Q3: Why does ROI monitor both `npm` and `docker` ecosystems?**
**A:**
- **npm**: Backend dependencies (Express.js, Prisma, etc.) — JavaScript CVEs.
- **Docker**: Base images (`node:20-alpine`) — OS-level CVEs in Alpine Linux.

A vulnerability in the base image affects ALL containers built from it. Both layers need monitoring.

**Q4: What is a CVE?**
**A:** **Common Vulnerabilities and Exposures** — A standardized ID for a known security flaw.

Example: `CVE-2024-12345` — A specific vulnerability in a specific version of a library. Security databases track these, and tools like Dependabot match them against your dependencies.

**Q5: What is `package.json` vs `package-lock.json`?**
**A:**
| `package.json` | `package-lock.json` |
|---|---|
| Lists dependencies with **version ranges** | Lists **exact** versions of every dependency |
| `"express": "^4.18.0"` (any 4.x) | `"express": "4.18.2"` (exactly this) |
| Human-maintained | Auto-generated by npm |
| Defines what you WANT | Defines what you HAVE |
| Committed to Git | **Also committed to Git** |

**Why `package-lock.json` matters:**
Without it, `npm install` might install `express@4.19.0` on your machine but `express@4.18.2` on production → different behavior → bugs that only appear in production.

`npm ci` (used in CI/CD) **requires** `package-lock.json` and installs exact versions.

**Q6: What is Semantic Versioning (SemVer)?**
**A:** Version format: `MAJOR.MINOR.PATCH` (e.g., `4.18.2`)

| Part | When to Bump | Example |
|---|---|---|
| **MAJOR** (4.x.x) | Breaking changes | Removing an API endpoint |
| **MINOR** (x.18.x) | New features (backward compatible) | Adding a new endpoint |
| **PATCH** (x.x.2) | Bug fixes | Fixing a crash |

**Version ranges in package.json:**
- `^4.18.0` → Allows `4.x.x` (MINOR + PATCH updates) — **most common**
- `~4.18.0` → Allows `4.18.x` (PATCH updates only)
- `4.18.0` → Exact version (no updates)
- `*` → Any version (dangerous!)

**Q7: How does a Dependabot PR work end-to-end?**
**A:**
1. Dependabot checks npm registry for newer versions weekly.
2. Finds `express@4.18.2` → `express@4.19.0` available.
3. Creates a branch `dependabot/npm/express-4.19.0`.
4. Updates `package.json` and `package-lock.json`.
5. Opens a PR with changelog, release notes, and compatibility score.
6. `backend-ci.yml` runs tests on the PR automatically.
7. If tests pass → safe to merge. If they fail → dependency has a breaking change.

**Q8: What is `npm audit`? How is it different from Dependabot?**
**A:**
| `npm audit` | Dependabot |
|---|---|
| Manual — you run it | Automatic — runs on schedule |
| Shows vulnerabilities | Opens PRs to fix them |
| One-time check | Continuous monitoring |
| `npm audit fix` auto-patches | You merge the PR |

```bash
npm audit                  # Show vulnerabilities
npm audit fix              # Auto-fix compatible updates
npm audit fix --force       # Fix even if breaking (risky)
```

---

### 🏥 Health Endpoints (Bonus Section)

**Q9: What is a health check endpoint? How do you create one?**
**A:** A health endpoint returns the application's status — used by Docker, load balancers, and monitoring tools to know if the app is alive.

**Express.js Backend:**
```javascript
// Simple health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

// Deep health check (checks dependencies)
app.get('/health/ready', async (req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;  // DB check
    await redis.ping();                 // Redis check
    res.status(200).json({
      status: 'ok',
      database: 'connected',
      redis: 'connected',
      uptime: process.uptime()
    });
  } catch (err) {
    res.status(503).json({ status: 'error', error: err.message });
  }
});
```

**Two types of health checks:**
| Liveness (`/health`) | Readiness (`/health/ready`) |
|---|---|
| "Is the process running?" | "Can it serve traffic?" |
| Simple, fast | Checks DB, Redis, etc. |
| If fails: restart container | If fails: stop sending traffic |

**Docker Compose healthcheck:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 10s
```

**Nginx health check for upstream:**
```nginx
location /nginx-health {
  access_log off;
  return 200 'healthy';
  add_header Content-Type text/plain;
}
```

**Q10: What is a Liveness Probe vs Readiness Probe?**
**A:**
- **Liveness**: "Should I restart this container?" If the app is stuck in a deadlock, liveness fails → Docker restarts it.
- **Readiness**: "Should I send traffic to this container?" During startup (running migrations), readiness fails → no traffic until ready.

In Docker Compose, there's only one `healthcheck` (acts as liveness). In Kubernetes, you configure both separately.

---

## 📊 12. Prometheus

### What is it?
Open-source **metrics monitoring system** with a time-series database. It **pulls** (scrapes) metrics from your services at regular intervals.

### ROI's Setup
- Scrapes metrics from: backend, Node Exporter, Redis
- Stores 30 days of data
- Evaluates alert rules → sends to Alertmanager
- Config: `monitoring/prometheus.yml`

### Key Concepts

| Concept | Explanation |
|---|---|
| **Scrape** | Prometheus pulls metrics from targets every N seconds |
| **Target** | An endpoint exposing metrics (e.g., `backend:5000/metrics`) |
| **Time series** | A metric with a name, labels, and timestamped values |
| **PromQL** | Query language for Prometheus data |
| **Alert rule** | Condition that triggers an alert |

### Interview Questions (0–3 Years)

**Q1: What is Prometheus? Pull vs Push model?**
**A:**
| Pull (Prometheus) | Push (CloudWatch, Datadog) |
|---|---|
| Prometheus **fetches** metrics from targets | Apps **send** metrics to a collector |
| Prometheus controls scrape interval | App controls send interval |
| Easy to detect if target is down (scrape fails) | Hard to distinguish "no data" from "service down" |
| Simple for services — just expose `/metrics` | Requires SDK/agent in every service |

ROI uses Pull because it's simpler — backend just exposes an HTTP endpoint.

**Q2: What is a metric type? Name the 4 types.**
**A:**
| Type | Description | Example |
|---|---|---|
| **Counter** | Only goes up (or resets to 0) | `http_requests_total` |
| **Gauge** | Goes up and down | `memory_usage_bytes` |
| **Histogram** | Distributes values into buckets | `http_request_duration_seconds` |
| **Summary** | Like histogram but calculates percentiles | `request_latency_p99` |

**Q3: What is PromQL? Give an example.**
**A:** PromQL is Prometheus Query Language for querying time-series data.

Examples:
```promql
# Current CPU usage percentage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Request rate (requests per second over 5 minutes)
rate(http_requests_total[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Q4: What is a scrape interval? What's a good value?**
**A:** The interval at which Prometheus pulls metrics from targets. ROI uses `15s` (default).

- Too frequent (1s) → High CPU/storage, unnecessary granularity.
- Too infrequent (5m) → Miss short-lived spikes.
- `15s` is the industry standard for most production workloads.

**Q5: What is `rate()` vs `irate()` in PromQL?**
**A:**
| `rate()` | `irate()` |
|---|---|
| Average rate over the entire time range | Instant rate (last two data points only) |
| Smoother, better for alerting | Spiky, better for dashboards |
| `rate(http_requests_total[5m])` | `irate(http_requests_total[5m])` |

**Q6: What is a recording rule?**
**A:** Pre-computed PromQL queries that run at regular intervals and store results as new time series. Useful for expensive queries that many dashboards use.

Instead of 10 dashboards each running `rate(http_requests_total[5m])`, you record it once and query the pre-computed result.

**Q7: How does Prometheus handle high availability?**
**A:**
1. **Run two Prometheus instances** scraping the same targets (both have full data).
2. **Thanos/Cortex** — Long-term storage and global querying across instances.
3. **Federation** — Hierarchical setup where a global Prometheus scrapes from local ones.

ROI runs a single instance (budget setup). For HA, you'd add a second Prometheus.

**Q8: What is the difference between Prometheus and CloudWatch?**
**A:**
| Prometheus | CloudWatch |
|---|---|
| Open source, free | AWS managed, pay per metric |
| Self-hosted | Fully managed |
| Pull model | Push model |
| PromQL (powerful) | Limited query syntax |
| Works anywhere | AWS only |
| Community dashboards | Basic dashboards |

**Q9: 🚨 SITUATION: Prometheus goes down for 30 minutes. What happens?**
**A:**
- **No new metrics collected** during the 30 minutes (data gap).
- **Existing data is safe** (stored on disk/volume).
- **Alerts stop firing** — this is the biggest risk. You won't know if something breaks.
- **Grafana dashboards** show a gap in graphs.

**Mitigation:**
1. Run **two Prometheus instances** scraping the same targets (HA).
2. Use **Alertmanager HA** (gossip protocol between instances).
3. Monitor Prometheus itself with a **meta-monitor** (another Prometheus or an external service).

**Q10: What is the `up` metric in Prometheus?**
**A:** A built-in metric that Prometheus creates automatically for every scrape target.

| Value | Meaning |
|---|---|
| `up == 1` | Target is reachable and healthy |
| `up == 0` | Target is down or unreachable |

```promql
up{job="roi_backend"}   # Is the backend alive?
```

This is the **most basic and critical alert** you should have:
```yaml
- alert: TargetDown
  expr: up == 0
  for: 1m
  labels:
    severity: critical
```

**Q11: What is Remote Write in Prometheus?**
**A:** Remote Write sends metrics to a **long-term storage backend** outside Prometheus.

Prometheus stores data locally (default 15 days). For longer retention, you write to:
- **Thanos** — S3-backed long-term storage (popular)
- **Cortex/Mimir** — Grafana's scalable metrics backend
- **VictoriaMetrics** — Efficient time-series DB

```yaml
remote_write:
  - url: "http://thanos-receive:19291/api/v1/receive"
```

ROI doesn't use remote write (budget constraint), but production setups should for 90+ day retention.

**Q12: What is Prometheus Relabeling?**
**A:** Relabeling transforms labels **before** scraping or **before** storing. Used to:
- Add labels (environment, team)
- Drop high-cardinality labels
- Filter which targets to scrape

```yaml
relabel_configs:
  - source_labels: [__meta_docker_container_name]
    target_label: container_name
  - source_labels: [__name__]
    regex: "go_.*"    # Drop Go runtime metrics
    action: drop
```

---

## 📈 13. Grafana

### What is it?
Open-source **visualization and dashboarding** platform. Connects to data sources (Prometheus, Loki, Tempo) and displays metrics, logs, and traces in beautiful dashboards.

### ROI's Setup
- **Port**: 3001 (mapped from container 3000)
- **Data sources**: Prometheus (metrics), Loki (logs), Tempo (traces)
- **Provisioning**: Auto-configured via `monitoring/grafana/provisioning/`

### Interview Questions (0–3 Years)

**Q1: What is Grafana? How is it different from Prometheus?**
**A:** Prometheus = **collects and stores** metrics. Grafana = **visualizes** metrics.

Prometheus has a basic UI for queries, but Grafana provides rich dashboards with graphs, tables, alerts, and drill-downs. Grafana connects to Prometheus as a "data source."

**Q2: What is a Grafana Data Source?**
**A:** A backend that Grafana queries for data.

ROI's data sources:
| Data Source | Type | Purpose |
|---|---|---|
| Prometheus | Metrics | CPU, memory, request rates |
| Loki | Logs | Container log search |
| Tempo | Traces | Request tracing across services |

**Q3: What is Grafana Provisioning?**
**A:** Auto-configuring Grafana via files instead of the UI. At startup, Grafana reads YAML files from the provisioning directory and configures data sources and dashboards automatically.

Benefits: No manual setup when recreating the container. Infrastructure as Code for dashboards.

```
monitoring/grafana/provisioning/
├── datasources/
│   └── datasources.yml    # Auto-add Prometheus, Loki, Tempo
└── dashboards/
    └── dashboards.yml     # Auto-import dashboard JSON files
```

**Q4: What are Grafana Variables?**
**A:** Dynamic values in dashboards that let you filter data. Example: a dropdown to select `container_name` → all panels filter by that container.

Makes dashboards reusable — one dashboard for all services, just switch the variable.

**Q5: What is the difference between Grafana Alerts and Prometheus Alerts?**
**A:**
| Prometheus Alerts | Grafana Alerts |
|---|---|
| Defined in YAML (`alert-rules.yml`) | Defined in Grafana UI or provisioning |
| Processed by Alertmanager | Processed by Grafana |
| Better for Ops teams | Better for mixed teams |
| More mature, battle-tested | Unified with dashboards |

ROI uses Prometheus alert rules → Alertmanager → notifications. This is the standard production pattern.

**Q6: How would you create a dashboard showing backend health?**
**A:** Panels I'd add:
1. **Request Rate** — `rate(http_requests_total[5m])` → Graph
2. **Error Rate** — `rate(http_requests_total{status=~"5.."}[5m])` → Graph
3. **Latency P95** — `histogram_quantile(0.95, ...)` → Graph
4. **CPU Usage** — `node_cpu_seconds_total` → Gauge
5. **Memory Usage** — `container_memory_usage_bytes` → Gauge
6. **Container Status** — `up` metric → Stat panel (1=UP, 0=DOWN)

**Q7: How to export/import Grafana dashboards as JSON?**
**A:** Grafana dashboards are stored as JSON. You can:

```bash
# Export: Dashboard → Share → Export → Save to file
# Import: Dashboards → Import → Upload JSON file

# Or via API:
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
  http://localhost:3001/api/dashboards/uid/abc123 \
  > dashboard.json
```

In ROI, dashboards are **provisioned** from JSON files — if Grafana container is recreated, dashboards auto-load.

**Q8: What are Grafana Annotations?**
**A:** Annotations are **vertical markers** on graphs that show when events happened.

Examples:
- "Deploy v1.2.3" marker on the timeline → correlate deploys with metric changes.
- "Alert fired" marker → see when issues started.

Can be added manually, via API, or auto-generated from alert rules.

**Q9: What is the difference between a Panel, Row, and Dashboard?**
**A:**
- **Panel** — A single visualization (graph, table, gauge, stat).
- **Row** — A collapsible group of panels.
- **Dashboard** — A collection of rows and panels.

Organization: Dashboard → Rows → Panels.

**Q10: What is a Grafana Alert Contact Point?**
**A:** Where alerts are sent. Grafana supports:
- **Email** — SMTP configuration
- **Slack** — Webhook URL
- **PagerDuty** — Integration key
- **Webhook** — Any HTTP endpoint
- **Telegram** — Bot token + chat ID

ROI routes alerts through Alertmanager → which then sends to configured channels.

---

## 📝 14. Loki

### What is it?
**Log aggregation system** by Grafana Labs. Like Prometheus but for logs. It indexes **labels** (not full text), making it highly efficient.

### ROI's Setup
- Receives logs from Promtail
- Stores container logs
- Queryable from Grafana using **LogQL**

### Interview Questions (0–3 Years)

**Q1: What is Loki? How is it different from Elasticsearch?**
**A:**
| Loki | Elasticsearch (ELK) |
|---|---|
| Indexes **labels only** | Indexes **full text** |
| Very low resource usage | High CPU and memory |
| Uses LogQL | Uses Lucene/KQL |
| Perfect for: containers, cost-sensitive | Perfect for: complex text search |
| Grafana native | Needs Kibana |

ROI uses Loki because our `t3.small` can't afford Elasticsearch's memory requirements. Loki uses ~100 MB RAM vs Elasticsearch's ~2 GB minimum.

**Q2: What is LogQL?**
**A:** Loki's query language. Like PromQL but for logs.

```logql
# All backend error logs
{container_name="roi_backend"} |= "error"

# JSON parsed logs where status is 500
{container_name="roi_backend"} | json | status = 500

# Count errors per minute
count_over_time({container_name="roi_backend"} |= "error" [1m])
```

**Q3: How does Loki differ from Prometheus in data model?**
**A:**
| Prometheus | Loki |
|---|---|
| Stores **numbers** (metrics) | Stores **text** (log lines) |
| Time series with labels | Log streams with labels |
| PromQL for queries | LogQL for queries |
| Answers: "How many errors?" | Answers: "What was the error message?" |

They complement each other: Prometheus tells you something is wrong, Loki tells you what went wrong.

**Q4: What is a Log Stream in Loki?**
**A:** A stream is a unique combination of labels. Each unique label set creates a separate stream.

```
{container_name="roi_backend", job="docker"} → Stream 1
{container_name="roi_frontend", job="docker"} → Stream 2
```

Too many streams (high cardinality) = poor performance. Never use high-cardinality labels like `user_id` or `request_id` as Loki labels.

**Q5: What is Log Retention and how does Loki handle it?**
**A:** How long logs are kept before deletion. In ROI's config:
```yaml
limits_config:
  retention_period: 168h   # 7 days
```
After 7 days, Loki deletes old log chunks to save disk space. On a `t3.small`, disk is limited — 7 days is a practical balance.

**Q6: How do you search for a specific error in production logs?**
**A:** In Grafana → Explore → Select Loki data source:
```logql
{container_name="roi_backend"} |= "TypeError" | json
```
This finds all log lines containing "TypeError" from the backend container and parses them as JSON for structured viewing.

### 📡 Centralized Logging (Bonus)

**Q7: What is Centralized Logging? Why not just read logs from each container?**
**A:** Centralized logging collects logs from ALL services into a single searchable location.

| Local Logs | Centralized Logs |
|---|---|
| `docker logs roi_backend` | Grafana → Loki → all containers |
| Must SSH into server | Access from browser |
| Lost when container recreates | Persisted to storage |
| No correlation across services | Search all services at once |
| No alerting on log patterns | Alert on errors, patterns |

**Popular stacks:**
| Stack | Components | Best For |
|---|---|---|
| **PLG** (ROI uses this) | Promtail + Loki + Grafana | Lightweight, cost-effective |
| **ELK** | Elasticsearch + Logstash + Kibana | Full-text search, complex queries |
| **EFK** | Elasticsearch + Fluentd + Kibana | Kubernetes-native |
| **CloudWatch** | AWS native | AWS-only, no extra infra |

**Q8: What is High Cardinality in Loki? Why is it dangerous?**
**A:** Cardinality = the number of unique label combinations. High cardinality = too many streams.

**Bad (high cardinality):**
```yaml
labels:
  user_id: "12345"     # Millions of unique values = millions of streams
  request_id: "abc"    # Every request creates a new stream
```

**Good (low cardinality):**
```yaml
labels:
  container_name: "roi_backend"  # ~12 unique values
  level: "error"                  # 4 values: debug, info, warn, error
```

**Rule**: Labels should have < 100 unique values. Put high-cardinality data in the log line itself, not in labels.

---

## 📤 15. Promtail

### What is it?
**Log shipping agent** by Grafana Labs. It reads logs from Docker containers and sends them to Loki.

### ROI's Setup
- Reads from Docker socket (`/var/run/docker.sock`)
- Adds labels (`container_name`, `job`)
- Ships to Loki at `http://loki:3100`

### Interview Questions (0–3 Years)

**Q1: What is Promtail? Why is it needed?**
**A:** Loki doesn't collect logs — it only stores and queries them. Promtail is the agent that:
1. **Discovers** containers via Docker socket.
2. **Reads** their log files.
3. **Labels** them (container name, host, etc.).
4. **Ships** them to Loki.

It's the "Prometheus" for Loki — Prometheus scrapes metrics, Promtail ships logs.

**Q2: What is the Docker socket and why does Promtail mount it?**
**A:** `/var/run/docker.sock` is the Unix socket that the Docker daemon listens on. It's the Docker API endpoint.

Promtail mounts it **read-only** to:
- Discover all running containers.
- Read their log files from `/var/lib/docker/containers/`.
- Auto-label logs with container metadata.

**Q3: What are Pipeline Stages in Promtail?**
**A:** Processing steps that transform logs before sending to Loki:
- **docker** — Parse Docker JSON log format.
- **regex** — Extract fields using regex.
- **labels** — Add labels from extracted fields.
- **timestamp** — Set the log timestamp.
- **output** — Select which field is the log line.

**Q4: What is the difference between Promtail, Fluentd, and Filebeat?**
**A:**
| Promtail | Fluentd | Filebeat |
|---|---|---|
| Grafana Labs | CNCF | Elastic |
| Ships to **Loki** | Ships anywhere | Ships to **Elasticsearch** |
| Lightest (~30 MB RAM) | Moderate (~100 MB) | Light (~50 MB) |
| Label-based | Plugin-based | Module-based |

ROI uses Promtail because we use Loki — they're purpose-built to work together.

**Q5: What is a Promtail Scrape Config?**
**A:** Defines WHERE Promtail looks for logs and HOW to process them.

```yaml
scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock  # Discover containers
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        target_label: 'container_name'     # Add container name as label
```

`docker_sd_configs` = Docker Service Discovery — auto-discovers all running containers.

**Q6: What is Grafana Alloy? Should I use it instead of Promtail?**
**A:** Grafana Alloy is the **successor to Promtail**. It's a unified agent that collects metrics, logs, AND traces (replaces Promtail + Node Exporter + OTel Collector).

| Promtail | Alloy |
|---|---|
| Logs only | Logs + Metrics + Traces |
| Loki-specific | Vendor-neutral |
| Simple config | More complex but powerful |
| Still maintained | Recommended for new projects |

ROI uses Promtail (simpler). New projects should consider Alloy.

**Q7: What happens if Promtail can't reach Loki?**
**A:** Promtail has a **WAL (Write-Ahead Log)** buffer. It stores logs locally and retries sending when Loki is back up. No log loss during temporary Loki downtime.

If the buffer fills up (disk full), oldest logs are dropped. Monitor Promtail's `promtail_sent_bytes_total` metric.

---

## 🔍 16. Tempo

### What is it?
**Distributed tracing backend** by Grafana Labs. It stores and queries traces — the journey of a request across services.

### ROI's Setup
- Receives traces via **OTLP** (OpenTelemetry Protocol) on ports 4317 (gRPC) and 4318 (HTTP).
- Queryable from Grafana.

### Key Concepts

| Concept | Explanation |
|---|---|
| **Trace** | The full journey of a request (e.g., user click → API → DB → response) |
| **Span** | A single operation within a trace (e.g., "DB query took 50ms") |
| **Trace ID** | Unique identifier that links all spans in a request |
| **OTLP** | OpenTelemetry Protocol — standard for sending traces |

### Interview Questions (0–3 Years)

**Q1: What is Distributed Tracing? Why is it needed?**
**A:** Tracing tracks a request as it flows through multiple services. In a monolith, a stack trace shows everything. In microservices, one request touches many services — tracing connects the dots.

Example in ROI: User uploads KYC → Backend receives → Validates → Uploads to S3 → Saves to DB → Returns response. A trace shows each step with timing.

**Q2: What is the difference between a Trace and a Span?**
**A:**
- **Trace** = The complete request journey (like a tree).
- **Span** = A single node in that tree (one operation).

```
Trace: "POST /api/kyc/upload"
├── Span: "Validate JWT" (2ms)
├── Span: "Parse multipart form" (5ms)
├── Span: "Upload to S3" (150ms)
├── Span: "Save to PostgreSQL" (20ms)
└── Span: "Return response" (1ms)
Total: 178ms
```

**Q3: What is OpenTelemetry (OTel)?**
**A:** A vendor-neutral observability framework that provides APIs, SDKs, and tools for:
- **Traces** — Request flows
- **Metrics** — Numbers over time
- **Logs** — Text events

ROI uses OTel SDK in the backend to send traces to Tempo via OTLP protocol. If we switch from Tempo to Jaeger tomorrow, we only change the endpoint — not the code.

**Q4: What are the Three Pillars of Observability?**
**A:**
| Pillar | Tool in ROI | Question it Answers |
|---|---|---|
| **Metrics** | Prometheus | "How many errors per minute?" |
| **Logs** | Loki | "What was the error message?" |
| **Traces** | Tempo | "Where exactly did the request fail?" |

All three are needed. Metrics alert you, logs explain the error, traces pinpoint the location.

**Q5: What is the difference between Tempo and Jaeger?**
**A:**
| Tempo | Jaeger |
|---|---|
| Grafana Labs | Uber/CNCF |
| No indexing (object store) | Indexes in Elasticsearch/Cassandra |
| Very low cost | Higher storage cost |
| Integrated with Grafana | Standalone UI |
| Search by Trace ID or LogQL | Full search capabilities |

ROI uses Tempo because it's lightweight and integrates natively with Grafana, Loki, and Prometheus.

**Q6: How do you correlate logs with traces?**
**A:** Include the `trace_id` in log lines. In Grafana, clicking a trace ID in Loki takes you to the trace in Tempo, and vice versa.

```json
{"level":"error", "msg":"S3 upload failed", "trace_id":"abc123"}
```

Loki log → click `trace_id` → Tempo shows the full request flow → identify which span failed.

**Q7: What is Sampling in Tracing?**
**A:** In production, tracing EVERY request creates too much data. Sampling selects a subset:

| Strategy | How | Use Case |
|---|---|---|
| **Head-based** | Decide at the START of request (random %) | Simple, consistent |
| **Tail-based** | Decide at the END (keep errors, slow requests) | Better, captures important traces |
| **Rate limiting** | Keep N traces per second | Predictable cost |

```javascript
// Head-based: 10% sampling
const sampler = new TraceIdRatioBased(0.1);
```

**Tail-based is better** because it always keeps traces with errors or high latency — the ones you actually need to debug.

**Q8: What is a Service Graph?**
**A:** A visual map showing how services connect and communicate, auto-generated from trace data.

```
Nginx → Backend → PostgreSQL
                 → Redis
                 → S3
```

Grafana's Tempo plugin can generate service graphs. Shows:
- Which services call which.
- Request rates between services.
- Error rates per connection.
- Latency per hop.

**Q9: What are Span Attributes?**
**A:** Key-value pairs attached to spans providing context:

```javascript
span.setAttribute('http.method', 'POST');
span.setAttribute('http.url', '/api/kyc/upload');
span.setAttribute('http.status_code', 200);
span.setAttribute('user.id', '12345');  // Custom attribute
```

Attributes help you filter and search traces: "Show me all traces where `http.status_code = 500`."

**Q10: 🚨 SITUATION: An API endpoint is slow. How do you debug it with tracing?**
**A:**
1. Find the trace for the slow request (search by endpoint, time range, duration).
2. Look at the **waterfall view** — which span took the longest?
3. Common findings:
   - DB query span = 2 seconds → Missing index, N+1 query.
   - S3 upload span = 5 seconds → Large file, network issue.
   - External API span = 3 seconds → Timeout needed, add caching.
4. Fix the bottleneck → verify with a new trace.

---

## 🚨 17. Alertmanager

### What is it?
Handles **alert routing, deduplication, grouping, and silencing** for Prometheus alerts.

### ROI's Setup
- Receives alerts from Prometheus.
- Groups related alerts.
- Routes to notification channels (email, Slack, PagerDuty).

### Interview Questions (0–3 Years)

**Q1: What is Alertmanager? Why not just alert directly from Prometheus?**
**A:** Prometheus evaluates alert rules and fires alerts, but it doesn't handle:
- **Grouping** — 100 instances down = 1 alert, not 100.
- **Deduplication** — Same alert doesn't fire multiple times.
- **Silencing** — Mute alerts during maintenance.
- **Routing** — Critical alerts → PagerDuty, warnings → Slack.
- **Inhibition** — If the entire cluster is down, suppress individual service alerts.

**Q2: What is an Alert Rule in Prometheus?**
**A:**
```yaml
- alert: HighMemoryUsage
  expr: container_memory_usage_bytes > 1.5e+9  # >1.5 GB
  for: 5m                                       # Must be true for 5 min
  labels:
    severity: warning
  annotations:
    summary: "Container memory > 1.5 GB"
```

- `expr` — PromQL condition.
- `for` — Prevents flapping (must be true for 5 minutes continuously).
- `labels.severity` — Used by Alertmanager for routing.

**Q3: What is alert grouping?**
**A:** Combining related alerts into a single notification.

Without grouping: If 5 containers go down simultaneously, you get 5 separate alerts.
With grouping (`group_by: [alertname]`): You get 1 notification listing all 5 containers.

**Q4: What is a Silence in Alertmanager?**
**A:** A temporary mute for specific alerts. Used during planned maintenance.

Example: You're upgrading the database and expect it to be down for 30 minutes. Create a silence for `DatabaseDown` alert for 30 minutes → no false alerts during maintenance.

**Q5: What is the difference between `warning` and `critical` severity?**
**A:**
| Warning | Critical |
|---|---|
| Something is degraded | Something is broken |
| Route to: Slack/email | Route to: PagerDuty/phone call |
| Example: Memory at 80% | Example: Service down |
| Action: investigate soon | Action: investigate NOW |

**Q6: 🚨 SITUATION: Alert storm — 50 alerts fire at once. What do you do?**
**A:**
1. **Don't panic** — most are likely cascading from one root cause.
2. **Check grouping** — Alertmanager should group related alerts. If not, fix `group_by`.
3. **Find root cause** — Usually one critical alert caused the others. Check `critical` severity first.
4. **Silence noise** — Create a silence for the cascading alerts while you fix the root cause.
5. **Add inhibition rules** — Prevent cascading alerts in the future:

```yaml
inhibit_rules:
  - source_match:
      severity: critical
      alertname: NodeDown
    target_match:
      severity: warning
    equal: ['instance']
```

This says: If `NodeDown` (critical) fires, suppress all `warning` alerts for the same instance.

**Q7: What is an Alertmanager Webhook Receiver?**
**A:** Sends alert notifications to any HTTP endpoint as a JSON POST.

```yaml
receivers:
  - name: 'custom-webhook'
    webhook_configs:
      - url: 'https://your-api.com/alerts'
        send_resolved: true  # Also notify when alert resolves
```

Use case: Trigger a Lambda function, create a Jira ticket, post to Discord, send SMS via Twilio.

**Q8: What is `group_wait`, `group_interval`, and `repeat_interval`?**
**A:**
| Setting | What it Does | ROI Value |
|---|---|---|
| `group_wait` | Wait time before sending the first alert (to collect more) | `30s` |
| `group_interval` | Wait time before sending NEW alerts for an existing group | `5m` |
| `repeat_interval` | Wait time before re-sending an unresolved alert | `4h` |

Without these, you'd get spammed with the same alert every 15 seconds.

---

## 🖥️ 18. Node Exporter

### What is it?
Prometheus exporter that exposes **host-level hardware and OS metrics** — CPU, memory, disk, network.

### ROI's Setup
Runs as a container with access to host's `/proc`, `/sys`, and `/` filesystems.

### Interview Questions (0–3 Years)

**Q1: What is Node Exporter? What metrics does it provide?**
**A:** Node Exporter exposes Linux host metrics to Prometheus:
- **CPU**: `node_cpu_seconds_total` — usage per core per mode (user, system, idle)
- **Memory**: `node_memory_MemAvailable_bytes` — free memory
- **Disk**: `node_filesystem_avail_bytes` — free disk space
- **Network**: `node_network_receive_bytes_total` — network traffic

Without it, Prometheus only knows about container metrics, not the underlying EC2 host.

**Q2: Why does Node Exporter mount `/proc` and `/sys`?**
**A:** `/proc` and `/sys` are virtual filesystems that expose kernel information. Node Exporter reads:
- `/proc/stat` → CPU stats
- `/proc/meminfo` → Memory stats
- `/sys/class/net/` → Network interface stats

It mounts them **read-only** (`:ro`) for security.

**Q3: What is the `pid: host` setting in the compose file?**
**A:** `pid: host` gives the container access to the host's process namespace. Node Exporter needs this to see ALL processes on the host (not just container processes) to report accurate CPU metrics.

**Q4: What is cAdvisor? When to use it instead of Node Exporter?**
**A:**
| Node Exporter | cAdvisor |
|---|---|
| **Host-level** metrics (entire machine) | **Container-level** metrics (per container) |
| CPU, memory, disk of the HOST | CPU, memory, network PER CONTAINER |
| Runs as a container or binary | Runs as a container |
| Built by Prometheus team | Built by Google |

ROI could add cAdvisor to see per-container memory usage: "Is the backend or Prometheus eating all the RAM?"

**Q5: What is the Textfile Collector?**
**A:** A Node Exporter feature that reads custom metrics from text files.

```bash
# Write custom metric to a file
echo 'backup_last_success_timestamp 1714000000' > /metrics/backup.prom
```

Node Exporter reads `/metrics/*.prom` and exposes the metrics to Prometheus. Used for: backup timestamps, deployment versions, custom business metrics.

**Q6: What key Node Exporter metrics should you always monitor?**
**A:**
```promql
# Disk space < 10% remaining (critical for ROI's small EC2)
(node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1

# Memory usage > 90%
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9

# CPU sustained > 80% for 10 minutes
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[10m])) * 100) > 80

# System load (should be < number of CPUs)
node_load1 > 2  # ROI has 2 vCPUs
```

---

## 🗃️ 19. Redis

### What is it?
**In-memory key-value data store** used for caching, session management, and queues.

### ROI's Setup
```yaml
redis-server --maxmemory 128mb --maxmemory-policy allkeys-lru --appendonly yes
```
- **128 MB** memory limit (budget constraint on `t3.small`)
- **LRU eviction** — removes least recently used keys when full
- **AOF persistence** — data survives restarts

### Interview Questions (0–3 Years)

**Q1: What is Redis? Why use it instead of just querying the database?**
**A:** Redis stores data in **RAM** (nanosecond access) vs PostgreSQL on **disk** (millisecond access). That's ~1000x faster.

Use cases in ROI:
- Cache frequently accessed data (user sessions, config).
- Reduce database load (fewer queries = DB stays fast).
- Rate limiting (count requests per IP in memory).

**Q2: What are Redis Eviction Policies? What is `allkeys-lru`?**
**A:** When Redis reaches `maxmemory`, it needs to decide which keys to remove:

| Policy | Behavior |
|---|---|
| `noeviction` | Return error on write (don't remove anything) |
| `allkeys-lru` | Remove **least recently used** key from ALL keys |
| `volatile-lru` | Remove LRU from keys with TTL set |
| `allkeys-random` | Remove random key |
| `volatile-ttl` | Remove key closest to expiration |

ROI uses `allkeys-lru` — the most practical policy. Rarely accessed data is evicted first.

**Q3: What is Redis Persistence? AOF vs RDB?**
**A:**
| RDB (Snapshotting) | AOF (Append Only File) |
|---|---|
| Point-in-time snapshot | Logs every write operation |
| Fast recovery | Slower recovery (replay log) |
| Possible data loss (since last snapshot) | Minimal data loss (at most 1 second) |
| Less disk I/O | More disk I/O |

ROI uses AOF (`appendonly yes`) to minimize data loss on container restarts.

**Q4: What is a Cache Miss vs Cache Hit?**
**A:**
- **Cache Hit**: Data found in Redis → return immediately (fast ✅).
- **Cache Miss**: Data NOT in Redis → query PostgreSQL → store in Redis → return (slow first time, fast next time ✅).

Pattern:
```
Request → Check Redis → Hit? → Return
                       → Miss? → Query DB → Store in Redis → Return
```

**Q5: What is the difference between Redis and Memcached?**
**A:**
| Redis | Memcached |
|---|---|
| Rich data structures (lists, sets, hashes) | Simple key-value only |
| Persistence (AOF/RDB) | No persistence |
| Single-threaded (atomic ops) | Multi-threaded |
| Pub/Sub, Lua scripting | Basic caching only |
| Replication + Sentinel | Client-side sharding |

Redis is the modern default. Memcached only wins when you need raw multi-threaded performance for simple caching.

**Q6: How would you monitor Redis health?**
**A:**
- **Healthcheck**: `redis-cli ping` → returns `PONG` if alive.
- **Metrics**: `INFO` command exposes hits, misses, memory usage, connected clients.
- **Key metrics to watch**: `hit_rate` (should be >90%), `used_memory`, `evicted_keys`.

ROI's healthcheck in compose:
```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 3s
  retries: 3
```

**Q7: What is Redis TTL (Time To Live)?**
**A:** TTL sets an **expiration time** on a key. After the TTL expires, Redis deletes the key automatically.

```bash
SET session:user123 "data" EX 3600   # Expires in 1 hour
TTL session:user123                    # Returns remaining seconds
PERSIST session:user123                # Remove expiration
```

Use case: Session tokens (expire after 24 hours), OTP codes (expire after 5 minutes), cached API responses (expire after 15 minutes).

**Q8: What is Redis Pub/Sub?**
**A:** A messaging system where publishers send messages to channels, and subscribers listen.

```javascript
// Publisher
await redis.publish('notifications', JSON.stringify({ type: 'kyc_approved', userId: 123 }));

// Subscriber
redis.subscribe('notifications', (message) => {
  const data = JSON.parse(message);
  sendEmail(data.userId);
});
```

Use case: Real-time notifications, chat messages, event broadcasting between microservices.

**Q9: What is Redis Pipelining?**
**A:** Send multiple commands to Redis in one round trip instead of one-by-one.

```javascript
// Without pipeline: 100 round trips
for (let i = 0; i < 100; i++) {
  await redis.set(`key:${i}`, `value:${i}`);  // Each is a network round trip
}

// With pipeline: 1 round trip
const pipeline = redis.pipeline();
for (let i = 0; i < 100; i++) {
  pipeline.set(`key:${i}`, `value:${i}`);
}
await pipeline.exec();  // All 100 commands in one batch
```

Speed improvement: **10-50x faster** for bulk operations.

**Q10: Redis Cluster vs Redis Sentinel — what's the difference?**
**A:**
| Sentinel | Cluster |
|---|---|
| **High availability** (automatic failover) | **Scalability** (data sharding) |
| 1 master + N replicas | Multiple masters, each with replicas |
| All data on one master | Data split across masters |
| Use for: HA without scaling | Use for: data too large for one machine |

ROI uses a single Redis instance (2 GB memory is enough). Sentinel would be the next step for HA.

**Q11: 🚨 SITUATION: Redis is using 100% of `maxmemory`. What happens?**
**A:** Depends on the eviction policy:
- `allkeys-lru` (ROI): Oldest unused keys are evicted to make room → app keeps working but cache hit rate drops.
- `noeviction`: Redis returns errors on write operations → app crashes if not handled.

**Debug:**
```bash
redis-cli INFO memory          # Check used_memory vs maxmemory
redis-cli INFO stats            # Check evicted_keys count
redis-cli --bigkeys             # Find the largest keys consuming memory
redis-cli MEMORY USAGE mykey    # Check size of specific key
```

---

## 🔒 20. SOPS (Secrets OPerationS)

### What is it?
**Encrypted secrets management** tool by Mozilla. Encrypts secret files so they can be safely committed to Git.

### ROI's Setup (age encryption)
- Encrypts `.env.prod` files into `.env.enc`.
- Uses `age` for key management (asymmetric encryption) instead of AWS KMS to reduce cloud vendor lock-in and costs.
- The private key is stored securely in GitHub Secrets (`SOPS_AGE_KEY`) and never committed to the repository.

### Interview Questions (0–3 Years)

**Q1: What is SOPS? Why not just use `.gitignore` for secrets?**
**A:** `.gitignore` prevents committing secrets but creates a problem: How do you share secrets with the team or CI/CD?

SOPS encrypts the secret values (not keys) in the file:
```yaml
database_url: ENC[AES256_GCM,data:abc123...]  # Encrypted
database_host: "localhost"                      # Not encrypted (not sensitive)
```

Benefits:
- Secrets are in Git (version controlled, reviewable).
- Only people/services with the KMS key can decrypt.
- You can see WHAT changed in a diff (key names visible), just not the values.

**Q2: How does SOPS encryption work?**
**A:**
1. SOPS generates a unique **data key**.
2. Data key encrypts the secret values.
3. The data key itself is encrypted with **AWS KMS** master key.
4. Both encrypted values + encrypted data key are stored in the file.

To decrypt: SOPS calls KMS to decrypt the data key → uses data key to decrypt values.

**Q3: What is the difference between SOPS and HashiCorp Vault?**
**A:**
| SOPS | Vault |
|---|---|
| File-based encryption | Centralized secret server |
| Static secrets in Git | Dynamic secrets (auto-rotated) |
| Simple, no infra needed | Requires running a server |
| Good for: small teams | Good for: enterprise |

ROI uses SOPS because it's zero-infrastructure — just a config file and KMS key.

**Q4: What is AWS KMS?**
**A:** Key Management Service — AWS manages encryption keys. You never see the raw key. You call KMS to encrypt/decrypt, and it handles key rotation, access control, and auditing.

SOPS uses KMS as the "master key" that protects all your secrets.

**Q5: How do you rotate SOPS encryption keys?**
**A:** Key rotation changes the master key without re-encrypting every file manually.

```bash
# Update .sops.yaml with new KMS key ARN
# Then rotate all encrypted files:
sops rotate -i secrets.enc.yaml
```

SOPS re-encrypts the data key with the new master key. The data key itself doesn't change, so the encrypted values remain the same.

**Q6: How to handle multi-environment secrets?**
**A:** Create separate encrypted files per environment:

```
secrets/
├── dev.enc.yaml      # Encrypted with dev KMS key
├── staging.enc.yaml  # Encrypted with staging KMS key
└── prod.enc.yaml     # Encrypted with prod KMS key
```

`.sops.yaml` creation rules route each file to the correct KMS key:
```yaml
creation_rules:
  - path_regex: secrets/dev\..*
    kms: arn:aws:kms:us-east-1:123:key/dev-key
  - path_regex: secrets/prod\..*
    kms: arn:aws:kms:us-east-1:123:key/prod-key
```

**Q7: How did you implement SOPS in the ROI platform from scratch?**
**A:** I used `sops` with `age` encryption. The workflow is:

1. **Install tools:**
   ```bash
   brew install sops age
   ```

2. **Generate the key pair:**
   ```bash
   age-keygen -o key.txt
   ```
   *(This generates a public key and a private key. The public key is used to encrypt, the private key is used to decrypt).*

3. **Encrypt the production secrets:**
   ```bash
   sops --encrypt --age <PUBLIC_KEY> --input-type dotenv --output-type dotenv .env.prod > .env.enc
   ```

4. **Push to GitHub:**
   ```bash
   git add .env.enc
   git commit -m "feat: Add encrypted SOPS production secrets"
   git push origin main
   ```

5. **Configure CI/CD:**
   I pasted the contents of `key.txt` into a GitHub Secret called `SOPS_AGE_KEY`. During deployment, the GitHub Action installs SOPS, decrypts `.env.enc` on the fly, and then immediately deletes the private key for security.

**Step-by-Step Execution Reference:**

Before you run this, quickly open `.env.prod` on your Mac and just make sure your Razorpay/JWT secrets are filled in correctly.

Once they look good, run these 4 commands in your terminal:

```bash
# 1. Install tools
brew install sops age

# 2. Generate the key (open key.txt to get your Public Key starting with age1...)
age-keygen -o key.txt

# 3. Encrypt the file (Replace <PUBLIC_KEY> with the age1... string)
sops --encrypt --age <PUBLIC_KEY> --input-type dotenv --output-type dotenv .env.prod > .env.enc

# 4. Push to Git
git add .env.enc
git commit -m "feat: Add encrypted SOPS production secrets"
git push origin main
```

Finally: Go to GitHub → Settings → Secrets → Actions. Create `SOPS_AGE_KEY` and paste the entire contents of your `key.txt` file into it.

Let me know when you've pushed `.env.enc` to GitHub!

---

## 🔧 21. Makefile

### What is it?
A **task runner** that defines common commands as short, memorable targets. Originally for C/C++ builds, now used as a DevOps automation tool.

### ROI's Targets (17 total)
```
make dev          # Start local dev environment
make build        # Build production images
make deploy       # Push to main (triggers CI/CD)
make logs         # Stream production logs
make backup       # Manual database backup
make infra-plan   # Terraform plan
make infra-apply  # Terraform apply
make monitoring-up  # Start monitoring stack
make clean        # Remove all Docker artifacts
```

### Interview Questions (0–3 Years)

**Q1: Why use Makefile instead of shell scripts?**
**A:**
| Makefile | Shell Scripts |
|---|---|
| Discoverable (`make help`) | Must read each script |
| Standard convention | No standard naming |
| Self-documenting with `##` comments | Must add docs manually |
| Tab-based syntax (love it or hate it) | Regular bash syntax |

Makefile is a **team convention** — everyone runs `make deploy`, not `./scripts/deploy.sh` which might have a different name on every project.

**Q2: What is `.PHONY` in a Makefile?**
**A:** `.PHONY` tells Make that a target is NOT a file. Without it, if a file named `test` exists in the directory, `make test` would say "nothing to do" (because the file already exists).

```makefile
.PHONY: test deploy clean
```

**Q3: What does `make help` do in ROI?**
**A:** It greps the Makefile for lines with `## ` comments and formats them into a nice table:
```
dev                  Start local development environment
build                Build production Docker images
deploy               Deploy to production
```
This is self-documenting — every target with a `## ` comment appears in help.

**Q4: How does `make deploy` work in ROI?**
**A:** `make deploy` runs `git push origin main`. This triggers the `deploy-to-aws.yml` GitHub Action which SSHs into EC2 and updates the containers. It's a GitOps approach — Git is the single source of truth.

**Q5: How does `make help` work? How can someone new discover all available targets?**
**A:** The `help` target uses `grep` + `awk` to extract target names and their `## ` comments:

```makefile
.PHONY: help
help: ## Show all available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
```

**For a new developer:**
```bash
make            # Runs default target (usually help)
make help       # Lists all targets with descriptions
cat Makefile    # Read the raw file
```

**Output of `make help`:**
```
  dev                  Start local development environment
  build                Build production Docker images
  deploy               Deploy to production
  logs                 Stream backend logs
  backup               Manual database backup
  clean                Remove all Docker artifacts
  infra-plan           Run terraform plan
  infra-apply          Run terraform apply
  monitoring-up        Start monitoring stack
```

**Q6: What are Makefile variables? How to use them?**
**A:**
```makefile
# Variables
APP_NAME := roi-backend
DOCKER_TAG := $(shell git rev-parse --short HEAD)

# Usage
build:
	docker build -t $(APP_NAME):$(DOCKER_TAG) .
```

- `:=` — Immediate evaluation (evaluated once when Makefile is read).
- `=` — Lazy evaluation (evaluated every time the variable is used).
- `$(shell ...)` — Run a shell command and capture output.

**Override at runtime:** `make build DOCKER_TAG=v1.2.3`

**Q7: What are common Makefile mistakes?**
**A:**
1. **Using spaces instead of tabs** — Makefile requires TABS for recipe lines. Spaces cause `missing separator` error.
2. **Missing `.PHONY`** — If a file named `test` exists, `make test` won't run.
3. **Not quoting variables** — Variables with spaces break if not quoted.
4. **Recursive make calls** — Use `$(MAKE)` not `make` for recursive calls.

---

## 🔐 22. Certbot / Let's Encrypt

### What is it?
- **Let's Encrypt** — Free, automated Certificate Authority (CA) that issues SSL/TLS certificates.
- **Certbot** — A tool that automates certificate issuance and renewal with Let's Encrypt.

### ROI's Setup
- Certbot runs on the EC2 instance.
- Auto-renews certificates every 60-90 days.
- Configures Nginx to serve HTTPS on `paisatest.online`.

### Interview Questions (0–3 Years)

**Q1: What is SSL/TLS? Why is HTTPS important?**
**A:** SSL/TLS encrypts traffic between the browser and server. Without it:
- Passwords sent in **plain text** (attackable on public WiFi).
- No way to verify you're talking to the real server (man-in-the-middle).
- Browsers show "Not Secure" warning → users leave.
- Google ranks HTTPS sites higher in search results.

**Q2: What is Let's Encrypt and why is it free?**
**A:** Let's Encrypt is a nonprofit CA backed by Mozilla, Google, and others. It's free because its mission is to encrypt the entire web.

It issues **Domain Validated (DV)** certificates — proves you own the domain, but doesn't verify the organization behind it. For ROI, DV is sufficient.

**Q3: How does Certbot auto-renewal work?**
**A:**
1. Certbot creates a systemd timer that runs twice daily.
2. On each run, it checks if any certificate expires within 30 days.
3. If yes, it contacts Let's Encrypt's ACME server, proves domain ownership, and gets a new certificate.
4. Reloads Nginx to pick up the new certificate.

Zero manual intervention after initial setup.

**Q4: What is the ACME protocol?**
**A:** Automated Certificate Management Environment — the protocol Certbot uses to communicate with Let's Encrypt.

Flow:
1. Certbot asks Let's Encrypt for a certificate for `paisatest.online`.
2. Let's Encrypt issues a challenge: "Place this file at `/.well-known/acme-challenge/xyz`"
3. Certbot places the file, Let's Encrypt verifies it → you own the domain.
4. Certificate issued.

**Q5: 🚨 SITUATION: SSL certificate expires. What happens?**
**A:**
- Browsers show **"Your connection is not private"** warning.
- Users can't access the site (most browsers block expired SSL).
- Google **drops search ranking** immediately.
- API clients (mobile app, webhooks) will **refuse to connect**.

**Prevention:**
1. Certbot auto-renewal (runs twice daily).
2. Monitor certificate expiry with Prometheus: `probe_ssl_earliest_cert_expiry`.
3. Alert if cert expires in < 14 days.

```bash
# Check certificate expiry manually
openssl s_client -connect paisatest.online:443 -servername paisatest.online < /dev/null 2>/dev/null | \
  openssl x509 -noout -dates
```

**Q6: What is a Wildcard Certificate?**
**A:** A certificate that covers ALL subdomains: `*.paisatest.online`

| Regular Certificate | Wildcard Certificate |
|---|---|
| Covers `paisatest.online` only | Covers `*.paisatest.online` |
| Need separate cert for each subdomain | One cert for all subdomains |
| HTTP challenge (easy) | **DNS challenge required** |

```bash
# Wildcard cert requires DNS challenge
certbot certonly --dns-route53 -d '*.paisatest.online' -d 'paisatest.online'
```

Let's Encrypt requires DNS challenge for wildcards because you need to prove you own the entire domain, not just one server.

**Q7: What are Let's Encrypt Rate Limits?**
**A:**
| Limit | Value |
|---|---|
| Certificates per domain per week | 50 |
| Duplicate certificates per week | 5 |
| Failed validations per hour | 5 |
| New registrations per IP per 3 hours | 10 |

**If you hit the rate limit**, you can't get new certificates for that period. This is why you should:
- Use `--staging` flag for testing (staging has much higher limits).
- Never request certificates in a CI/CD loop.

---

## 🔵🟢 23. Prisma

### What is it?
**Next-generation ORM** (Object-Relational Mapper) for Node.js. It translates database tables into TypeScript types and provides a type-safe query builder.

### ROI's Setup
- Schema: `backend/prisma/schema.prisma`
- Database: PostgreSQL
- Migrations: `npx prisma db push`

### Interview Questions (0–3 Years)

**Q1: What is an ORM? Why use Prisma instead of raw SQL?**
**A:**
| Raw SQL | Prisma ORM |
|---|---|
| Write SQL strings manually | Write TypeScript function calls |
| No type safety | Full TypeScript types |
| SQL injection risk | Auto-parameterized queries |
| No auto-migration | Schema-driven migrations |

```typescript
// Raw SQL (risky)
db.query(`SELECT * FROM users WHERE email = '${email}'`)

// Prisma (safe, typed)
prisma.user.findUnique({ where: { email } })
```

**Q2: What is `prisma db push` vs `prisma migrate`?**
**A:**
| `db push` | `migrate` |
|---|---|
| Syncs schema to DB directly | Creates migration files |
| No migration history | Full migration history |
| Good for: prototyping | Good for: production |
| Can lose data | Safe, reversible |

ROI uses `db push` for simplicity. Production-grade apps should use `prisma migrate`.

**Q3: What is Prisma Seeding?**
**A:** Populating the database with initial/test data using a script.

```javascript
// prisma/seed.js
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  await prisma.user.create({
    data: {
      email: 'admin@roi.com',
      name: 'Admin',
      role: 'ADMIN'
    }
  });
}
main();
```

```bash
npx prisma db seed  # Run the seed script
```

Use for: admin accounts, default settings, test data in development.

**Q4: How do Prisma Relations work?**
**A:**
```prisma
model User {
  id        Int       @id @default(autoincrement())
  email     String    @unique
  documents Document[]  // One-to-many: user has many documents
}

model Document {
  id       Int    @id @default(autoincrement())
  url      String
  userId   Int
  user     User   @relation(fields: [userId], references: [id])
}
```

Query with relations:
```javascript
const user = await prisma.user.findUnique({
  where: { id: 1 },
  include: { documents: true }  // Eager load documents
});
```

**Q5: When would you use raw SQL with Prisma?**
**A:** When Prisma's query builder can't express complex queries:

```javascript
// Complex aggregation
const result = await prisma.$queryRaw`
  SELECT DATE_TRUNC('month', created_at) as month,
         COUNT(*) as total,
         SUM(amount) as revenue
  FROM transactions
  GROUP BY month
  ORDER BY month DESC
`;
```

Use cases: Complex JOINs, window functions, database-specific features, performance-critical queries.

**Q6: What is Connection Pooling in Prisma?**
**A:** Prisma maintains a **pool of database connections** instead of creating a new connection for each query.

```
Pool: [conn1, conn2, conn3, conn4, conn5]

Request A → grabs conn1 → query → returns conn1 to pool
Request B → grabs conn2 → query → returns conn2 to pool
```

Default pool size: `num_cpus * 2 + 1`. For ROI's 2-CPU EC2: `2*2+1 = 5` connections.

If all connections are busy, new requests **wait in a queue** (with timeout). Configure via `DATABASE_URL`:
```
postgresql://user:pass@host:5432/db?connection_limit=10&pool_timeout=10
```

---

## 🔵🟢 24. Blue/Green Deployment

### What is it?
A deployment strategy that runs **two identical environments** — Blue (current) and Green (new). Traffic switches from Blue to Green atomically.

### ROI's ADR Decision
ROI chose Blue/Green over Rolling Deployment because:
- **Zero downtime** — Users never see partial deployments.
- **Instant rollback** — Switch back to Blue if Green fails.
- **Simple** — No complex orchestration needed.

### Interview Questions (0–3 Years)

**Q1: What is Blue/Green Deployment?**
**A:**
```
Before:  Users → [Blue v1.0] ✅  |  [Green v1.1] (deploying)
After:   Users → [Green v1.1] ✅  |  [Blue v1.0] (standby/rollback)
```

1. Blue = current production, serving all traffic.
2. Deploy new version to Green environment.
3. Test Green thoroughly.
4. Switch traffic from Blue → Green (DNS or load balancer).
5. If problems → switch back to Blue immediately.

**Q2: Blue/Green vs Rolling vs Canary — what's the difference?**
**A:**
| Strategy | How it Works | Risk | Complexity |
|---|---|---|---|
| **Blue/Green** | Full switch at once | Low (instant rollback) | Low |
| **Rolling** | Replace instances one by one | Medium (partial new/old) | Medium |
| **Canary** | Send 5% traffic to new version, gradually increase | Lowest | High |

**Implementation Details (How & Where to configure):**

### 1. Blue/Green Deployment
- **How:** Run two identical environments. Switch traffic at the proxy or load balancer level.
- **Where to change:** Edit the `upstream` block in `nginx.conf` or the Target Group in an AWS ALB.
- **Example (Nginx `nginx.conf`):**
  ```nginx
  # Before deployment (Blue active)
  upstream backend {
      server localhost:5001; # Blue container
      # server localhost:5002; # Green container (offline)
  }

  # After deployment (Green active)
  upstream backend {
      # server localhost:5001; # Blue container (offline)
      server localhost:5002; # Green container
  }
  ```
  *(Run `nginx -s reload` to apply with zero downtime)*

### 2. Rolling Update
- **How:** Terminate one old instance, wait for a new one to become healthy, repeat.
- **Where to change:** In Kubernetes, this is default. You define it in `deployment.yaml`.
- **Example (Kubernetes `deployment.yaml`):**
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  spec:
    replicas: 5
    strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 1       # Create max 1 extra pod during update
        maxUnavailable: 0 # Never let available pods drop below 5
  ```

### 3. Canary Deployment
- **How:** Use weighted routing to send exactly 5% of requests to the new code, 95% to the old.
- **Where to change:** In AWS Route53 or Kubernetes (using Istio/Argo).
- **Example (AWS Route53 via Terraform):**
  ```hcl
  resource "aws_route53_record" "canary_v1" {
    name           = "api.roi.com"
    set_identifier = "v1-old-code"
    weight         = 95    # 95% of traffic
    records        = [aws_lb.v1.dns_name]
  }

  resource "aws_route53_record" "canary_v2" {
    name           = "api.roi.com"
    set_identifier = "v2-new-code"
    weight         = 5     # 5% of traffic
    records        = [aws_lb.v2.dns_name]
  }
  ```

**Q3: What is the main disadvantage of Blue/Green?**
**A:** **Cost** — You need **double the infrastructure** during deployment (both Blue and Green environments running). For ROI's `t3.small`, we can't afford two EC2 instances, so we do a modified Blue/Green at the container level.

**Q4: How does ROI implement Blue/Green with Docker?**
**A:**
1. Pull new code → Build new containers.
2. Start new containers alongside old ones.
3. Health check new containers.
4. Switch Nginx upstream to new containers.
5. Stop old containers.

This gives us Blue/Green benefits without needing a second EC2 instance.

**Q5: What is a Rollback? When would you need one?**
**A:** Reverting to the previous version when the new deployment has issues.

Rollback triggers:
- Health checks failing after deploy.
- Error rate spike in Prometheus.
- User-reported critical bugs.
- Performance degradation.

In Blue/Green: Rollback = switch Nginx back to Blue containers. Takes seconds.
In traditional deploy: Rollback = rebuild old version, redeploy. Takes minutes/hours.

**Q6: 🚨 SITUATION: How do you handle database migrations in Blue/Green?**
**A:** This is the **hardest problem** in Blue/Green deployment.

**Problem:** Blue (v1) uses DB schema v1. Green (v2) needs schema v2. You can't migrate the DB for Green because Blue is still using it.

**Solution — Expand and Contract:**
1. **Expand**: Add new columns/tables without removing old ones (backward compatible).
2. **Deploy Green**: Green uses new columns, Blue ignores them.
3. **Switch traffic**: All traffic goes to Green.
4. **Contract**: Remove old columns/tables in a future migration.

```
v1: users table has 'name' column
v2: add 'first_name', 'last_name' columns (expand)
v3: remove 'name' column (contract, after v1 is gone)
```

**Q7: What are Feature Flags? How do they relate to deployments?**
**A:** Feature flags let you deploy code without activating it. The feature is behind an if/else check:

```javascript
if (featureFlags.isEnabled('new-kyc-flow')) {
  return newKycFlow(req, res);
} else {
  return oldKycFlow(req, res);
}
```

**Benefits:**
- Deploy anytime, enable features independently.
- Instant disable if something breaks (no rollback needed).
- A/B testing — enable for 10% of users.
- Canary — enable for internal team first.

Tools: LaunchDarkly, Unleash, or a simple Redis-backed config.

**Q8: Canary vs Blue/Green — deep comparison. When to use which?**
**A:**
| Aspect | Blue/Green | Canary |
|---|---|---|
| **Traffic split** | 0% or 100% | Gradual (1% → 5% → 25% → 100%) |
| **Risk detection** | Only after full switch | Detects issues with minimal blast radius |
| **Rollback speed** | Instant (switch back) | Instant (route back to stable) |
| **Infra cost** | 2x during deploy | 1x + small canary |
| **Complexity** | Low | High (needs traffic splitting) |
| **Best for** | Small teams, simple apps | Large-scale, high-traffic apps |
| **Tools** | Nginx, DNS, ALB | Istio, Argo Rollouts, AWS ALB weighted |

**ROI uses Blue/Green** because we have a single EC2 with Nginx — simple traffic switching. Canary would require a service mesh or ALB weighted target groups.

---

---

# Part 4 — Linux, Networking & Shell Scripting (Fundamentals)

---

## 🐧 25. Linux Fundamentals

### What is it?
Linux is the **operating system** that runs on 96% of the world's servers, including ROI's EC2 instance (`Ubuntu 22.04`). Every DevOps engineer MUST know Linux basics — you'll SSH into servers, read logs, debug processes, and automate tasks daily.

### Key Directories

| Directory | Purpose |
|---|---|
| `/` | Root — everything starts here |
| `/home` | User home directories (`/home/ubuntu`) |
| `/etc` | System configuration files (`/etc/nginx/nginx.conf`) |
| `/var/log` | Log files (`/var/log/syslog`, `/var/log/auth.log`) |
| `/tmp` | Temporary files (cleared on reboot) |
| `/proc` | Virtual filesystem — running processes and kernel info |
| `/sys` | Virtual filesystem — hardware/device info |
| `/opt` | Optional/third-party software |
| `/usr/bin` | User binaries (commands like `git`, `docker`) |
| `/usr/local/bin` | Locally installed binaries |

### Essential Commands Cheat Sheet

| Command | What it Does | Example |
|---|---|---|
| `ls -la` | List files with details + hidden | `ls -la /var/log/` |
| `cd` | Change directory | `cd /home/ubuntu/roi` |
| `pwd` | Print current directory | `pwd` → `/home/ubuntu` |
| `cat` | Print file contents | `cat /etc/hostname` |
| `less` / `more` | Page through large files | `less /var/log/syslog` |
| `tail -f` | Follow file in real-time | `tail -f /var/log/syslog` |
| `head -n 20` | First 20 lines | `head -n 20 file.log` |
| `cp` | Copy | `cp file.txt /tmp/` |
| `mv` | Move / rename | `mv old.txt new.txt` |
| `rm -rf` | Delete recursively (DANGEROUS) | `rm -rf /tmp/old-data/` |
| `mkdir -p` | Create nested directories | `mkdir -p /opt/roi/logs` |
| `find` | Search for files | `find / -name "*.log" -mtime -1` |
| `which` | Find command location | `which docker` → `/usr/bin/docker` |
| `whoami` | Current user | `whoami` → `ubuntu` |
| `hostname` | Machine name | `hostname` → `ip-10-0-1-50` |
| `df -h` | Disk usage (human-readable) | `df -h` |
| `du -sh` | Directory size | `du -sh /var/log/` |
| `free -h` | Memory usage | `free -h` |
| `uptime` | System uptime + load average | `uptime` |
| `uname -a` | Kernel/OS info | `uname -a` |

### Interview Questions (0–3 Years)

**Q1: What is the difference between `chmod` and `chown`?**
**A:**
| `chmod` | `chown` |
|---|---|
| Changes **permissions** (who can read/write/execute) | Changes **ownership** (who owns the file) |
| `chmod 755 script.sh` | `chown ubuntu:ubuntu script.sh` |
| Affects: user/group/others access | Affects: owner user and group |

**Permission numbers:**
```
r (read)    = 4
w (write)   = 2
x (execute) = 1

chmod 755 = rwxr-xr-x
  Owner:  7 = 4+2+1 = rwx (read + write + execute)
  Group:  5 = 4+0+1 = r-x (read + execute)
  Others: 5 = 4+0+1 = r-x (read + execute)

chmod 600 = rw-------  (only owner can read/write — use for SSH keys)
chmod 644 = rw-r--r--  (owner write, everyone read — use for config files)
chmod 777 = rwxrwxrwx  (NEVER use in production — everyone can do everything)
```

**Q2: What is `systemctl`? How do you manage services?**
**A:** `systemctl` is the command to manage **systemd services** (background processes that start on boot).

```bash
systemctl status nginx          # Check if running
systemctl start nginx           # Start service
systemctl stop nginx            # Stop service
systemctl restart nginx         # Restart (stop + start)
systemctl reload nginx          # Reload config without stopping
systemctl enable nginx          # Start on boot
systemctl disable nginx         # Don't start on boot
systemctl is-active nginx       # Returns "active" or "inactive"
systemctl list-units --type=service  # List all services
```

ROI uses Docker instead of systemd for most services, but Docker itself runs as a systemd service: `systemctl status docker`.

**Q3: How do you check running processes?**
**A:**
```bash
ps aux                    # List ALL processes
ps aux | grep node        # Find Node.js processes
top                       # Real-time process monitor (CPU, memory)
htop                      # Better version of top (install: apt install htop)
pgrep -f "node"           # Find PID by process name
kill <PID>                # Send SIGTERM (graceful stop)
kill -9 <PID>             # Send SIGKILL (force kill — last resort)
killall node              # Kill all processes named "node"
```

**`kill` vs `kill -9`:**
| `kill` (SIGTERM) | `kill -9` (SIGKILL) |
|---|---|
| Asks process to stop gracefully | Forces immediate termination |
| Process can clean up (close DB connections) | No cleanup — data may be lost |
| Process can ignore it | Cannot be ignored |
| Use first | Use only if SIGTERM doesn't work |

**Q4: What is a Cron Job? How do you schedule tasks?**
**A:** Cron runs commands on a schedule. Edit with `crontab -e`.

```
# Format: minute hour day-of-month month day-of-week command
# ┌───────── minute (0-59)
# │ ┌─────── hour (0-23)
# │ │ ┌───── day of month (1-31)
# │ │ │ ┌─── month (1-12)
# │ │ │ │ ┌─ day of week (0-7, 0=Sun)
# │ │ │ │ │
  * * * * *  command

# Examples:
0 2 * * *    /opt/roi/backup.sh        # Daily at 2:00 AM
*/5 * * * *  /opt/roi/healthcheck.sh    # Every 5 minutes
0 0 * * 0    /opt/roi/weekly-report.sh  # Every Sunday at midnight
0 6 * * 1-5  /opt/roi/weekday-task.sh   # Weekdays at 6:00 AM
```

```bash
crontab -l    # List current user's cron jobs
crontab -e    # Edit cron jobs
crontab -r    # Remove ALL cron jobs (careful!)
```

**Common mistake**: Cron runs with a minimal environment — always use full paths (`/usr/bin/docker` not `docker`).

**Q5: What is the difference between `apt` and `yum`?**
**A:**
| `apt` (Debian/Ubuntu) | `yum`/`dnf` (RHEL/CentOS/Amazon Linux) |
|---|---|
| `apt update` | `yum check-update` |
| `apt install nginx` | `yum install nginx` |
| `apt remove nginx` | `yum remove nginx` |
| `apt upgrade` | `yum update` |
| Uses `.deb` packages | Uses `.rpm` packages |

ROI's EC2 runs **Ubuntu** → uses `apt`.

**Q6: How do you check disk space and find large files?**
**A:**
```bash
df -h                        # Disk usage per partition
du -sh /var/log/             # Size of a directory
du -sh /* | sort -rh | head  # Top 10 largest directories
ncdu /                        # Interactive disk usage (install: apt install ncdu)

# Find files > 100MB
find / -type f -size +100M -exec ls -lh {} \;

# Find and delete old log files (older than 30 days)
find /var/log -name "*.log" -mtime +30 -delete
```

**Q7: What is `/proc`? Give useful examples.**
**A:** `/proc` is a virtual filesystem that exposes kernel and process information. Nothing is stored on disk — it's generated in real-time.

```bash
cat /proc/cpuinfo      # CPU details (cores, model)
cat /proc/meminfo      # Memory details
cat /proc/uptime       # System uptime in seconds
cat /proc/loadavg      # Load average (1, 5, 15 minutes)
cat /proc/<PID>/status # Details of a specific process
ls /proc               # Each numbered directory = a running process PID
```

Node Exporter reads from `/proc` to expose metrics to Prometheus.

**Q8: What are file descriptors? What is `stdin`, `stdout`, `stderr`?**
**A:**
| FD | Name | Description | Example |
|---|---|---|---|
| 0 | `stdin` | Standard input | Keyboard input, piped data |
| 1 | `stdout` | Standard output | Normal command output |
| 2 | `stderr` | Standard error | Error messages |

**Redirections:**
```bash
command > file.txt       # stdout to file (overwrite)
command >> file.txt      # stdout to file (append)
command 2> error.log     # stderr to file
command > out.log 2>&1   # Both stdout and stderr to same file
command > /dev/null 2>&1 # Discard ALL output (silent execution)
```

**Q9: What are `soft links` and `hard links`?**
**A:**
| Soft Link (Symlink) | Hard Link |
|---|---|
| Pointer to filename (like a shortcut) | Pointer to the file's data on disk |
| Can cross filesystems | Same filesystem only |
| Breaks if original is deleted | Still works if original name is deleted |
| `ln -s /original /link` | `ln /original /link` |

Most common: Soft links. Example: `/usr/bin/python3` → `/usr/bin/python3.10`

**Q10: How do you check who logged into the server?**
**A:**
```bash
last                  # Recent login history
last -n 10            # Last 10 logins
who                   # Currently logged-in users
w                     # Who is logged in + what they're doing
cat /var/log/auth.log # SSH authentication log (Ubuntu)
```

**Security check after a breach:**
```bash
last | head -20                    # Who logged in recently?
grep "Failed password" /var/log/auth.log | tail -20  # Brute-force attempts?
grep "Accepted" /var/log/auth.log | tail -20          # Successful logins?
```

**Q11: What is `sudo`? What is the difference between `sudo` and `su`?**
**A:**
| `sudo` | `su` |
|---|---|
| Run ONE command as root | Switch to root user entirely |
| `sudo apt update` | `su -` (then type root password) |
| Logs who ran what (audit trail) | No audit trail |
| Can be restricted per command | Full root access |
| Best practice ✅ | Avoid in production ❌ |

`/etc/sudoers` controls who can use `sudo` and which commands they can run.

**Q12: What is `ssh-keygen`? How does SSH key auth work?**
**A:**
```bash
ssh-keygen -t ed25519 -C "your@email.com"  # Generate key pair
# Creates: ~/.ssh/id_ed25519 (private) + ~/.ssh/id_ed25519.pub (public)
```

**How it works:**
1. You generate a key pair (public + private).
2. Public key → copied to server's `~/.ssh/authorized_keys`.
3. Private key → stays on YOUR machine (never share!).
4. SSH handshake: Server sends a challenge → your private key proves identity → access granted.

**Why keys > passwords:**
- Can't be brute-forced (2048+ bit key vs 8-char password).
- No password transmitted over network.
- Can be revoked per-key.

**Q13: 🚨 SITUATION: Server is slow. How do you diagnose?**
**A:** Follow this checklist:

```bash
# 1. Check CPU
top                    # Is any process using 100% CPU?
uptime                 # Load average > number of CPUs = overloaded

# 2. Check Memory
free -h                # Is memory full? Is swap being used?
# If swap is used heavily → need more RAM or find memory leak

# 3. Check Disk
df -h                  # Is any partition at 100%?
iostat                 # Is disk I/O saturated?

# 4. Check Network
ss -tuln               # What ports are listening?
netstat -an | grep ESTABLISHED | wc -l  # How many connections?

# 5. Check Processes
ps aux --sort=-%mem | head -10   # Top memory consumers
ps aux --sort=-%cpu | head -10   # Top CPU consumers

# 6. Check Logs
tail -100 /var/log/syslog        # System logs
dmesg | tail                     # Kernel messages (OOM killer?)
```

**Common culprits on ROI's `t3.small`:**
- Docker containers eating all 2GB RAM → OOM killer terminates processes.
- Log files filling disk → `du -sh /var/log/` → clean up.
- CPU credit exhaustion → check CloudWatch `CPUCreditBalance`.

**Q14: What is the OOM Killer?**
**A:** **Out-Of-Memory Killer** — when Linux runs out of RAM, the kernel picks a process to kill to free memory.

```bash
# Check if OOM killer was triggered
dmesg | grep -i "oom"
grep -i "oom" /var/log/syslog
```

**Prevention:**
1. Set `--memory` limits on Docker containers.
2. Monitor memory with Prometheus + alert at 80%.
3. Add swap space as a safety net (slower but prevents kills).

On ROI's 2GB `t3.small`, OOM is a real risk if all containers are running without memory limits.

**Q15: What is `nohup` and `&`? How to run processes in background?**
**A:**
```bash
command &              # Run in background (dies when terminal closes)
nohup command &        # Run in background (survives terminal close)
nohup command > out.log 2>&1 &  # Background + log output

# Better alternatives:
screen                 # Terminal multiplexer (detach/reattach)
tmux                   # Better terminal multiplexer
systemd service        # Proper way for production daemons
```

---

## 🌐 26. Networking Basics

### What is it?
Networking is HOW computers communicate. Every DevOps tool involves networking — Docker containers talk over networks, EC2 instances use VPCs, Nginx proxies HTTP requests, Prometheus scrapes metrics over HTTP.

### Interview Questions (0–3 Years)

**Q1: Explain the OSI Model (7 Layers).**
**A:**

| Layer | Name | What it Does | Example |
|---|---|---|---|
| 7 | **Application** | User-facing protocols | HTTP, HTTPS, DNS, SSH, FTP |
| 6 | Presentation | Data format, encryption | SSL/TLS, JPEG, JSON |
| 5 | Session | Session management | TCP sessions, authentication |
| 4 | **Transport** | End-to-end delivery | TCP (reliable), UDP (fast) |
| 3 | **Network** | Routing between networks | IP addresses, routers |
| 2 | Data Link | Local network delivery | MAC addresses, switches |
| 1 | Physical | Physical medium | Cables, WiFi signals |

**Interview shortcut**: You mostly need layers **7, 4, and 3**:
- Layer 7: HTTP, DNS, SSH (what DevOps tools use)
- Layer 4: TCP/UDP (how data is transported)
- Layer 3: IP (how machines are addressed)

**Q2: What is TCP vs UDP?**
**A:**
| TCP | UDP |
|---|---|
| **Reliable** — guaranteed delivery | **Unreliable** — no guarantee |
| Connection-oriented (handshake) | Connectionless |
| Ordered packets | Unordered packets |
| Slower (overhead of reliability) | Faster (no overhead) |
| HTTP, SSH, database connections | DNS, video streaming, gaming |

**TCP 3-way handshake:**
```
Client → SYN → Server         "Hey, let's talk"
Client ← SYN-ACK ← Server     "OK, I'm ready"
Client → ACK → Server         "Great, let's go"
```

**Q3: What is DNS? How does DNS resolution work?**
**A:** **Domain Name System** — translates domain names to IP addresses (`paisatest.online` → `3.222.210.129`).

**Resolution flow:**
```
Browser → "paisatest.online"
  → Check browser cache → miss
  → Check OS cache (/etc/hosts) → miss
  → Ask Recursive DNS Resolver (ISP) → miss
  → Ask Root DNS Server → ".online is managed by TLD server X"
  → Ask TLD Server (.online) → "paisatest.online is managed by NS Y"
  → Ask Authoritative DNS Server (Y) → "IP is 3.222.210.129"
  → Cache the result → Return IP to browser
```

**DNS Record Types:**
| Type | Purpose | Example |
|---|---|---|
| **A** | Domain → IPv4 | `paisatest.online → 3.222.210.129` |
| **AAAA** | Domain → IPv6 | `paisatest.online → 2001:db8::1` |
| **CNAME** | Alias → another domain | `www.paisatest.online → paisatest.online` |
| **MX** | Mail server | `paisatest.online → mail.google.com` |
| **NS** | Name server | `paisatest.online → ns1.provider.com` |
| **TXT** | Text data (verification) | SPF, DKIM, domain verification |

**Q4: What are common HTTP Status Codes?**
**A:**

| Code | Meaning | When you see it |
|---|---|---|
| **200** | OK | Request succeeded |
| **201** | Created | POST created a new resource |
| **204** | No Content | DELETE succeeded, nothing to return |
| **301** | Moved Permanently | URL changed, use new one (SEO redirect) |
| **302** | Found (Temporary Redirect) | Temporary redirect |
| **304** | Not Modified | Cached version is still valid |
| **400** | Bad Request | Client sent invalid data |
| **401** | Unauthorized | Not authenticated (no token/invalid token) |
| **403** | Forbidden | Authenticated but not permitted |
| **404** | Not Found | URL doesn't exist |
| **405** | Method Not Allowed | Wrong HTTP method (POST to a GET endpoint) |
| **429** | Too Many Requests | Rate limited (ROI's Nginx rate limiting!) |
| **500** | Internal Server Error | Backend crashed/bug |
| **502** | Bad Gateway | Nginx can't reach backend (container down) |
| **503** | Service Unavailable | Server overloaded or in maintenance |
| **504** | Gateway Timeout | Backend took too long to respond |

**Interview tip**: `502 vs 503 vs 504` is a favorite question:
- **502**: Backend is down (Nginx can't connect).
- **503**: Backend is up but overloaded (refuses connections).
- **504**: Backend is up but too slow (Nginx timeout).

**Q5: What are common ports? Which ones should you know?**
**A:**

| Port | Service | Protocol |
|---|---|---|
| 22 | SSH | TCP |
| 80 | HTTP | TCP |
| 443 | HTTPS | TCP |
| 3000 | React/Grafana (dev) | TCP |
| 3306 | MySQL | TCP |
| 5000 | Flask/Express (ROI backend) | TCP |
| 5432 | PostgreSQL (ROI database) | TCP |
| 6379 | Redis (ROI cache) | TCP |
| 8080 | Alternative HTTP | TCP |
| 9090 | Prometheus | TCP |
| 9100 | Node Exporter | TCP |

**Q6: What are `ping`, `traceroute`, `curl`, `dig`, `nslookup`?**
**A:**
```bash
# Is the host reachable? (ICMP)
ping google.com

# Show network path (every router hop)
traceroute google.com

# Make HTTP requests (the DevOps Swiss Army knife)
curl -I https://paisatest.online           # Headers only
curl -X POST -d '{"key":"val"}' URL        # POST request
curl -o file.zip https://example.com/file  # Download file
curl -w "%{http_code}" -s -o /dev/null URL # Just get status code

# DNS lookup
dig paisatest.online          # Detailed DNS query
dig +short paisatest.online   # Just the IP
nslookup paisatest.online     # Simpler DNS lookup

# Check open ports
ss -tuln                      # What ports are listening locally
nc -zv host 5432              # Test if a specific port is reachable
telnet host 5432              # Same but older tool
```

**Q7: What is a Firewall? `ufw` vs `iptables`?**
**A:** A firewall controls which network traffic is allowed in/out.

| `ufw` (Uncomplicated Firewall) | `iptables` |
|---|---|
| Simple, human-friendly | Complex, powerful |
| `ufw allow 22` | `iptables -A INPUT -p tcp --dport 22 -j ACCEPT` |
| Best for: quick setup | Best for: advanced rules |
| Frontend for iptables | The actual firewall engine |

```bash
ufw status                # Check firewall status
ufw enable                # Turn on firewall
ufw allow 22              # Allow SSH
ufw allow 80              # Allow HTTP
ufw allow 443             # Allow HTTPS
ufw deny 3306             # Block MySQL from outside
ufw allow from 10.0.0.0/16  # Allow entire VPC
```

**Q8: What is the difference between a Domain, DNS, and IP?**
**A:**
- **IP**: The actual address (`3.222.210.129`) — like a house's GPS coordinates.
- **Domain**: Human-readable name (`paisatest.online`) — like a house's street address.
- **DNS**: The phone book that maps domains to IPs.

**Q9: What is a Load Balancer? L4 vs L7?**
**A:** Distributes incoming traffic across multiple servers.

| L4 (Transport Layer) | L7 (Application Layer) |
|---|---|
| Routes based on **IP + Port** | Routes based on **URL path, headers, cookies** |
| Faster (no packet inspection) | Smarter (can read HTTP content) |
| AWS: NLB (Network Load Balancer) | AWS: ALB (Application Load Balancer) |
| Use for: TCP traffic, databases | Use for: HTTP APIs, microservices |

ROI's Nginx acts as an **L7 load balancer** — it reads the URL path and routes to backend or frontend.

**Q10: 🚨 SITUATION: Website returns 502 Bad Gateway. How do you debug?**
**A:**
```bash
# 1. Is Nginx running?
systemctl status nginx
docker ps | grep nginx

# 2. Is the backend running?
docker ps | grep backend
curl localhost:5000/health    # Direct backend health check

# 3. Can Nginx reach the backend?
docker exec nginx ping backend  # Can Nginx resolve the hostname?
docker logs nginx --tail 50     # Nginx error logs

# 4. Is the backend crashing?
docker logs roi_backend --tail 100  # Backend error logs

# 5. Is it a DNS issue inside Docker?
docker network ls                   # Is roi_global_network up?
docker network inspect roi_global_network  # Are containers connected?
```

**Most common 502 causes on ROI:**
1. Backend container crashed (OOM, uncaught exception).
2. Docker network not created (`roi_global_network`).
3. Backend health check failing → container restarting.

**Q11: What is the difference between HTTP and HTTPS?**
**A:**
| HTTP | HTTPS |
|---|---|
| Port 80 | Port 443 |
| Plain text (readable by anyone) | Encrypted (SSL/TLS) |
| No certificate needed | Requires SSL certificate |
| `http://` | `https://` |
| Insecure | Secure |

HTTPS = HTTP + TLS encryption. ROI uses Let's Encrypt/Certbot to get free TLS certificates.

**Q12: What is `localhost` vs `0.0.0.0` vs `127.0.0.1`?**
**A:**
| Address | Meaning | Who can access |
|---|---|---|
| `127.0.0.1` | Loopback (this machine only) | Only this machine |
| `localhost` | Hostname for `127.0.0.1` | Only this machine |
| `0.0.0.0` | ALL network interfaces | Anyone who can reach this machine |

**In Docker context:**
- App listening on `127.0.0.1:5000` → only accessible inside the container.
- App listening on `0.0.0.0:5000` → accessible from outside the container.

ROI's backend MUST listen on `0.0.0.0` so Nginx (in a separate container) can reach it.

---

## 💻 27. Shell Scripting (Bash)

### What is it?
Bash is the default **command-line shell** on Linux. Shell scripts automate repetitive tasks — backups, deployments, health checks, log cleanup.

### Interview Questions (0–3 Years)

**Q1: What is a Shebang (`#!/bin/bash`)? Why is it needed?**
**A:** The first line of a script that tells the OS which interpreter to use.

```bash
#!/bin/bash          # Use Bash shell
#!/usr/bin/env bash  # Find bash in PATH (more portable)
#!/usr/bin/python3   # This is a Python script
#!/bin/sh            # POSIX shell (more compatible, fewer features)
```

Without it, the OS doesn't know how to execute the file. You'd have to explicitly run `bash script.sh` instead of `./script.sh`.

**Q2: How do you write a basic Bash script?**
**A:**
```bash
#!/bin/bash

# Variables (no spaces around =)
NAME="ROI"
VERSION="1.0"
DATE=$(date +%Y-%m-%d)   # Command substitution

# Print
echo "Deploying $NAME v$VERSION on $DATE"

# Conditional
if [ "$1" == "production" ]; then
  echo "⚠️  Production deployment!"
  docker compose -f docker-compose.yml up --build -d
elif [ "$1" == "dev" ]; then
  echo "Starting dev environment"
  docker compose -f docker-compose.dev.yml up --build
else
  echo "Usage: $0 {production|dev}"
  exit 1
fi

# Exit code
echo "Done!"
exit 0
```

```bash
chmod +x deploy.sh       # Make executable
./deploy.sh production   # Run with argument
```

**Q3: What are Exit Codes? What is `$?`?**
**A:** Every command returns an exit code. `$?` holds the exit code of the last command.

| Exit Code | Meaning |
|---|---|
| `0` | Success ✅ |
| `1` | General error |
| `2` | Misuse of command |
| `126` | Permission denied |
| `127` | Command not found |
| `130` | Killed by Ctrl+C |
| `137` | Killed by `kill -9` (OOM Killer uses this!) |

```bash
docker ps
echo $?   # 0 if Docker is running, non-zero if not

# Use in scripts:
if ! docker ps > /dev/null 2>&1; then
  echo "Docker is not running!"
  exit 1
fi
```

**Q4: What is `grep`? Give useful examples.**
**A:** `grep` searches for patterns in text. The most-used DevOps command.

```bash
grep "error" /var/log/syslog            # Find lines with "error"
grep -i "error" file.log                # Case-insensitive
grep -r "DATABASE_URL" /opt/roi/        # Recursive search in directory
grep -c "error" file.log                # Count matching lines
grep -n "error" file.log                # Show line numbers
grep -v "debug" file.log                # Invert — show lines WITHOUT "debug"
grep -E "error|warning|critical" file   # Multiple patterns (regex)

# Pipeline usage:
docker ps | grep backend                # Find backend container
ps aux | grep node                      # Find Node.js processes
cat /var/log/auth.log | grep "Failed"   # Find failed SSH attempts
```

**Q5: What is `awk`? How is it used?**
**A:** `awk` processes text column-by-column. Think of it as a spreadsheet tool for the command line.

```bash
# Print specific columns
docker ps | awk '{print $1, $NF}'  # Container ID + Name
df -h | awk '{print $1, $5}'      # Filesystem + Usage%

# Filter rows
awk -F: '$3 >= 1000 {print $1}' /etc/passwd  # Users with UID >= 1000

# Calculate
awk '{sum += $1} END {print sum}' numbers.txt  # Sum all values

# ROI example: Find containers using > 500MB memory
docker stats --no-stream | awk 'NR>1 && $4+0 > 500 {print $2, $4}'
```

**Q6: What is `sed`? How is it used?**
**A:** `sed` = **Stream Editor** — find and replace text in files/streams.

```bash
# Replace first occurrence per line
sed 's/old/new/' file.txt

# Replace ALL occurrences
sed 's/old/new/g' file.txt

# Replace in-place (modify the file)
sed -i 's/localhost/0.0.0.0/g' config.yml

# Delete lines matching a pattern
sed -i '/^#/d' config.yml    # Remove all comment lines

# Insert line after match
sed -i '/\[dependencies\]/a new_package=1.0' config.ini
```

**Q7: What is Piping (`|`) and Chaining (`&&`, `||`, `;`)?**
**A:**
```bash
# Piping: output of command1 → input of command2
cat file.log | grep "error" | wc -l    # Count error lines

# Chaining:
command1 && command2     # Run command2 ONLY IF command1 succeeds
command1 || command2     # Run command2 ONLY IF command1 fails
command1 ; command2      # Run command2 regardless

# ROI examples:
docker compose build && docker compose up -d    # Build, then start
npm test && npm run build                        # Test, then build
docker ps || echo "Docker is not running!"       # Error handling
```

**Q8: How do you write a `for` loop and `while` loop?**
**A:**
```bash
# For loop — iterate over a list
for service in backend frontend redis postgres; do
  echo "Checking $service..."
  docker inspect "$service" --format '{{.State.Status}}'
done

# For loop — iterate over files
for file in /var/log/*.log; do
  echo "$file: $(wc -l < "$file") lines"
done

# While loop — read file line by line
while IFS= read -r line; do
  echo "Processing: $line"
done < servers.txt

# While loop — retry until success
MAX_RETRIES=5
count=0
while ! curl -s http://localhost:5000/health > /dev/null; do
  count=$((count + 1))
  if [ $count -ge $MAX_RETRIES ]; then
    echo "Backend failed to start after $MAX_RETRIES attempts"
    exit 1
  fi
  echo "Waiting for backend... ($count/$MAX_RETRIES)"
  sleep 5
done
echo "Backend is healthy!"
```

**Q9: Write a script to check if a service is running and restart it if not.**
**A:**
```bash
#!/bin/bash
# health-check.sh — Run via cron every 5 minutes

SERVICE="roi_backend"
LOGFILE="/var/log/health-check.log"

if docker inspect "$SERVICE" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"; then
  echo "$(date): $SERVICE is running ✅" >> "$LOGFILE"
else
  echo "$(date): $SERVICE is DOWN! Restarting... ⚠️" >> "$LOGFILE"
  cd /opt/roi && docker compose up -d "$SERVICE"
  
  # Wait and verify
  sleep 10
  if docker inspect "$SERVICE" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"; then
    echo "$(date): $SERVICE restarted successfully ✅" >> "$LOGFILE"
  else
    echo "$(date): $SERVICE FAILED to restart! 🚨 ALERT!" >> "$LOGFILE"
    # Send alert (could curl a webhook here)
  fi
fi
```

**Q10: What is `set -euo pipefail`? Why should every script start with it?**
**A:** Safety net for bash scripts:

```bash
#!/bin/bash
set -euo pipefail

# -e: Exit immediately if ANY command fails (non-zero exit code)
# -u: Treat undefined variables as errors (catches typos)
# -o pipefail: If any command in a pipeline fails, the whole pipeline fails
```

**Without `set -e`:**
```bash
rm -rf /opt/roi/$UNSET_VAR/  # $UNSET_VAR is empty → this runs: rm -rf /opt/roi// 
# Script continues as if nothing happened 😱
```

**With `set -euo pipefail`:** Script stops immediately and shows the error.

**Q11: What is the difference between `$()` and backticks?**
**A:** Both do command substitution (run a command and capture output).

```bash
DATE=$(date +%Y-%m-%d)     # Modern syntax ✅ (nestable, readable)
DATE=`date +%Y-%m-%d`      # Old syntax ❌ (hard to nest, harder to read)

# Nesting:
FILES=$(find / -name "$(hostname).log")    # ✅ Easy
FILES=`find / -name \`hostname\`.log`      # ❌ Ugly
```

Always use `$()`.

**Q12: Write a backup script for ROI's database.**
**A:**
```bash
#!/bin/bash
set -euo pipefail

# Config
BACKUP_DIR="/opt/roi/backups"
DB_CONTAINER="roi_postgres"
DB_NAME="roi_db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Dump database and compress
echo "$(date): Starting backup..."
docker exec "$DB_CONTAINER" pg_dump -U postgres "$DB_NAME" | gzip > "$BACKUP_FILE"

# Verify
if [ -s "$BACKUP_FILE" ]; then
  SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
  echo "$(date): Backup successful! Size: $SIZE → $BACKUP_FILE"
else
  echo "$(date): Backup FAILED! File is empty."
  rm -f "$BACKUP_FILE"
  exit 1
fi

# Clean old backups
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "$(date): Cleaned backups older than $RETENTION_DAYS days."
```

---

*— End of Part 4. Part 5 covers Git, CI/CD Design, Ansible, Kubernetes →*


# Part 5 — Version Control, CI/CD Design, Config Management & Orchestration

---

## 🌿 28. Git Deep-Dive

### What is it?
Git is a **distributed version control system**. Every developer has a full copy of the repository. ROI uses Git + GitHub for code management, branching, and collaboration.

### Interview Questions (0–3 Years)

**Q1: What is the difference between `git merge` and `git rebase`?**
**A:**
| `merge` | `rebase` |
|---|---|
| Creates a **merge commit** | Rewrites commit history (linear) |
| Preserves branch history | Cleaner, flat history |
| Safe for shared branches | **Never rebase shared branches** |
| `git merge feature` | `git rebase main` |

```
# Merge: main ──●──●──●──M──  (M = merge commit)
#               \       /
# feature:       ●──●──●

# Rebase: main ──●──●──●──●──●──●──  (linear, no merge commit)
```

**Golden rule**: Rebase YOUR feature branch onto main. Never rebase main onto your branch.

**Q2: What is `git stash`?**
**A:** Temporarily saves uncommitted changes so you can switch branches.

```bash
git stash                   # Save changes
git stash list              # List saved stashes
git stash pop               # Apply latest stash + delete it
git stash apply             # Apply latest stash (keep it)
git stash drop              # Delete latest stash
git stash -m "WIP: feature" # Named stash
```

Use case: You're mid-feature, but a critical bug needs fixing on main. Stash → switch → fix → switch back → pop.

**Q3: What is `git cherry-pick`?**
**A:** Applies a **specific commit** from one branch to another (without merging the whole branch).

```bash
git cherry-pick abc123    # Apply commit abc123 to current branch
git cherry-pick abc..def  # Apply range of commits
```

Use case: A bug fix was committed to `develop` but you need it on `main` right now — cherry-pick just that commit.

**Q4: What is `git reset` vs `git revert`?**
**A:**
| `reset` | `revert` |
|---|---|
| **Removes** commits from history | **Creates a new commit** that undoes changes |
| Rewrites history (dangerous for shared branches) | Safe for shared branches |
| `git reset --hard HEAD~1` | `git revert HEAD` |
| Commits disappear | Original commits preserved |

```bash
# Reset modes:
git reset --soft HEAD~1   # Undo commit, keep changes staged
git reset --mixed HEAD~1  # Undo commit, keep changes unstaged (default)
git reset --hard HEAD~1   # Undo commit, DELETE all changes ⚠️
```

**Rule**: Use `revert` on shared branches (main, develop). Use `reset` only on YOUR local branches.

**Q5: What are Git Branching Strategies?**
**A:**

| Strategy | Branches | Best For |
|---|---|---|
| **GitFlow** | main, develop, feature/*, release/*, hotfix/* | Large teams, versioned releases |
| **Trunk-Based** | main + short-lived feature branches | Small teams, CI/CD heavy |
| **GitHub Flow** | main + feature branches (PR-based) | Most web apps (ROI uses this) |

**ROI uses GitHub Flow:**
```
main (always deployable)
  └── feature/add-kyc-upload (branch from main)
        └── Open PR → CI runs → Code review → Merge → Auto-deploy
```

**Q6: What is `git reflog`? How does it save your life?**
**A:** `reflog` records EVERY move of HEAD — even after reset, rebase, and "lost" commits.

```bash
git reflog                # Show all HEAD movements
git checkout HEAD@{5}     # Go back to state 5 moves ago
git reset --hard HEAD@{3} # Restore to 3 moves ago
```

**Life-saving scenario**: You ran `git reset --hard` and lost commits. `reflog` shows them — you can recover.

**Q7: What is `git bisect`?**
**A:** Binary search through commits to find which commit introduced a bug.

```bash
git bisect start
git bisect bad              # Current commit has the bug
git bisect good v1.0        # This old version was fine
# Git checks out middle commit → you test → mark good/bad
git bisect good             # This commit is fine
git bisect bad              # This commit has the bug
# Repeat until Git finds the EXACT commit that broke things
git bisect reset            # Exit bisect mode
```

**Q8: What are Git Hooks?**
**A:** Scripts that run automatically at specific Git events.

```
.git/hooks/
├── pre-commit      # Before commit: run linter, tests
├── commit-msg      # Validate commit message format
├── pre-push        # Before push: run full test suite
└── post-merge      # After merge: install new dependencies
```

Example pre-commit hook:
```bash
#!/bin/bash
npm run lint
if [ $? -ne 0 ]; then
  echo "❌ Lint failed! Fix before committing."
  exit 1
fi
```

Tools like **Husky** (Node.js) automate Git hooks setup.

**Q9: What is `.gitignore`? What should NOT be in Git?**
**A:**
```gitignore
# Dependencies
node_modules/
vendor/

# Environment
.env
.env.production
*.pem

# Build output
dist/
build/

# OS files
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/

# Terraform
.terraform/
*.tfstate
*.tfstate.backup
```

**Never commit**: Secrets, API keys, passwords, large binaries, `node_modules/`, Terraform state.

**Q10: How do you resolve a Git merge conflict?**
**A:**
```
<<<<<<< HEAD
const port = 3000;      // Your version
=======
const port = 5000;      // Their version
>>>>>>> feature-branch
```

Steps:
1. Open conflicted file.
2. Choose which code to keep (or combine both).
3. Remove the `<<<<<<<`, `=======`, `>>>>>>>` markers.
4. `git add <file>` → `git commit`

**Prevention**: Pull frequently, keep PRs small, communicate with team.

**Q11: What is `git diff` and `git log`?**
**A:**
```bash
git diff                      # Unstaged changes
git diff --staged             # Staged changes
git diff main..feature        # Difference between branches
git diff HEAD~3               # Changes in last 3 commits

git log --oneline             # Compact history
git log --graph --oneline     # Visual branch graph
git log -n 10                 # Last 10 commits
git log --author="anurag"     # Commits by specific author
git log --since="2024-01-01"  # Commits after date
```

**Q12: What is a Git Tag?**
**A:** A named pointer to a specific commit — used for releases/versions.

```bash
git tag v1.0.0                    # Lightweight tag
git tag -a v1.0.0 -m "Release 1"  # Annotated tag (recommended)
git push origin v1.0.0             # Push tag to remote
git tag -l "v1.*"                  # List matching tags
```

---

## 🏗️ 29. CI/CD Design Scenarios

### What is it?
Interviewers often ask you to **design a CI/CD pipeline from scratch**. This tests your understanding of the entire software delivery lifecycle.

### Interview Questions (0–3 Years)

**Q1: Design a CI/CD pipeline for a Node.js web application.**
**A:**
```
┌─────────┐    ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Code   │ →  │  Build  │ →  │  Test    │ →  │  Stage   │ →  │  Prod    │
│  Push   │    │         │    │          │    │          │    │          │
└─────────┘    └─────────┘    └──────────┘    └──────────┘    └──────────┘

Stage 1 - Build:
  - Checkout code
  - Install dependencies (npm ci)
  - Lint (eslint)
  - Build Docker image
  - Push to container registry (ECR/DockerHub)

Stage 2 - Test:
  - Unit tests (jest)
  - Integration tests (supertest)
  - Security scan (npm audit, trivy)
  - Code coverage check (>80%)

Stage 3 - Deploy to Staging:
  - Deploy to staging environment
  - Run smoke tests
  - Run E2E tests (Playwright/Cypress)

Stage 4 - Deploy to Production:
  - Manual approval gate
  - Blue/Green deployment
  - Health check verification
  - Rollback if health check fails
```

**Q2: What is the difference between Continuous Delivery and Continuous Deployment?**
**A:**
| Continuous Delivery | Continuous Deployment |
|---|---|
| Code is always **ready** to deploy | Code is **automatically** deployed |
| Requires **manual approval** before prod | No human intervention |
| Safer for regulated industries | Faster for fast-moving teams |
| ROI uses this (push to main → auto-deploy) | Netflix, Facebook use this |

**Q3: What is a CI/CD Artifact? Why version it?**
**A:** An artifact is the **output of a build** — Docker image, compiled binary, or bundled JS.

**Versioning strategies:**
```bash
# Git SHA (most common for Docker)
roi-backend:a3f4b2c

# Semantic version
roi-backend:1.2.3

# Timestamp
roi-backend:20240115-143022

# Branch + SHA
roi-backend:main-a3f4b2c
```

**Why version?** So you can:
- Deploy **any** previous version (rollback).
- Know exactly which code is running in production.
- Avoid "it works on my machine" — same image everywhere.

**Q4: What is Environment Promotion?**
**A:** Moving the same artifact through environments: `Dev → Staging → Production`.

```
Build once → Push image:v1.2.3
  → Deploy to Dev    (automatic)
  → Deploy to Staging (automatic after Dev tests pass)
  → Deploy to Prod   (manual approval)
```

**Key rule**: Never rebuild for each environment. Same image everywhere — only config changes (env vars).

**Q5: How do you handle secrets in CI/CD?**
**A:**
| Method | Security | Example |
|---|---|---|
| **Hardcoded in YAML** ❌ | Terrible | `API_KEY: "abc123"` |
| **Environment variables** | OK for non-sensitive | `NODE_ENV: production` |
| **CI/CD Secrets** ✅ | Good | GitHub Secrets, GitLab Variables |
| **SOPS** ✅ | Better (version controlled) | Encrypted files in Git |
| **Vault** ✅ | Best (dynamic, rotated) | HashiCorp Vault |

ROI uses GitHub Secrets for CI/CD + SOPS for application secrets.

**Q6: What is a Monorepo vs Polyrepo?**
**A:**
| Monorepo | Polyrepo |
|---|---|
| All services in ONE repository | Each service in its OWN repository |
| Easier to share code | Better isolation |
| One CI/CD pipeline (complex) | Separate pipelines (simple) |
| Atomic changes across services | Cross-service changes need coordination |
| Google, Meta use this | Most companies use this |

ROI is a **monorepo** — backend, frontend, infra, monitoring all in one repo. Makes sense for a small team.

**Q7: What is Trunk-Based Development?**
**A:** All developers commit to `main` (trunk) directly or via short-lived feature branches (< 1 day).

```
main: ──●──●──●──●──●──●──  (always deployable)
         \   /
feature:  ●──●  (< 1 day, merged quickly)
```

vs GitFlow:
```
main:    ──●────────────────M──
develop: ──●──●──●──●──●──/
feature:       \──●──●──/      (can live for weeks)
```

Trunk-based works best with: feature flags, good CI/CD, automated tests.

**Q8: What is a Deployment Rollback Strategy?**
**A:** Every pipeline should answer: "What if the deploy fails?"

| Strategy | How | Speed |
|---|---|---|
| **Re-deploy previous version** | `docker pull image:v1.1` | Minutes |
| **Blue/Green switch** | Change Nginx upstream | Seconds |
| **Database rollback** | Risky — data migrations can't easily undo | Avoid |
| **Feature flag disable** | Toggle off in config | Instant |

ROI's rollback: Switch Nginx back to the old container set (Blue/Green).

**Q9: What is GitOps?**
**A:** Using Git as the **single source of truth** for infrastructure and deployments.

**Principles:**
1. All config is in Git (declarative).
2. Changes go through PRs (auditable).
3. Automated reconciliation (if Git says X, cluster should be X).
4. No manual changes to production.

ROI follows GitOps: `git push origin main` → GitHub Actions deploys → no manual SSH deploys.

**Q10: 🚨 SITUATION: A deployment broke production. Walk through your incident response.**
**A:**
```
1. DETECT (0-5 min)
   → Prometheus alert fires → Alertmanager notifies on Slack
   → Grafana dashboard shows error rate spike

2. RESPOND (5-10 min)
   → Acknowledge alert
   → Check: What was the last deployment? (git log -1)
   → Rollback: switch to previous container (Blue/Green)

3. MITIGATE (10-30 min)
   → Verify rollback worked (check /health endpoint)
   → Announce incident in team channel
   → Check logs in Loki for root cause

4. INVESTIGATE (30 min - 2 hours)
   → git diff between old and new version
   → Reproduce in staging
   → Identify root cause

5. FIX AND PREVENT
   → Write fix → Test in staging → Deploy with monitoring
   → Write post-mortem (what happened, why, how to prevent)
   → Add test/alert to catch this in future
```

---

## ⚙️ 30. Ansible (Configuration Management)

### What is it?
Ansible is an **agentless configuration management** tool. It SSHes into servers and runs tasks to configure them — install packages, copy files, manage services.

### Key Concepts

| Concept | What it Is |
|---|---|
| **Playbook** | YAML file defining tasks to run |
| **Inventory** | List of servers (hosts) to configure |
| **Module** | Built-in functions (apt, copy, service, docker) |
| **Role** | Reusable collection of tasks (like a function) |
| **Handler** | Task that runs only when notified (e.g., restart Nginx after config change) |
| **Idempotent** | Running twice = same result (safe to re-run) |

### Interview Questions (0–3 Years)

**Q1: What is Ansible? How is it different from Terraform?**
**A:**
| Ansible | Terraform |
|---|---|
| **Configuration Management** — configures servers | **Infrastructure Provisioning** — creates servers |
| "Install Docker on this EC2" | "Create this EC2 instance" |
| Procedural (step by step) | Declarative (desired state) |
| Agentless (SSH) | Agentless (API calls) |
| Mutable infrastructure | Immutable infrastructure |

**They complement each other:**
```
Terraform creates EC2 → Ansible configures EC2
                         (install Docker, copy configs, start services)
```

ROI uses Terraform for provisioning + User Data for basic setup. Ansible would be the next step for complex configuration.

**Q2: What is a Playbook? Write a simple one.**
**A:**
```yaml
# setup-server.yml
---
- name: Configure ROI server
  hosts: production
  become: yes    # Run as root (sudo)

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Docker
      apt:
        name: docker.io
        state: present

    - name: Start Docker service
      service:
        name: docker
        state: started
        enabled: yes

    - name: Add ubuntu user to docker group
      user:
        name: ubuntu
        groups: docker
        append: yes

    - name: Copy docker-compose file
      copy:
        src: ./docker-compose.yml
        dest: /opt/roi/docker-compose.yml

    - name: Start application
      command: docker compose up -d
      args:
        chdir: /opt/roi
```

Run: `ansible-playbook -i inventory.ini setup-server.yml`

**Q3: What is an Inventory?**
**A:** A file listing servers Ansible should manage.

```ini
# inventory.ini
[production]
3.222.210.129 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/roi-key.pem

[staging]
10.0.1.50 ansible_user=ubuntu

[monitoring]
10.0.2.50 ansible_user=ubuntu

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

Can also be **dynamic** — pull server list from AWS EC2 API (useful when servers are auto-scaled).

**Q4: What is Idempotency? Why is it important?**
**A:** Running a playbook **twice produces the same result**. It doesn't install Docker twice or create duplicate files.

```yaml
# Idempotent ✅ — Ansible checks if Docker is already installed
- apt:
    name: docker.io
    state: present   # "Ensure it's present" — if already there, skip

# NOT idempotent ❌ — runs every time
- command: apt install docker.io
```

**Why?** You can safely re-run playbooks after failures, network interruptions, or config changes without breaking things.

**Q5: What is an Ansible Role?**
**A:** A reusable package of tasks, files, templates, and variables.

```
roles/
├── docker/
│   ├── tasks/main.yml      # Install + configure Docker
│   ├── handlers/main.yml   # Restart Docker when config changes
│   ├── templates/daemon.json.j2  # Docker config template
│   └── defaults/main.yml   # Default variables
├── nginx/
│   ├── tasks/main.yml
│   └── templates/nginx.conf.j2
```

Use in playbook:
```yaml
- hosts: production
  roles:
    - docker
    - nginx
    - monitoring
```

Like functions in programming — write once, reuse everywhere.

**Q6: What are Handlers?**
**A:** Tasks that run **only when notified** — typically to restart services after config changes.

```yaml
tasks:
  - name: Update Nginx config
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Restart Nginx     # Only restart if config actually changed

handlers:
  - name: Restart Nginx
    service:
      name: nginx
      state: restarted
```

Without handlers, Nginx would restart even if the config didn't change.

**Q7: What is `ansible-vault`?**
**A:** Encrypts sensitive data (passwords, API keys) in Ansible files.

```bash
ansible-vault create secrets.yml     # Create encrypted file
ansible-vault edit secrets.yml       # Edit encrypted file
ansible-vault encrypt vars.yml       # Encrypt existing file
ansible-vault decrypt vars.yml       # Decrypt file

# Run playbook with vault password
ansible-playbook site.yml --ask-vault-pass
ansible-playbook site.yml --vault-password-file .vault_pass
```

Similar to SOPS but built into Ansible.

**Q8: What are Ad-Hoc Commands?**
**A:** One-liner Ansible commands without writing a playbook.

```bash
# Ping all servers
ansible all -m ping -i inventory.ini

# Check uptime
ansible production -m command -a "uptime"

# Install a package
ansible production -m apt -a "name=htop state=present" --become

# Copy a file
ansible production -m copy -a "src=./config.yml dest=/opt/roi/config.yml"

# Restart Docker
ansible production -m service -a "name=docker state=restarted" --become
```

**Q9: Ansible vs Chef vs Puppet — comparison.**
**A:**
| Feature | Ansible | Chef | Puppet |
|---|---|---|---|
| Language | YAML | Ruby | Ruby DSL |
| Architecture | Agentless (SSH) | Agent-based | Agent-based |
| Learning curve | Easy | Hard | Medium |
| Push/Pull | Push | Pull | Pull |
| Community | Huge | Large | Large |

Ansible wins for most DevOps use cases due to simplicity and agentless design.

**Q10: When should you NOT use Ansible?**
**A:**
- **Creating cloud resources** → Use Terraform instead.
- **Container orchestration** → Use Kubernetes/Docker Compose.
- **Immutable infrastructure** → If you rebuild servers instead of updating them, Ansible is less useful.
- **Very large scale (10,000+ servers)** → Consider Puppet/Salt for better pull-based architecture.

---

## ☸️ 31. Kubernetes (Container Orchestration)

### What is it?
Kubernetes (K8s) is a **container orchestration platform** that automates deployment, scaling, and management of containerized applications. It's the industry standard for running containers in production.

### Why Does a DevOps Engineer Need to Know K8s?
- **80% of DevOps job descriptions** require Kubernetes knowledge.
- ROI currently uses Docker Compose (single server). K8s is the next evolution when you need to scale.
- K8s vs Docker Compose = "managing a fleet of ships" vs "managing one ship."

### K8s Architecture

```
┌───────────────────────────────────────────┐
│           CONTROL PLANE (Master)          │
│  ┌──────────┐  ┌──────┐  ┌───────────┐   │
│  │ API      │  │ etcd │  │ Scheduler │   │
│  │ Server   │  │      │  │           │   │
│  └──────────┘  └──────┘  └───────────┘   │
│  ┌──────────────────────────────────┐     │
│  │  Controller Manager             │     │
│  └──────────────────────────────────┘     │
└───────────────────────────────────────────┘
          │                    │
┌─────────┴────────┐  ┌───────┴──────────┐
│  WORKER NODE 1   │  │  WORKER NODE 2   │
│  ┌─────────────┐ │  │  ┌─────────────┐ │
│  │ kubelet     │ │  │  │ kubelet     │ │
│  │ kube-proxy  │ │  │  │ kube-proxy  │ │
│  │ ┌─────────┐ │ │  │  │ ┌─────────┐ │ │
│  │ │ Pod     │ │ │  │  │ │ Pod     │ │ │
│  │ │ ┌─────┐ │ │ │  │  │ │ ┌─────┐ │ │ │
│  │ │ │ App │ │ │ │  │  │ │ │ App │ │ │ │
│  │ │ └─────┘ │ │ │  │  │ │ └─────┘ │ │ │
│  │ └─────────┘ │ │  │  │ └─────────┘ │ │
│  └─────────────┘ │  │  └─────────────┘ │
└──────────────────┘  └──────────────────┘
```

### Key Concepts

| Concept | What it Is | Docker Compose Equivalent |
|---|---|---|
| **Pod** | Smallest unit — one or more containers | A single container |
| **Deployment** | Manages replica Pods (desired state) | `services:` with `replicas:` |
| **Service** | Stable network endpoint for Pods | `ports:` mapping |
| **ConfigMap** | Non-sensitive configuration | `.env` file |
| **Secret** | Sensitive configuration (base64 encoded) | `.env` secrets |
| **Namespace** | Virtual cluster (isolation) | No equivalent |
| **Ingress** | HTTP routing rules (like Nginx) | Nginx reverse proxy |
| **HPA** | Horizontal Pod Autoscaler | No equivalent |
| **Helm** | Package manager for K8s | No equivalent |

### Interview Questions (0–3 Years)

**Q1: What is Kubernetes? Why not just use Docker Compose?**
**A:**
| Docker Compose | Kubernetes |
|---|---|
| Single host | Multi-host cluster |
| No auto-scaling | Auto-scales based on load |
| No self-healing (manual restart) | Auto-restarts failed containers |
| No rolling updates | Built-in rolling updates + rollback |
| Simple (YAML + `docker compose up`) | Complex (many resources to learn) |
| Use for: dev, small apps (ROI now) | Use for: production, scale (ROI future) |

**When to move from Compose to K8s:**
- Need more than one server.
- Need auto-scaling (traffic spikes).
- Need zero-downtime deployments.
- Need multi-region deployment.

**Q2: What is a Pod? Why not just run containers directly?**
**A:** A Pod is the smallest K8s unit — a wrapper around one or more containers that share:
- Same network namespace (localhost).
- Same storage volumes.
- Same lifecycle (start/stop together).

**Why Pods?** Some containers are tightly coupled. Example: app container + log sidecar container → same Pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: roi-backend
spec:
  containers:
    - name: backend
      image: roi-backend:1.0
      ports:
        - containerPort: 5000
    - name: log-shipper     # Sidecar container
      image: promtail:latest
```

**Q3: What is a Deployment? Write one for ROI's backend.**
**A:** A Deployment manages Pods — ensures the desired number of replicas are running, handles updates and rollbacks.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: roi-backend
  namespace: roi
spec:
  replicas: 3                    # Run 3 copies
  selector:
    matchLabels:
      app: roi-backend
  strategy:
    type: RollingUpdate          # Zero-downtime update
    rollingUpdate:
      maxSurge: 1                # Create 1 extra during update
      maxUnavailable: 0          # Never go below 3
  template:
    metadata:
      labels:
        app: roi-backend
    spec:
      containers:
        - name: backend
          image: roi-backend:1.2.3
          ports:
            - containerPort: 5000
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: roi-secrets
                  key: database-url
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 5000
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 5000
            initialDelaySeconds: 5
            periodSeconds: 10
```

**Q4: What is a Service? What types exist?**
**A:** A Service provides a **stable endpoint** to access Pods (Pods are ephemeral — their IPs change).

| Type | Description | Use Case |
|---|---|---|
| **ClusterIP** (default) | Internal only — accessible within cluster | Backend API, databases |
| **NodePort** | Exposes on each node's IP + static port | Dev/testing |
| **LoadBalancer** | Creates cloud load balancer (ALB/NLB) | Production external access |
| **ExternalName** | CNAME to external service | Access external DB by name |

```yaml
apiVersion: v1
kind: Service
metadata:
  name: roi-backend-svc
spec:
  type: ClusterIP
  selector:
    app: roi-backend      # Route to Pods with this label
  ports:
    - port: 80            # Service port
      targetPort: 5000    # Container port
```

**Q5: What is a Namespace?**
**A:** A virtual cluster within a cluster — for isolation and organization.

```bash
kubectl get namespaces
# default       Active
# kube-system   Active   (K8s internal components)
# roi           Active   (ROI application)
# monitoring    Active   (Prometheus, Grafana, Loki)

kubectl create namespace roi
kubectl get pods -n roi         # List pods in roi namespace
kubectl get pods --all-namespaces  # List ALL pods
```

**Q6: What is an Ingress?**
**A:** HTTP routing rules — like Nginx reverse proxy but K8s-native.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: roi-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
    - hosts: [paisatest.online]
      secretName: roi-tls
  rules:
    - host: paisatest.online
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: roi-backend-svc
                port: { number: 80 }
          - path: /
            pathType: Prefix
            backend:
              service:
                name: roi-frontend-svc
                port: { number: 80 }
```

This replaces ROI's `nginx-proxy.conf` — same routing but managed by K8s.

**Q7: What are ConfigMaps and Secrets?**
**A:**
```yaml
# ConfigMap — non-sensitive config
apiVersion: v1
kind: ConfigMap
metadata:
  name: roi-config
data:
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  REDIS_HOST: "redis-svc"

---
# Secret — sensitive config (base64 encoded)
apiVersion: v1
kind: Secret
metadata:
  name: roi-secrets
type: Opaque
data:
  database-url: cG9zdGdyZXM6Ly91c2VyOnBhc3NAaG9zdC9kYg==  # base64
  jwt-secret: c3VwZXItc2VjcmV0LWtleQ==
```

**Note**: K8s Secrets are base64 encoded, NOT encrypted. Use SOPS + sealed-secrets or external secrets for real security.

**Q8: What is `kubectl`? Essential commands.**
**A:**
```bash
# Cluster info
kubectl cluster-info
kubectl get nodes

# Pods
kubectl get pods -n roi
kubectl describe pod roi-backend-abc123 -n roi
kubectl logs roi-backend-abc123 -n roi --tail=100
kubectl logs roi-backend-abc123 -n roi -f    # Follow logs
kubectl exec -it roi-backend-abc123 -- /bin/sh  # Shell into pod

# Deployments
kubectl get deployments -n roi
kubectl scale deployment roi-backend --replicas=5 -n roi
kubectl rollout status deployment/roi-backend -n roi
kubectl rollout undo deployment/roi-backend -n roi   # Rollback!
kubectl set image deployment/roi-backend backend=roi-backend:1.3.0

# Services
kubectl get svc -n roi
kubectl get ingress -n roi

# Apply/Delete
kubectl apply -f deployment.yml
kubectl delete -f deployment.yml

# Debug
kubectl get events -n roi --sort-by='.lastTimestamp'
kubectl top pods -n roi   # CPU/memory per pod
```

**Q9: What is Horizontal Pod Autoscaler (HPA)?**
**A:** Automatically scales Pods based on CPU/memory or custom metrics.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: roi-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: roi-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70   # Scale when CPU > 70%
```

When CPU goes above 70% → K8s adds more Pods. When it drops → scales down. Docker Compose can't do this.

**Q10: What is Helm?**
**A:** A **package manager** for Kubernetes. Like `apt` for Linux or `npm` for Node.js, but for K8s manifests.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
helm upgrade prometheus prometheus-community/kube-prometheus-stack
helm rollback prometheus 1    # Rollback to version 1
helm list -n monitoring       # List installed charts
```

Instead of writing 20 YAML files for Prometheus, Grafana, Alertmanager → one `helm install` command.

**Q11: What is a Liveness Probe vs Readiness Probe in K8s?**
**A:**
| Liveness Probe | Readiness Probe |
|---|---|
| "Is the container alive?" | "Can it serve traffic?" |
| Failure → **restart** the container | Failure → **stop sending traffic** |
| Catches: deadlocks, infinite loops | Catches: DB not ready, loading cache |
| Runs throughout container lifetime | Runs throughout container lifetime |

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 10   # Wait 10s before first check
  periodSeconds: 30          # Check every 30s

readinessProbe:
  httpGet:
    path: /health/ready
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Q12: What happens when you run `kubectl apply -f deployment.yml`?**
**A:**
```
1. kubectl sends YAML to API Server
2. API Server validates and stores in etcd
3. Scheduler assigns Pods to Nodes
4. kubelet on each Node pulls the image and starts containers
5. kube-proxy sets up networking rules
6. Deployment controller monitors Pod health
7. If a Pod dies → controller creates a new one (self-healing)
```

**Q13: 🚨 SITUATION: A Pod is in `CrashLoopBackOff`. How do you debug?**
**A:**
```bash
# 1. Check pod status
kubectl get pods -n roi
# NAME                  READY   STATUS             RESTARTS   AGE
# roi-backend-abc123    0/1     CrashLoopBackOff   5          10m

# 2. Check logs (why did it crash?)
kubectl logs roi-backend-abc123 -n roi --previous  # Logs from LAST crash

# 3. Check events
kubectl describe pod roi-backend-abc123 -n roi
# Look at Events section at the bottom

# 4. Common causes:
# - Missing environment variable (DATABASE_URL not set)
# - Wrong image tag (image doesn't exist)
# - Port conflict
# - OOMKilled (memory limit too low)
# - Liveness probe failing too early (increase initialDelaySeconds)
```

**Q14: How would you migrate ROI from Docker Compose to Kubernetes?**
**A:**
```
Docker Compose → Kubernetes Mapping:

docker-compose.yml services:  →  Deployments + Services
  backend:                    →  Deployment: roi-backend
                                  Service: roi-backend-svc
  frontend:                   →  Deployment: roi-frontend
                                  Service: roi-frontend-svc
  postgres:                   →  StatefulSet: roi-postgres
                                  PersistentVolumeClaim
  redis:                      →  Deployment: roi-redis
                                  Service: roi-redis-svc
  nginx:                      →  Ingress (replaces Nginx routing)
  
.env files:                   →  ConfigMaps + Secrets
volumes:                      →  PersistentVolumeClaims
networks:                     →  Namespaces + Services
depends_on:                   →  readinessProbe (K8s handles ordering)
```

**Q15: What is the difference between a Deployment, StatefulSet, and DaemonSet?**
**A:**
| Deployment | StatefulSet | DaemonSet |
|---|---|---|
| Stateless apps | Stateful apps | One per node |
| Pods are interchangeable | Pods have stable identity + storage | Runs on EVERY node |
| Backend API, frontend | PostgreSQL, Redis, Kafka | Node Exporter, Promtail |
| Random pod names | Ordered names (db-0, db-1, db-2) | One per node |
| Scale up/down freely | Scale carefully (data!) | Auto-scales with nodes |

---

*— End of Part 5. You now have complete coverage for junior DevOps interviews. —*


---

# Part 6 — Senior Level & System Design (3-6+ Years)

---

## 🏛️ 32. System Design & Cloud Architecture

### What is it?
At the senior level, interviewers stop asking "what is a VPC?" and start asking "how would you design a multi-region network?" You are expected to design systems that are **Highly Available (HA)**, **Fault-Tolerant**, and **Scalable**.

### Interview Questions (Senior Level)

**Q1: Design a Highly Available (HA) web architecture on AWS that survives a single Availability Zone (AZ) failure.**
**A:** 
*   **Networking:** VPC with 2 Public Subnets and 2 Private Subnets spread across 2 AZs (e.g., `us-east-1a`, `us-east-1b`).
*   **Compute:** Application Load Balancer (ALB) in the Public Subnets. Target group points to an Auto Scaling Group (ASG) of EC2 instances residing in the Private Subnets.
*   **Database:** Amazon RDS (PostgreSQL/MySQL) with Multi-AZ enabled. The primary DB is in AZ-A, the synchronous standby is in AZ-B.
*   **Failure Scenario:** If AZ-A goes down, the ALB automatically routes traffic only to instances in AZ-B. RDS automatically fails over to the standby instance in AZ-B (DNS flips automatically in ~60 seconds).

**Q2: How do you design for a Full Region outage (e.g., all of `us-east-1` goes down)?**
**A:** This requires an **Active-Active** or **Active-Passive** multi-region setup.
*   **Data replication:** Use DynamoDB Global Tables or RDS Cross-Region Read Replicas to copy data from `us-east-1` to `us-west-2`.
*   **Compute:** Replicate the ASG and ALB infrastructure via Terraform in `us-west-2`.
*   **Routing:** Use Route53 with a **Failover Routing Policy** (Active-Passive) or **Latency/Weighted Routing Policy** (Active-Active). Route53 health checks monitor `us-east-1`; if it fails, DNS resolves to the `us-west-2` ALB.

**Q3: Explain the difference between Scalability and Elasticity.**
**A:**
*   **Scalability:** The ability of the system to handle *increased* load (e.g., upgrading from a `t3.small` to a `m5.large` is Vertical Scaling. Adding more `t3.small`s is Horizontal Scaling).
*   **Elasticity:** The ability to scale *out* when load increases, AND scale *in* when load decreases to save costs. Auto Scaling Groups provide elasticity.

**Q4: Your database is the bottleneck. How do you scale it?**
**A:**
1.  **Vertical Scaling:** Increase the RDS instance size (causes brief downtime).
2.  **Caching:** Put Redis/Memcached in front of the DB to cache frequent, read-heavy queries.
3.  **Read Replicas:** Route all `SELECT` queries to Read Replicas, and keep `INSERT/UPDATE` queries on the Master node.
4.  **Sharding:** Split the data across multiple databases (e.g., Users A-M on DB1, Users N-Z on DB2). High complexity, last resort.

**Q5: What is the "Strangler Fig" pattern?**
**A:** A strategy for migrating a monolithic application to microservices. Instead of a massive rewrite, you put a reverse proxy (API Gateway/Nginx) in front of the monolith. You slowly build new features as microservices, and configure the proxy to route specific endpoints (e.g., `/api/billing`) to the new microservice, while the rest goes to the monolith. Over time, the monolith is "strangled" out of existence.

---

## 🐍 33. Python Scripting for DevOps

### What is it?
Bash is great for server automation, but Python is the king of **Cloud Automation, API interaction, and Data parsing**. `boto3` is the official AWS SDK for Python.

### Interview Questions (Senior Level)

**Q1: How do you find and delete all unattached EBS volumes across all AWS regions using Python to save costs?**
**A:** You use the `boto3` library.
```python
import boto3

def delete_unattached_volumes():
    ec2_client = boto3.client('ec2', region_name='us-east-1')
    # Get all regions
    regions = [region['RegionName'] for region in ec2_client.describe_regions()['Regions']]
    
    for region in regions:
        print(f"Checking region: {region}")
        ec2 = boto3.resource('ec2', region_name=region)
        # Filter for 'available' state (not 'in-use')
        volumes = ec2.volumes.filter(Filters=[{'Name': 'status', 'Values': ['available']}])
        
        for vol in volumes:
            print(f"Deleting unattached volume: {vol.id} in {region}")
            vol.delete()

if __name__ == '__main__':
    delete_unattached_volumes()
```

**Q2: What is the difference between `boto3.client` and `boto3.resource`?**
**A:**
*   **Client:** Low-level AWS API wrapper. Returns raw Python dictionaries (JSON). You have to handle pagination manually.
*   **Resource:** High-level, object-oriented API. Returns Python objects (e.g., `s3.Bucket('name')`). Handles pagination automatically under the hood. (Note: AWS is slowly deprecating `resource` in favor of `client` for newer services).

**Q3: How do you handle exceptions and rate limits in Python scripts interacting with APIs?**
**A:** Use exponential backoff (e.g., `tenacity` or `backoff` libraries) or standard `try/except` blocks looking for `429 Too Many Requests` or AWS `ThrottlingException`.

```python
import time
import boto3
from botocore.exceptions import ClientError

client = boto3.client('ec2')
retries = 0

while retries < 5:
    try:
        client.describe_instances()
        break
    except ClientError as e:
        if e.response['Error']['Code'] == 'RequestLimitExceeded':
            time.sleep(2 ** retries)  # 1s, 2s, 4s, 8s, 16s
            retries += 1
        else:
            raise
```

**Q4: How do you parse a large JSON log file in Python without running out of memory?**
**A:** Do not use `json.loads(file.read())` as it loads the entire file into RAM. Instead, read the file line by line (if it's JSON-Lines) or use a streaming parser like `ijson`.
```python
import json

with open("large_logs.jsonl", "r") as f:
    for line in f:
        log_entry = json.loads(line)
        if log_entry.get("level") == "error":
            print(log_entry["message"])
```

---

## ⚓ 34. GitOps & Advanced Cloud-Native Tools

### What is it?
GitOps is the paradigm where Git is the single source of truth for declarative infrastructure and applications. Instead of *pushing* deployments via CI pipelines (like GitHub Actions), agents running *inside* Kubernetes *pull* the state from Git.

### Interview Questions (Senior Level)

**Q1: Explain how ArgoCD works. How does it differ from a traditional Jenkins/GitHub Actions deployment?**
**A:**
*   **Traditional (Push):** GitHub Actions builds the Docker image, then runs `kubectl apply` to push the manifest to the Kubernetes cluster. *Problem:* CI needs cluster admin credentials.
*   **ArgoCD (Pull / GitOps):** ArgoCD runs *inside* the K8s cluster. It constantly monitors a Git repository containing Kubernetes manifests (or Helm charts). If the Git repo changes (e.g., a new image tag is committed), ArgoCD detects the drift and pulls the new manifests into the cluster, applying them automatically. *Benefit:* Cluster credentials never leave the cluster. If someone manually edits a Pod via `kubectl`, ArgoCD instantly overwrites it to match Git.

**Q2: What is a Service Mesh (e.g., Istio or Linkerd)? Why would you use one?**
**A:** A Service Mesh handles communication *between* microservices (east-west traffic). It works by injecting a "sidecar" proxy (like Envoy) into every Pod. 
**Why use it?**
1.  **mTLS:** Automatically encrypts all traffic between internal microservices.
2.  **Traffic Routing:** Allows advanced Canary deployments (send 5% of traffic to v2, 95% to v1).
3.  **Observability:** Provides golden signals (latency, traffic, errors, saturation) for every service without changing application code.

**Q3: What are Kubernetes Operators?**
**A:** Operators are software extensions that use custom resources to manage complex, stateful applications on Kubernetes. 
*Example:* A standard Deployment can run a stateless web app. But a database like PostgreSQL requires complex logic (setting up master/replica, handling failover, taking backups). A PostgreSQL Operator replaces a human DBA by automating all that lifecycle logic inside the K8s cluster.

**Q4: How does a Canary Deployment work in Kubernetes?**
**A:** You deploy the new version (v2) alongside the old version (v1). Initially, you route 1% of traffic to v2. You monitor v2's error rates and latency in Prometheus. If healthy, you scale traffic to 10%, then 50%, then 100%. If errors spike, you instantly route traffic back to 100% v1. Tools like **Argo Rollouts** or **Flagger** automate this exact process based on Prometheus metrics.

---

## 🛡️ 35. DevSecOps & Compliance

### What is it?
Shifting security "left" — meaning integrating security checks into the CI/CD pipeline and code creation phase, rather than waiting for an audit right before production.

### Interview Questions (Senior Level)

**Q1: How do you integrate security into a CI/CD pipeline?**
**A:**
1.  **Pre-commit:** Git hooks (e.g., `trufflehog` or `git-secrets`) to prevent hardcoded passwords/API keys from being committed.
2.  **SAST (Static Application Security Testing):** Run tools like SonarQube or Snyk on the source code to find vulnerabilities (e.g., SQL injection risks) before building.
3.  **SCA (Software Composition Analysis):** Run `npm audit` or Dependabot to find known vulnerabilities (CVEs) in third-party libraries.
4.  **Container Scanning:** Run tools like **Trivy** or Clair on the built Docker image to find OS-level vulnerabilities (e.g., a vulnerable version of `openssl` in the Ubuntu base image).
5.  **DAST (Dynamic Application Security Testing):** Run tools like OWASP ZAP against the deployed staging environment to test for vulnerabilities on the running app.

**Q2: What is Open Policy Agent (OPA)?**
**A:** OPA is a general-purpose policy engine. In Kubernetes, it acts as an Admission Controller.
*Example use case:* You write a policy in OPA's language (Rego) that says "No Pods can run as the root user" and "All images must come from our private ECR registry, not DockerHub." If a developer tries to run `kubectl apply` with an invalid Pod, OPA intercepts the API request and denies it.

**Q3: How do you achieve least privilege in AWS?**
**A:** 
1.  Use AWS IAM Access Analyzer to identify unused permissions.
2.  Use IAM Roles instead of permanent IAM Users/Access Keys.
3.  For EC2/EKS, attach an IAM Role directly to the instance/Pod (IRSA in K8s) rather than embedding credentials in code.
4.  Use IAM Permission Boundaries to restrict the maximum permissions a developer can grant to a role they create.

---

## ☁️ 36. Multi-Cloud & Cloud-Agnostic Concepts

### What is it?
Many enterprise companies use more than one cloud provider (e.g., AWS for compute, GCP for AI/data). Senior engineers must understand how concepts map across providers.

### Interview Questions (Senior Level)

**Q1: How do AWS, Azure, and GCP map to each other for basic services?**
**A:**
| Concept | AWS | Microsoft Azure | Google Cloud (GCP) |
|---|---|---|---|
| Virtual Machines | EC2 | Azure VMs | Compute Engine (GCE) |
| Object Storage | S3 | Blob Storage | Cloud Storage |
| Managed Kubernetes | EKS | AKS | GKE |
| Relational DB | RDS | Azure SQL | Cloud SQL |
| IaC Native Tool | CloudFormation | ARM Templates / Bicep | Deployment Manager |

**Q2: How do you manage multi-cloud infrastructure with Terraform?**
**A:** Terraform is cloud-agnostic in its *workflow*, but the *code* is provider-specific. You cannot use an `aws_instance` resource in Azure. You manage multi-cloud by configuring multiple providers in the same Terraform project:
```hcl
provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
}

resource "aws_instance" "web" { ... }
resource "azurerm_virtual_machine" "db" { ... }
```

**Q3: What is Pulumi, and how does it compare to Terraform?**
**A:**
*   **Terraform:** Uses HCL (HashiCorp Configuration Language), a domain-specific, declarative language.
*   **Pulumi:** Allows you to write Infrastructure as Code using general-purpose programming languages like Python, TypeScript, or Go. 
*   **Why use Pulumi?** If your team are hardcore developers (e.g., TypeScript engineers), they can write IaC in a language they already know, utilizing standard `for` loops, classes, and testing frameworks (like Jest) directly on the infrastructure code.

---

# 🏁 Summary — All 36 Tools/Topics by Category

| Category | Tools |
|---|---|
| **Containerization** | Docker, Docker Compose |
| **Web Server** | Nginx |
| **IaC** | Terraform, Pulumi |
| **AWS Compute** | EC2 |
| **AWS Storage** | S3, DynamoDB |
| **AWS Security** | IAM, VPC |
| **CI/CD** | GitHub Actions, Dependabot |
| **Metrics** | Prometheus, Node Exporter |
| **Visualization** | Grafana |
| **Logging** | Loki, Promtail |
| **Tracing** | Tempo |
| **Alerting** | Alertmanager |
| **Caching** | Redis |
| **Secrets** | SOPS |
| **Automation** | Makefile |
| **SSL** | Certbot / Let's Encrypt |
| **Database** | Prisma (ORM) |
| **Deployment** | Blue/Green Strategy, Canary (Argo Rollouts) |
| **OS Fundamentals** | Linux |
| **Networking** | Networking Basics |
| **Scripting** | Shell Scripting (Bash), Python (boto3) |
| **Version Control** | Git |
| **CI/CD Design** | Pipeline Architecture |
| **Config Management** | Ansible |
| **Container Orchestration** | Kubernetes |
| **System Design** | HA, Active-Active, Scalability |
| **GitOps** | ArgoCD |
| **Service Mesh** | Istio |
| **DevSecOps** | Trivy, SonarQube, OPA |
| **Multi-Cloud** | AWS, Azure, GCP Mapping |

> **Total Questions: 320+** across 36 tools/topics — covering everything from 0-year fundamentals to 5+ year Senior System Design.

