#!/bin/bash

# ROI Platform Deployment Script
# This script deploys the latest version from GitHub

set -e

echo "🚀 Starting ROI Platform deployment..."

# Configuration
APP_DIR="/home/ubuntu/app"
REPO_URL="${GITHUB_REPO:-https://github.com/your-username/roi}"
BRANCH="${GITHUB_BRANCH:-main}"

# Change to app directory
cd $APP_DIR

# Load environment if present to hydrate compose substitutions/ports
if [ -f ".env" ]; then
    set -a
    . ./.env
    set +a
fi

FRONTEND_PORT="${FRONTEND_PORT:-3000}"
BACKEND_PORT="${BACKEND_PORT:-5000}"
APP_HEALTHCHECK_URL="${APP_HEALTHCHECK_URL:-http://localhost:${BACKEND_PORT}/api/health}"

# Pull latest code
echo "📥 Pulling latest code from GitHub..."
if [ -d ".git" ]; then
    git fetch origin
    git reset --hard origin/$BRANCH
else
    git clone -b $BRANCH $REPO_URL .
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker compose down || true

# Remove old images (optional - saves space)
echo "🧹 Cleaning up old images..."
docker system prune -f

# Build and start containers
echo "🐳 Building and starting Docker containers..."
docker compose -f docker-compose.yml up -d --build

# Wait for containers to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check container status
echo "📊 Container status:"
docker compose ps

# Check backend health
echo "🏥 Checking backend health..."
MAX_RETRIES=30
RETRY_COUNT=0
until curl -f "${APP_HEALTHCHECK_URL}" > /dev/null 2>&1 || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
    echo "Waiting for backend to be ready... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Backend failed to start properly"
    echo "📋 Backend logs:"
    docker compose logs backend
    exit 1
fi

echo "✅ Backend is healthy!"

# Display logs
echo "📋 Recent logs:"
docker compose logs --tail=50

# Get container IPs
FRONTEND_PORT=$(docker compose port frontend 80 2>/dev/null || echo "3000")
BACKEND_PORT=$(docker compose port backend 5000 2>/dev/null || echo "5000")

echo ""
echo "✨ Deployment completed successfully!"
echo ""
echo "🌐 Application URLs:"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "   Frontend: http://${PUBLIC_IP}:${FRONTEND_PORT}"
echo "   Backend:  http://${PUBLIC_IP}:${BACKEND_PORT}"
echo ""
echo "📋 Useful commands:"
echo "   View logs:     docker compose logs -f"
echo "   Restart:       docker compose restart"
echo "   Stop:          docker compose down"
echo ""
