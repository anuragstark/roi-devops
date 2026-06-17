#!/bin/sh
# ROI Platform — 12-Hour Health Digest
# Checks all services and sends a formatted HTML status email

set -e

TO_EMAIL="${ALERT_EMAIL:-anuragchauhan536@gmail.com}"
FROM_EMAIL="${FROM_EMAIL:-anuragchauhan536@gmail.com}"
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-anuragchauhan536@gmail.com}"
SMTP_PASS="${SMTP_PASS}"
PLATFORM_URL="${PLATFORM_URL:-https://paisatest.online}"

TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")
HOSTNAME=$(hostname)

# --- Helper: Check HTTP endpoint ---
check_endpoint() {
  NAME="$1"
  URL="$2"
  TIMEOUT="${3:-5}"

  START=$(date +%s%N 2>/dev/null || date +%s)
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$URL" 2>/dev/null || echo "000")
  END=$(date +%s%N 2>/dev/null || date +%s)

  # Calculate response time in ms (fallback to seconds if %N not supported)
  if echo "$START" | grep -q "N"; then
    RESPONSE_MS="N/A"
  else
    RESPONSE_MS=$(( (END - START) / 1000000 ))
  fi

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ] 2>/dev/null; then
    STATUS="✅ Healthy"
    COLOR="#22c55e"
  else
    STATUS="❌ Down (HTTP $HTTP_CODE)"
    COLOR="#ef4444"
    OVERALL_HEALTHY=false
  fi

  echo "<tr>
    <td style='padding:10px 14px;border-bottom:1px solid #e2e8f0;font-weight:500;'>$NAME</td>
    <td style='padding:10px 14px;border-bottom:1px solid #e2e8f0;color:$COLOR;font-weight:600;'>$STATUS</td>
    <td style='padding:10px 14px;border-bottom:1px solid #e2e8f0;'>${RESPONSE_MS}ms</td>
  </tr>"
}

# --- Helper: Check Docker container ---
check_container() {
  NAME="$1"
  CONTAINER="$2"

  STATE=$(docker inspect --format='{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "not_found")
  RESTARTS=$(docker inspect --format='{{.RestartCount}}' "$CONTAINER" 2>/dev/null || echo "?")
  UPTIME=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null | cut -d'T' -f1 || echo "?")

  if [ "$STATE" = "running" ]; then
    STATUS="✅ Running"
    COLOR="#22c55e"
  elif [ "$STATE" = "restarting" ]; then
    STATUS="🔄 Restarting"
    COLOR="#f59e0b"
    OVERALL_HEALTHY=false
  elif [ "$STATE" = "not_found" ]; then
    STATUS="❌ Not Found"
    COLOR="#ef4444"
    OVERALL_HEALTHY=false
  else
    STATUS="❌ $STATE"
    COLOR="#ef4444"
    OVERALL_HEALTHY=false
  fi

  echo "<tr>
    <td style='padding:10px 14px;border-bottom:1px solid #e2e8f0;font-weight:500;'>$NAME</td>
    <td style='padding:10px 14px;border-bottom:1px solid #e2e8f0;color:$COLOR;font-weight:600;'>$STATUS</td>
    <td style='padding:10px 14px;border-bottom:1px solid #e2e8f0;'>Restarts: $RESTARTS</td>
  </tr>"
}

# --- Collect System Metrics ---
CPU_USAGE=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' || echo "N/A")
MEM_TOTAL=$(free -m 2>/dev/null | awk '/Mem:/{print $2}' || echo "?")
MEM_USED=$(free -m 2>/dev/null | awk '/Mem:/{print $3}' || echo "?")
MEM_PCT=$(free 2>/dev/null | awk '/Mem:/{printf "%.1f", $3/$2*100}' || echo "N/A")
DISK_PCT=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' || echo "N/A")
DISK_AVAIL=$(df -h / 2>/dev/null | awk 'NR==2{print $4}' || echo "N/A")
SWAP_PCT=$(free 2>/dev/null | awk '/Swap:/{if($2>0) printf "%.1f", $3/$2*100; else print "0"}' || echo "N/A")

OVERALL_HEALTHY=true

# --- Build Endpoint Checks ---
ENDPOINT_ROWS=""
ENDPOINT_ROWS="${ENDPOINT_ROWS}$(check_endpoint 'Frontend (Website)' "$PLATFORM_URL" 10)"
ENDPOINT_ROWS="${ENDPOINT_ROWS}$(check_endpoint 'Backend API' "$PLATFORM_URL/api/health" 10)"
ENDPOINT_ROWS="${ENDPOINT_ROWS}$(check_endpoint 'Prometheus' 'http://roi_prometheus:9090/-/healthy' 5)"
ENDPOINT_ROWS="${ENDPOINT_ROWS}$(check_endpoint 'Grafana' 'http://roi_grafana:3000/api/health' 5)"
ENDPOINT_ROWS="${ENDPOINT_ROWS}$(check_endpoint 'Loki' 'http://roi_loki:3100/ready' 5)"
ENDPOINT_ROWS="${ENDPOINT_ROWS}$(check_endpoint 'Tempo' 'http://roi_tempo:3200/ready' 5)"
ENDPOINT_ROWS="${ENDPOINT_ROWS}$(check_endpoint 'Alertmanager' 'http://roi_alertmanager:9093/-/healthy' 5)"

# --- Build Container Checks ---
CONTAINER_ROWS=""
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'Prometheus' 'roi_prometheus')"
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'Grafana' 'roi_grafana')"
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'Loki' 'roi_loki')"
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'Promtail' 'roi_promtail')"
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'Tempo' 'roi_tempo')"
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'Alertmanager' 'roi_alertmanager')"
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'Redis' 'roi_redis')"
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'Node Exporter' 'roi_node_exporter')"
CONTAINER_ROWS="${CONTAINER_ROWS}$(check_container 'DB Backup' 'roi_db_backup')"

# --- Overall Status ---
if [ "$OVERALL_HEALTHY" = true ]; then
  BADGE="✅ All Systems Operational"
  BADGE_COLOR="#22c55e"
  SUBJECT="✅ ROI Platform Health Digest — All OK — $TIMESTAMP"
else
  BADGE="⚠️ Issues Detected"
  BADGE_COLOR="#ef4444"
  SUBJECT="🚨 ROI Platform Health Digest — Issues Found — $TIMESTAMP"
fi

# --- Build HTML Email ---
HTML_BODY="<!DOCTYPE html><html><head><meta charset='utf-8'></head><body style='margin:0;padding:0;background:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;'>
<div style='max-width:640px;margin:20px auto;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 6px rgba(0,0,0,0.07);'>

  <!-- Header -->
  <div style='background:linear-gradient(135deg,#1e293b 0%,#334155 100%);padding:28px 30px;'>
    <h1 style='margin:0;color:#ffffff;font-size:22px;'>🏥 ROI Platform Health Digest</h1>
    <p style='margin:6px 0 0;color:#94a3b8;font-size:13px;'>$TIMESTAMP · $HOSTNAME</p>
  </div>

  <!-- Overall Badge -->
  <div style='padding:20px 30px;text-align:center;'>
    <span style='display:inline-block;padding:10px 24px;background:${BADGE_COLOR}15;border:1.5px solid $BADGE_COLOR;border-radius:8px;color:$BADGE_COLOR;font-weight:700;font-size:16px;'>$BADGE</span>
  </div>

  <!-- System Resources -->
  <div style='padding:0 30px 20px;'>
    <h2 style='font-size:16px;color:#1e293b;border-bottom:2px solid #e2e8f0;padding-bottom:8px;'>📊 System Resources</h2>
    <table style='width:100%;border-collapse:collapse;font-size:14px;'>
      <tr>
        <td style='padding:8px 0;color:#64748b;'>CPU Usage</td>
        <td style='padding:8px 0;font-weight:600;text-align:right;'>${CPU_USAGE}%</td>
      </tr>
      <tr>
        <td style='padding:8px 0;color:#64748b;'>Memory</td>
        <td style='padding:8px 0;font-weight:600;text-align:right;'>${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PCT}%)</td>
      </tr>
      <tr>
        <td style='padding:8px 0;color:#64748b;'>Disk</td>
        <td style='padding:8px 0;font-weight:600;text-align:right;'>${DISK_AVAIL} free (${DISK_PCT} used)</td>
      </tr>
      <tr>
        <td style='padding:8px 0;color:#64748b;'>Swap</td>
        <td style='padding:8px 0;font-weight:600;text-align:right;'>${SWAP_PCT}%</td>
      </tr>
    </table>
  </div>

  <!-- Endpoint Health -->
  <div style='padding:0 30px 20px;'>
    <h2 style='font-size:16px;color:#1e293b;border-bottom:2px solid #e2e8f0;padding-bottom:8px;'>🌐 Endpoint Health</h2>
    <table style='width:100%;border-collapse:collapse;font-size:14px;'>
      <tr style='background:#f8fafc;'>
        <th style='padding:10px 14px;text-align:left;color:#64748b;font-weight:600;'>Service</th>
        <th style='padding:10px 14px;text-align:left;color:#64748b;font-weight:600;'>Status</th>
        <th style='padding:10px 14px;text-align:left;color:#64748b;font-weight:600;'>Response</th>
      </tr>
      $ENDPOINT_ROWS
    </table>
  </div>

  <!-- Container Status -->
  <div style='padding:0 30px 20px;'>
    <h2 style='font-size:16px;color:#1e293b;border-bottom:2px solid #e2e8f0;padding-bottom:8px;'>🐳 Container Status</h2>
    <table style='width:100%;border-collapse:collapse;font-size:14px;'>
      <tr style='background:#f8fafc;'>
        <th style='padding:10px 14px;text-align:left;color:#64748b;font-weight:600;'>Container</th>
        <th style='padding:10px 14px;text-align:left;color:#64748b;font-weight:600;'>Status</th>
        <th style='padding:10px 14px;text-align:left;color:#64748b;font-weight:600;'>Info</th>
      </tr>
      $CONTAINER_ROWS
    </table>
  </div>

  <!-- Footer -->
  <div style='padding:16px 30px;background:#f8fafc;border-top:1px solid #e2e8f0;text-align:center;'>
    <p style='margin:0;color:#94a3b8;font-size:12px;'>ROI Platform Monitoring · Sent automatically every 12 hours</p>
  </div>

</div>
</body></html>"

# --- Send Email via msmtp ---
{
  echo "From: $FROM_EMAIL"
  echo "To: $TO_EMAIL"
  echo "Subject: $SUBJECT"
  echo "MIME-Version: 1.0"
  echo "Content-Type: text/html; charset=utf-8"
  echo ""
  echo "$HTML_BODY"
} | msmtp --host="$SMTP_HOST" --port="$SMTP_PORT" --auth=on --user="$SMTP_USER" --password="$SMTP_PASS" --tls=on --from="$FROM_EMAIL" "$TO_EMAIL"

echo "[$(date -u +"%Y-%m-%d %H:%M UTC")] Health digest sent to $TO_EMAIL"
