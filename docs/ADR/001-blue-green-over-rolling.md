# ADR-001: Blue/Green Deployment over Rolling Updates

## Status
Accepted

## Context
We needed a zero-downtime deployment strategy for the ROI platform running on a single EC2 instance. Common options include:
- Rolling updates (Kubernetes-style)
- Blue/Green via Nginx port swap
- ASG Instance Refresh (used in TeleDoc)

## Decision
**Blue/Green via Nginx port swap** — deploy new containers on alternate ports, health check, then swap Nginx upstream with `systemctl reload nginx`.

## Rationale
1. **Single server** — Rolling updates require multiple replicas (Kubernetes). We run on one EC2.
2. **Instant rollback** — If health check fails, we simply don't swap Nginx and tear down the new containers.
3. **Zero infrastructure cost** — No load balancer or ASG needed. Nginx reload is atomic (zero-downtime).
4. **Different from TeleDoc** — TeleDoc uses ASG Instance Refresh. Using a different approach demonstrates breadth of deployment knowledge.

## Consequences
- Requires enough memory on EC2 to run both blue and green simultaneously during deployment (~60 seconds).
- The CI/CD pipeline is slightly more complex (port detection, nginx sed, old environment teardown).
