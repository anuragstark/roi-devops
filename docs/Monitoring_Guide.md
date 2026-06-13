# ROI Platform - Observability & Monitoring Guide

The ROI Platform comes with a fully automated, enterprise-grade monitoring stack out of the box. This stack automatically tracks server health, API metrics, and centralizes all container logs in real-time.

## 🌟 The Monitoring Stack
Our stack consists of the following tools, all managed securely within the `docker-compose.infra.yml` configuration:

1. **Grafana** - The central visualization dashboard where you view all metrics and logs.
2. **Prometheus** - The time-series database that scrapes and stores metrics from the server.
3. **Loki** - The log aggregation system (similar to Elasticsearch) designed for highly efficient log querying.
4. **Promtail** - The agent that tails all Docker container logs and instantly ships them to Loki.
5. **Node Exporter** - Exports hardware and OS metrics (CPU, RAM, Disk usage) to Prometheus.

---

## 🔐 Accessing the Grafana Dashboard

To access your centralized monitoring dashboard:

1. **URL**: `http://<YOUR_EC2_IP>:3001` or `http://paisatest.online:3001`
2. **Username**: `admin`
3. **Password**: The password is automatically injected via the `GRAFANA_ADMIN_PASSWORD` variable in your `.env` file. If that variable is not set, the default password is `admin`.
   *(Note: Grafana has disabled the prompt to change passwords on first login to ensure automated deployments succeed).*

---

## 📝 How to View Centralized Logs (Loki)

You never need to SSH into the server to run `docker compose logs` again! All logs from the Frontend, Backend, Cron jobs, and Backup scripts are streamed live to Grafana.

1. Open **Grafana** in your browser.
2. Click the **Hamburger Menu (Top Left) > Explore**.
3. In the top-left dropdown, ensure the data source is set to **Loki** (this was auto-provisioned for you).
4. **How to query logs**:
   - Click the **Label Filters** button.
   - Select `container` from the first dropdown.
   - Select the container you want to view (e.g., `roi_blue-backend-1` or `roi_db_backup`).
   - Click **Run query** (top right) to see the logs instantly.
5. **Live Tailing**: Click the "Live" button in the top right to watch the logs stream in real-time as users interact with the app.

> 🧠 **Why do we need to select "Loki" as the Data Source?**
> Grafana is just a "TV Screen" (a visualization UI). It doesn't store any data itself. It connects to multiple "channels" (Data Sources).
> - **Prometheus** only understands *Numbers* (e.g., CPU is at 80%, Memory is at 2GB). It draws graphs.
> - **Loki** only understands *Text* (e.g., `Error: Database connection failed`). It shows logs.
> When you want to read logs, you have to tell the TV Screen to tune into the "Loki" channel!
> 
> **Can we show multiple data sources at once?**
> Yes! In the Explore tab, you can click the **Split** button (looks like a split screen icon) near the top right. You can put Prometheus on the left screen to watch CPU spikes, and put Loki on the right screen to see the exact logs that were printing during that exact CPU spike. This is the superpower of Grafana!

### 💡 Useful LogQL (Loki) Queries
Loki uses LogQL. You can type these directly into the query bar in Grafana:
- **Show all backend errors**: `{container=~"roi_.*-backend-1"} |= "error" `
- **Show database backup logs**: `{container="roi_db_backup"}`
- **Filter out noisy polling logs**: `{container=~"roi_.*-backend-1"} != "GET /api/admin/support/unread-count"`

---

## 📈 How to View Server Metrics (Prometheus)

1. Open **Grafana** and go to **Dashboards**.
2. Grafana automatically loads pre-provisioned dashboards from the `monitoring/grafana/dashboards` directory.
3. You will see dashboards for:
   - **Node Exporter Full**: View exact CPU %, RAM %, and Disk I/O of your AWS EC2 instance.
   - **Docker Containers**: View how much CPU/RAM each specific Docker container is consuming.
   - **API Metrics**: View exact request rates, response times, and 500/400 error rates from the backend.

---

## 💾 Disaster Recovery (Automated Backups)

While not strictly monitoring, the backup container (`roi_db_backup`) runs within the same decoupled infrastructure stack (`docker-compose.infra.yml`).

- **When does it run?** Every single day at **2:00 AM** server time.
- **What does it do?** It uses `mysqldump` to snapshot the production RDS database, compresses it using `gzip`, and streams it directly to your AWS S3 bucket.
- **How to monitor it?** You can view the output of the backup script directly in Grafana Loki by searching for `{container="roi_db_backup"}`.

---

## 🏗️ Architectural Insight: Infrastructure Decoupling

You may notice we have two separate Compose files:
1. `docker-compose.yml` (The App Layer: Frontend, Backend, Cron)
2. `docker-compose.infra.yml` (The Infra Layer: Monitoring, Backups)

This is a **Blue/Green Deployment pattern**. By decoupling the infrastructure, the GitHub Action deployment script can safely shut down, hot-swap, and restart the backend application containers (`roi_blue` and `roi_green`) *without* ever bringing down Grafana, Prometheus, or interrupting a database backup. 

---

## 📂 File Structure Reference

If you need to modify the monitoring configurations, here is exactly where everything lives:

| File / Folder | Purpose |
|---------------|---------|
| `docker-compose.infra.yml` | The isolated Docker Compose file that spins up the entire monitoring stack. Decoupled from the App layer to ensure zero downtime. |
| `monitoring/prometheus.yml` | Configures what targets Prometheus scrapes for metrics (e.g., the backend `/api/metrics`). |
| `monitoring/loki-config.yml` | Configures how Loki stores your log data on the disk (retention policies, storage limits). |
| `monitoring/promtail-config.yml` | Configures Promtail to read `/var/run/docker.sock` and automatically label logs with the exact container name. |
| `monitoring/grafana/provisioning/datasources/loki.yml` | Automatically connects Grafana to Loki upon startup without requiring manual UI configuration. |
| `monitoring/grafana/dashboards/` | Stores the JSON models for the visual dashboards you see in Grafana. |
