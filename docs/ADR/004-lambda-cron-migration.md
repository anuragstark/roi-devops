# ADR-004: Lambda Cron Migration

## Status
Proposed

## Context
The ROI platform runs a cron job every hour to credit ROI to active investments. Currently this runs as a dedicated Docker container (`roi-cron`) that stays running 24/7 and executes a Node.js script on schedule via `node-cron`.

## Decision
**Migrate the cron worker from Docker container to AWS Lambda + EventBridge Scheduler.**

## Rationale
1. **Cost reduction** — The roi-cron container consumes ~100MB RAM 24/7 on an already-constrained t3.small. Lambda runs only when triggered (~60s/hour = 720 invocations/month).
2. **Serverless keyword** — AWS Lambda is the most requested skill in cloud job postings.
3. **Reliability** — EventBridge Scheduler is managed by AWS with built-in retry and dead-letter queues.
4. **Scalability** — If we need multiple cron jobs, we add more Lambda functions instead of containers.

## Consequences
- Lambda has a 15-minute timeout (our job takes ~30s, so this is fine).
- Lambda needs RDS network access (must be in the same VPC or RDS must be publicly accessible).
- Cold start adds ~2s to first invocation (acceptable for hourly cron).
- Prisma client bundle size may be large — may need `prisma generate --accelerate` or raw SQL.
