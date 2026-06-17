FROM alpine:3.20

# Install msmtp for sending emails, curl for endpoints, docker-cli to inspect containers
RUN apk add --no-cache msmtp curl docker-cli tzdata

# Set timezone
ENV TZ=UTC

WORKDIR /app
COPY health-check.sh /app/health-check.sh
RUN chmod +x /app/health-check.sh

# Run via a simple while loop (every 12 hours = 43200 seconds)
# We sleep first so it doesn't instantly send an email on every docker compose up (unless configured differently)
CMD ["sh", "-c", "echo 'Health check cron started' && while true; do /app/health-check.sh; sleep 43200; done"]
