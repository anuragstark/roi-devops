#!/bin/sh

# Fail if any command fails
set -e

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="roi_platform_backup_$TIMESTAMP.sql.gz"
S3_URI="s3://$AWS_S3_BUCKET/database-backups/$BACKUP_FILE"

echo "[$(date)] Starting ROI Platform Database Backup..."

# 1. Dump the database and compress it
# --no-tablespaces prevents permissions errors if the AWS RDS user lacks PROCESS privileges
echo "[$(date)] Running mysqldump..."
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" --no-tablespaces | gzip > /tmp/$BACKUP_FILE

# 2. Upload to AWS S3
echo "[$(date)] Uploading to S3 bucket ($S3_URI)..."
aws s3 cp /tmp/$BACKUP_FILE $S3_URI

# 3. Cleanup
rm /tmp/$BACKUP_FILE

echo "[$(date)] Backup completed successfully!"
