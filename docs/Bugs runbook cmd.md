<!-- smtp check logs :
docker logs roi_backend_dev 2>&1 | grep -i smtp



 for check api 
# curl -sk -X POST https://127.0.0.1/api/auth/login \

#   -H "Content-Type: application/json" \

#   -d '{"email":"admin@example.com","password":"changeMe!Admin"}'

# AWS_S3_BUCKET=your-actual-bucket-name -->



<!-- check logs :
docker compose logs backend --tail 50 | grep -i error -->



# 🐛 ROI Platform: Bug & Incident Runbook

This document tracks common errors encountered during development and deployment, along with their precise root causes and commands to fix them.

---

## 1. Grafana Dashboards Showing "No data" (Local Development)

**Symptoms:** 
- Grafana loads successfully, but all panels (HTTP requests, Node.js Memory, etc.) display a big "No data" warning.
- You recently spun up the `docker-compose.dev.yml` stack.

**Root Causes & Fixes:**

**Cause A: Docker Internal DNS Mismatch**
If the Prometheus service in `docker-compose.dev.yml` is named `prometheus_dev`, Grafana will fail to connect. This is because Grafana's shared provisioning config (`datasources/prometheus.yml`) strictly looks for the URL `http://prometheus:9090`.
* **Fix:** Ensure the service name in your `docker-compose.dev.yml` is exactly `prometheus` (and `grafana`, `node-exporter` respectively), perfectly matching the production compose file. 

**Cause B: Missing NPM Dependencies (Backend Crash Loop)**
If a new NPM package (like `prom-client`) was recently added to `package.json`, running a standard `docker compose up -d` does **not** automatically rebuild the local Docker image. The backend container will silently crash on startup because it cannot find the new module.
* **Fix:** Force Docker to rebuild the image and install the new dependencies:
  ```bash
  docker compose -f docker-compose.dev.yml up -d --build
  ```

**Cause C: No Traffic Generated Yet**
HTTP metric panels calculate rates over the last few minutes. If you just started the server and haven't visited the website, the HTTP graphs will be legitimately empty because there is zero traffic to measure.
* **Fix:** Open the frontend (`localhost:3000`), click around several pages to trigger backend API requests, and wait 15-30 seconds for Prometheus to scrape the newly generated data.

---

## 2. Docker Compose: Orphan Containers Conflict

**Symptoms:**
When attempting to start your Docker stack, you receive a fatal conflict error:
> `Error response from daemon: Conflict. The container name "/roi_node_exporter_dev" is already in use by container "...". You have to remove (or rename) that container to be able to reuse that name.`

**Root Cause:**
A service name was changed inside the `docker-compose.yml` file (e.g., renaming `prometheus_dev` to `prometheus`) while the old containers were still actively running. Because the name changed, Docker Compose no longer recognizes the old container as part of the current compose file. It leaves the old container running as an "orphan", which blocks the new container from taking over the name.

**Fix:**
Append the `--remove-orphans` flag to your compose command. This safely destroys any ghost containers that belong to the project but are no longer mapped in your YAML file.
```bash
docker compose -f docker-compose.dev.yml up -d --remove-orphans
```
