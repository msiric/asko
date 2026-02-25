# asko — Security-first self-hosted AI assistant stack

.PHONY: setup start stop restart test lint health backup update restore pull-models import-workflows logs clean

# === Setup & Lifecycle ===

setup: ## Run interactive setup wizard
	./setup.sh

start: ## Start all services
	docker compose up -d

stop: ## Stop all services
	docker compose stop

restart: ## Restart all services
	docker compose restart

down: ## Stop and remove containers (preserves volumes)
	docker compose down

# === Testing ===

test: ## Run all tests
	./tests/run-all.sh

test-unit: ## Run unit tests only
	bats tests/unit/

test-compose: ## Run compose validation tests
	bats tests/compose/

test-templates: ## Run template tests
	bats tests/templates/

test-security: ## Run security tests
	bats tests/security/

# === Linting ===

lint: ## Run ShellCheck on all scripts
	shellcheck setup.sh scripts/*.sh tests/run-all.sh

lint-yaml: ## Validate YAML configs
	python3 -c "import yaml; yaml.safe_load(open('config/litellm/config.yaml.template'))"

lint-toml: ## Validate TOML configs
	python3 -c "import tomllib; tomllib.loads(open('config/ironclaw/config.toml.template').read())"

lint-compose: ## Validate docker-compose.yml
	docker compose config --quiet

lint-all: lint lint-yaml lint-toml lint-compose ## Run all linters

# === Operations ===

health: ## Check service health
	./scripts/health-check.sh

backup: ## Create backup of databases and configs
	./scripts/backup.sh

update: ## Safely update all services (backup first)
	./scripts/update.sh

restore: ## Restore from backup (usage: make restore DIR=backups/20260225_120000)
	./scripts/restore.sh $(DIR)

pull-models: ## Download Ollama models based on available RAM
	./scripts/pull-models.sh

import-workflows: ## Import n8n workflow templates
	./scripts/import-workflows.sh

# === Logs ===

logs: ## Follow all service logs
	docker compose logs -f

logs-ollama: ## Follow Ollama logs
	docker compose logs -f ollama

logs-litellm: ## Follow LiteLLM logs
	docker compose logs -f litellm

logs-n8n: ## Follow n8n logs
	docker compose logs -f n8n

# === Info ===

status: ## Show container status
	docker compose ps

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
