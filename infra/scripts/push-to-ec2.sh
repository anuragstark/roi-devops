#!/bin/bash

# Usage: ./push-to-ec2.sh <EC2_PUBLIC_IP> <KEY_PATH>
# Example: ./push-to-ec2.sh 1.2.3.4 ~/.ssh/roi-platform-key.pem

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <EC2_PUBLIC_IP> <KEY_PATH>"
    exit 1
fi

EC2_IP=$1
KEY_PATH=$2

echo "🚀 Syncing code to EC2 ($EC2_IP)..."

# Ensure key has correct permissions
chmod 400 "$KEY_PATH"

# Get absolute path to project root (2 levels up from script)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Sync files using rsync
# Excludes heavy/unnecessary folders
rsync -avz --progress \
  --exclude 'node_modules' \
  --exclude '.git' \
  --exclude '.next' \
  --exclude 'dist' \
  --exclude 'infra' \
  --exclude 'infra2' \
  --exclude '.env' \
  --exclude '.DS_Store' \
  -e "ssh -i $KEY_PATH -o StrictHostKeyChecking=no" \
  "$PROJECT_ROOT/" ubuntu@$EC2_IP:/home/ubuntu/app/

echo "✅ Code synced!"

echo "🔄 Rebuilding and restarting containers..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$EC2_IP << EOF
  cd /home/ubuntu/app
  
  # Create a default .env if not exists (you should allow user to upload their own .env)
  if [ ! -f .env ]; then
      echo "No .env file found! Please upload one."
  fi

  # Build and start
  docker compose down --remove-orphans || true
  docker compose up -d --build
EOF

echo "🎉 Deployment complete!"
