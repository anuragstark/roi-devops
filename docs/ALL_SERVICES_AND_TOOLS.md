# All Services & Tools Used in the ROI Project

This document provides a comprehensive, categorized list of every tool, service, SDK, and framework currently powering the ROI Platform.

---

### 1. Frontend (The Web App)
*   **React 18** — Core UI library.
*   **Vite 5** — Build tool and ultra-fast local dev server.
*   **TypeScript** — Strongly typed JavaScript for safer code.
*   **TailwindCSS** — Utility-first CSS framework for styling.
*   **React Router (v6)** — Client-side routing for navigating pages.
*   **React Hook Form + Zod** — Form handling and strict schema validation.
*   **Axios** — HTTP client to make requests to the backend.
*   **ApexCharts & Chart.js** — Used for rendering the investment and ROI graphs.
*   **React Hot Toast** — Used for popup success/error notifications.

### 2. Backend (The API Server)
*   **Node.js** — The JavaScript runtime environment.
*   **Express.js** — The web framework handling API routes and middleware.
*   **TypeScript** — For backend type safety.
*   **Prisma ORM** — The database toolkit used to query the database instead of raw SQL.
*   **JWT (JSON Web Tokens) & Bcrypt** — Used for secure user login and password hashing.
*   **Node-Cron** — A task scheduler running background jobs (calculating daily ROI and salary payouts).
*   **Multer** — Middleware for handling file uploads (e.g., KYC documents).
*   **Zod** — Validating incoming API payloads to ensure data integrity.

### 3. Third-Party API Integrations
*   **AWS SDK (S3)** — Used to upload and fetch images/documents securely to cloud storage.
*   **Razorpay** — Payment gateway integration for Fiat (INR/USD) transactions.
*   **TronWeb** — Blockchain SDK to handle TRX / USDT crypto transactions on the TRON network.
*   **Ethers.js** — Web3 library for interacting with Ethereum-compatible blockchains.

### 4. Database & Caching
*   **MySQL (v8.0)** — The primary relational database (running on AWS RDS).
*   **Redis** — In-memory caching system used to speed up queries and handle rate-limiting.

### 5. Cloud Infrastructure (AWS)
*   **EC2 (Ubuntu 24.04)** — The virtual server running the application containers (`t3.small`).
*   **RDS (Relational Database Service)** — Managed MySQL database (`db.t4g.micro`).
*   **S3 (Simple Storage Service)** — Object storage for user files and Terraform remote state.
*   **DynamoDB** — Used specifically by Terraform to lock the state file during deployments.
*   **VPC, Security Groups, Elastic IPs** — AWS Networking components to secure the server.
*   **Route53** — AWS DNS management.

### 6. DevOps & Deployment
*   **Docker & Docker Compose** — Containerizing the Node and React apps so they run identically everywhere.
*   **Terraform** — Infrastructure as Code (IaC) to create the AWS resources via code.
*   **GitHub Actions** — CI/CD pipelines to automatically deploy code when pushed to `main`.
*   **Nginx** — The reverse proxy that sits in front of the app, routing traffic and handling SSL.
*   **Certbot (Let's Encrypt)** — Automatically provisions and renews free SSL/HTTPS certificates.
*   **SOPS (Secrets OPerationS)** — Encrypts your `.env` secrets safely within Git using KMS/PGP.
*   **Makefile** — Used to create easy shortcut commands (like `make deploy` or `make up`).

### 7. Observability & Monitoring (The PLG Stack)
*   **Prometheus** — Scrapes and stores time-series metrics (CPU, Memory, API latency).
*   **Grafana** — The dashboard UI where you view those metrics.
*   **Loki & Promtail** — Loki stores application logs, and Promtail ships them from Docker to Loki.
*   **Tempo** — Distributed tracing (tracks a request as it moves through the system).
*   **Alertmanager** — Sends Slack/Email alerts when things crash.
*   **Node Exporter** — A daemon exposing Linux hardware metrics (Disk space, RAM) to Prometheus. 
*   **Prom-client** — The Node.js library generating custom API metrics for Prometheus.

### 8. GitHub Actions & Deployment Automation
The `.github/workflows/` directory contains all CI/CD pipelines governing the project lifecycle:
*   **`deploy.yml`** — **(Auto on push to `main` & Manual)** The core CI/CD pipeline. It provisions AWS infrastructure via Terraform, decrypts secrets using SOPS, builds Docker containers, executes zero-downtime Blue/Green deployments, and automates Certbot SSL provisioning.
*   **`backend-ci.yml`** — **(Auto on backend changes or PRs)** A continuous integration safety net. It runs the TypeScript compiler to prevent broken backend code from merging into the main branch.
*   **`drift-detection.yml`** — **(Auto every Monday at 6 AM & Manual)** A security auditing pipeline. It runs `terraform plan` on a schedule to detect if someone manually modified AWS resources (Infrastructure Drift) outside of the code.
*   **`terraform-destroy.yml`** — **(Strictly Manual)** The cost-saving kill switch. When manually triggered, it runs `terraform destroy` to safely tear down all EC2 and RDS resources to stop AWS billing when the project is not in use.

### 9. Docker Configuration Architecture
The project utilizes a distinct split between local development and production Docker environments:
*   **`docker-compose.yml`** — The main **Production App** orchestrator. Deployed by GitHub Actions, it runs the compiled `frontend/Dockerfile` and `backend/Dockerfile`.
*   **`docker-compose.infra.yml`** — The **Production Infrastructure** orchestrator. Booted during deployment to run Prometheus, Grafana, Loki, Redis, and a custom `infra/backup/Dockerfile` that backs up the MySQL database to AWS S3 nightly.
*   **`docker-compose.dev.yml`** — The **Local Development** orchestrator. Used purely on your local machine (never in AWS). It boots a local MySQL database, Redis, and uses `frontend/Dockerfile.dev` and `backend/Dockerfile.dev` for hot-reloading code changes instantly.
