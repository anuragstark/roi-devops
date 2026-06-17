FROM alpine:3.19

# Install required tools: mysql-client for mysqldump, aws-cli for S3 upload
RUN apk add --no-cache mysql-client aws-cli tzdata

WORKDIR /app

# Copy the backup script
COPY backup.sh .
RUN chmod +x backup.sh

# Run the backup job every day at 2:00 AM server time
RUN echo "0 2 * * * /app/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

# Start the cron daemon in the foreground
CMD ["crond", "-f", "-l", "2"]
