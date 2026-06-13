# ADR-002: Loki + Promtail over CloudWatch Logs

## Status
Accepted

## Context
We needed centralized logging for all Docker containers (backend, frontend, cron, monitoring stack). Options:
- AWS CloudWatch Logs (managed, pay-per-GB)
- Loki + Promtail (self-hosted, free, Grafana-native)

## Decision
**Loki + Promtail** for self-hosted centralized logging with Grafana integration.

## Rationale
1. **Cost** — CloudWatch charges per GB ingested ($0.50/GB). Loki runs on existing EC2 for free.
2. **Grafana integration** — We already run Grafana for Prometheus metrics. Loki gives us logs + metrics + traces in a single pane of glass.
3. **Different from TeleDoc** — TeleDoc uses CloudWatch Logs via IAM policies. Using Loki shows proficiency with both managed and self-hosted logging solutions.
4. **No vendor lock-in** — Loki uses LogQL (similar to PromQL), making our logging stack portable.

## Consequences
- We own the operational burden (disk space, log rotation, Loki upgrades).
- Container log rotation must be configured (`daemon.json`) to prevent disk exhaustion.
- No automatic log retention policies — must configure manually.
