# ============================================================
# ROI Platform — Developer Workflow Automation
# ============================================================
# Usage: make <target>
# Run `make help` to see all available targets
# ============================================================

.PHONY: help dev build deploy logs backup test lint infra-plan infra-apply clean

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ======================== Development ========================

dev: ## Start local development environment
	docker compose -f docker-compose.dev.yml up --build

dev-down: ## Stop local development environment
	docker compose -f docker-compose.dev.yml down

# ======================== Production =========================

build: ## Build production Docker images
	docker compose -f docker-compose.yml build

deploy: ## Deploy to production (push to main triggers CI/CD)
	git push origin main

logs: ## View production backend logs (last 100 lines)
	ssh ubuntu@3.222.210.129 'docker logs roi_backend --tail 100 -f'

logs-all: ## View all production container logs
	ssh ubuntu@3.222.210.129 'docker compose logs --tail 50 -f'

status: ## Check production container status
	ssh ubuntu@3.222.210.129 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# ======================== Database ===========================

backup: ## Trigger manual database backup to S3
	ssh ubuntu@3.222.210.129 'docker exec roi_db_backup /backup.sh'

migrate: ## Run Prisma migrations in production
	ssh ubuntu@3.222.210.129 'docker exec roi_backend npx prisma db push'

# ======================== Testing ============================

test: ## Run backend tests
	cd backend && npm test

lint: ## Run linters for backend and frontend
	cd backend && npm run lint
	cd frontend && npm run lint

# ======================== Infrastructure =====================

infra-init: ## Initialize Terraform
	cd infra/terraform && terraform init

infra-plan: ## Preview Terraform changes
	cd infra/terraform && terraform plan

infra-apply: ## Apply Terraform changes
	cd infra/terraform && terraform apply

infra-destroy: ## Destroy all Terraform-managed infrastructure
	cd infra/terraform && terraform destroy

# ======================== Monitoring =========================

monitoring-up: ## Start monitoring stack
	docker compose -f docker-compose.infra.yml up -d

monitoring-down: ## Stop monitoring stack
	docker compose -f docker-compose.infra.yml down

# ======================== Cleanup ============================

clean: ## Clean Docker artifacts (images, volumes, networks)
	docker system prune -af
	docker volume prune -f

clean-logs: ## Clean container logs on production
	ssh ubuntu@3.222.210.129 'sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log'
