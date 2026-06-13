# ADR-003: SOPS over SSM Parameter Store

## Status
Accepted

## Context
We needed a secrets management solution for environment variables (DB passwords, JWT secrets, API keys). Options:
- AWS SSM Parameter Store (used in TeleDoc)
- AWS Secrets Manager (managed, $0.40/secret/month)
- SOPS + age (encrypt in Git, decrypt in CI)
- HashiCorp Vault (enterprise-grade, overkill)

## Decision
**SOPS + age encryption** for Git-native secrets, with **AWS Secrets Manager** for runtime secrets that Lambda/EC2 need to fetch dynamically.

## Rationale
1. **Git-native** — SOPS encrypts `.env` files and commits them to Git. No external dependency at deploy time.
2. **Offline-capable** — Unlike SSM, decryption works without AWS connectivity.
3. **Different from TeleDoc** — TeleDoc uses SSM Parameter Store with ASG user-data. Using SOPS + Secrets Manager shows knowledge of multiple secrets management approaches.
4. **Dual approach** — SOPS for CI/CD secrets, Secrets Manager for runtime secrets = covers two tools on resume.

## Consequences
- Must securely store the `age` private key (not in Git).
- Team members need the key to decrypt locally.
- CI/CD pipeline needs the key as a GitHub Secret.
