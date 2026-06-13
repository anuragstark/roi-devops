# Deployment Guide

## Prerequisites

- Node.js 18+ installed
- MySQL 8.0+ database
- AWS account (for S3, SES, etc.)
- Moralis API key (for USDT)
- Razorpay account (for INR)

## Quick Start

### 1. Clone and Install
```bash
cd backend
npm install
```

### 2. Configure Environment
Create `.env` file with required variables (see `.env.example`)

### 3. Database Setup
```bash
# Generate Prisma client
npm run prisma:generate

# Run migrations (create database first)
npm run prisma:migrate deploy

# Seed admin user
SEED_ADMIN_EMAIL=admin@example.com SEED_ADMIN_PASSWORD='SecurePass123!' npm run seed:admin
```

### 4. Start Development Server
```bash
npm run dev
```

### 5. Start Cron Jobs (separate terminals)
```bash
# ROI Credit Cron
npm run cron:roi

# Salary Credit Cron
npm run cron:salary
```

## Production Deployment

### Using PM2
```bash
# Build
npm run build

# Start app
pm2 start dist/index.js --name roi-backend

# Start cron jobs
pm2 start npm --name roi-cron -- run cron:roi
pm2 start npm --name salary-cron -- run cron:salary

# Save PM2 config
pm2 save
pm2 startup
```

### Using Docker
```bash
# Build image
docker build -t roi-backend .

# Run container
docker run -d \
  --name roi-backend \
  -p 8080:8080 \
  --env-file .env \
  roi-backend
```

### Using Docker Compose
```yaml
version: '3.8'
services:
  backend:
    build: .
    ports:
      - "8080:8080"
    env_file: .env
    depends_on:
      - mysql
      - redis
  
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: roi_platform
    volumes:
      - mysql_data:/var/lib/mysql
  
  redis:
    image: redis:alpine
```

## AWS ECS Deployment

1. Build and push Docker image to ECR
2. Create ECS task definition
3. Create ECS service
4. Configure load balancer
5. Set up CloudWatch logging

## Environment Variables

See `backend/.env.example` for all required variables.

### Critical Variables
- `DATABASE_URL` - MySQL connection string
- `JWT_ACCESS_SECRET` - Strong random secret
- `JWT_REFRESH_SECRET` - Strong random secret
- `MORALIS_API_KEY` - Moralis API key
- `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` - Razorpay credentials

## Health Checks

- `GET /health` - Basic health check
- `GET /health?db=true` - Include database check

## Monitoring

- Monitor `/health` endpoint
- Set up CloudWatch alarms
- Track error rates
- Monitor database connections
- Watch cron job execution

## Security Checklist

- [ ] Strong JWT secrets
- [ ] Database credentials secured
- [ ] API keys encrypted
- [ ] HTTPS enabled
- [ ] Rate limiting configured
- [ ] CORS properly configured
- [ ] Input validation enabled
- [ ] SQL injection protection (Prisma)
- [ ] XSS protection headers
- [ ] Regular security updates

## Troubleshooting

### Database Connection Issues
- Check DATABASE_URL format
- Verify database is accessible
- Check firewall rules

### Cron Jobs Not Running
- Verify cron schedule format
- Check logs for errors
- Ensure database connection

### API Errors
- Check environment variables
- Verify integration credentials
- Review error logs

## Support

For issues or questions, refer to:
- Day-by-day documentation in `docs/day-XX/`
- API endpoint documentation
- Prisma schema for data models

