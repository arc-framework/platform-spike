# ==============================================================================
# A.R.C. Framework Platform - Enterprise Service Orchestration
# ==============================================================================
# Project: Agentic Reasoning Core Framework
# Version: 2.0.0
# Architecture: Core + Plugins Pattern
# ==============================================================================

.DEFAULT_GOAL := help
.PHONY: help init up down restart clean build ps logs health \
        up-minimal up-core-services up-dev up-observability up-security up-full \
        down-minimal down-core-services down-dev down-observability down-security down-full \
        health-success health-all health-core health-plugins health-observability health-security health-services \
        health-core-services health-dev health-observability-profile health-security-profile \
        wait-for-core wait-for-core-services wait-for-dev wait-for-observability-profile wait-for-security-profile wait-for-full \
        validate info status version \
        init-env init-network init-all generate-secrets validate-secrets \
        backup-db restore-db reset-db migrate-db \
        logs-core logs-observability logs-security logs-services \
        shell-postgres shell-redis shell-nats test-connectivity \
        validate-architecture validate-compose validate-paths ci-validate \
        info-core \
        pr task-commit build-base-images validate-dockerfiles validate-structure validate-all \
        analyze-deps analyze-deps-mermaid analyze-deps-json build-impact security-scan security-report \
        track-build-times track-build-times-cold check-image-sizes check-image-sizes-strict \
        _lint-go _lint-py _lint-sh _lint-docker _fmt-go _fmt-py _test-go _test-py _typecheck-py _security-scan \
        check-all lint-all test-all fmt-all

# ==============================================================================
# Configuration Variables
# ==============================================================================
PROJECT_NAME := arc-platform
CONTAINER_PREFIX := arc
ENV_FILE ?= .env
COMPOSE := docker compose
COMPOSE_DIR := deployments/docker

# Service lists for targeted operations
CORE_SERVICES := traefik otel_collector postgres redis nats pulsar infisical unleash
OBSERVABILITY_SERVICES := loki prometheus jaeger grafana
SECURITY_SERVICES := kratos
APP_SERVICES := raymond

# Compose file references
COMPOSE_BASE := $(COMPOSE) -p $(PROJECT_NAME) --env-file $(ENV_FILE) -f $(COMPOSE_DIR)/docker-compose.base.yml
COMPOSE_CORE := $(COMPOSE_BASE) -f $(COMPOSE_DIR)/docker-compose.core.yml
COMPOSE_CORE_SERVICES := $(COMPOSE_CORE) -f $(COMPOSE_DIR)/docker-compose.services.yml
COMPOSE_OBS := $(COMPOSE_CORE) -f $(COMPOSE_DIR)/docker-compose.observability.yml
COMPOSE_CORE_OBS_SERVICES := $(COMPOSE_OBS) -f $(COMPOSE_DIR)/docker-compose.services.yml
COMPOSE_SEC := $(COMPOSE_OBS) -f $(COMPOSE_DIR)/docker-compose.security.yml
COMPOSE_FULL := $(COMPOSE_SEC) -f $(COMPOSE_DIR)/docker-compose.services.yml

# Deployment profiles
PROFILE ?= full

# Color output for better UX
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
MAGENTA := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[1;37m
NC := \033[0m

# Docker optimization
export DOCKER_BUILDKIT := 1
export COMPOSE_DOCKER_CLI_BUILD := 1
export COMPOSE_BAKE := true

# Script paths
SCRIPTS_DIR := ./scripts
SETUP_SCRIPTS := $(SCRIPTS_DIR)/setup

# ==============================================================================
# Help & Documentation
# ==============================================================================
help:
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║        A.R.C. Framework - Enterprise Service Orchestration        ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(WHITE)Architecture: Core + Plugins Pattern$(NC)"
	@echo "$(WHITE)Deployment Profiles: minimal | core-services | dev | observability | security | full$(NC)"
	@echo ""
	@echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(YELLOW)Initialization:$(NC)"
	@echo "  $(GREEN)make init$(NC)              Initialize complete environment (creates .env and network)"
	@echo "  $(GREEN)make init-env$(NC)          Create .env file (interactive)"
	@echo "  $(GREEN)make generate-secrets$(NC)  Generate secure random secrets"
	@echo "  $(GREEN)make validate-secrets$(NC)  Validate secrets configuration"
	@echo "  $(GREEN)make init-network$(NC)      Create Docker network"
	@echo ""
	@echo "$(YELLOW)Common Development Commands:$(NC)"
	@echo "  $(GREEN)make up-core-services$(NC)  Start core services + application services (~3GB RAM)"
	@echo "  $(GREEN)make up-dev$(NC)            Start core + observability + application services (~5GB RAM)"
	@echo "  $(GREEN)make up-observability$(NC)  Start core + observability services (~4GB RAM)"
	@echo "  $(GREEN)make up-full$(NC)           Start all services (~6GB RAM)"
	@echo ""
	@echo "$(YELLOW)Lifecycle Management:$(NC)"
	@echo "  $(GREEN)make up$(NC)                Alias for up-full (default)"
	@echo "  $(GREEN)make down$(NC)              Stop all services (preserves data)"
	@echo "  $(GREEN)make restart$(NC)           Restart all services"
	@echo "  $(GREEN)make build$(NC)             Rebuild custom images"
	@echo "  $(GREEN)make clean$(NC)             Remove containers, networks, and all data volumes"
	@echo "  $(GREEN)make reset$(NC)             Alias for 'make clean' with confirmation"
	@echo ""
	@echo "$(YELLOW)Diagnostics & Monitoring:$(NC)"
	@echo "  $(GREEN)make ps$(NC)                List running containers"
	@echo "  $(GREEN)make status$(NC)            Show comprehensive status"
	@echo "  $(GREEN)make health-all$(NC)        Check health of all services"
	@echo "  $(GREEN)make logs$(NC)              Stream logs from all services"
	@echo ""
	@echo "$(YELLOW)Information:$(NC)"
	@echo "  $(GREEN)make info$(NC)              Display service URLs and credentials"
	@echo "  $(GREEN)make version$(NC)           Display component versions"
	@echo ""
	@echo "$(YELLOW)PR & Git Workflow:$(NC)"
	@echo "  $(GREEN)make pr$(NC)                Generate feature PR description (full feature)"
	@echo "  $(GREEN)make task-commit$(NC)       Generate commit message for task completions"
	@echo ""
	@echo "$(YELLOW)Docker & Validation:$(NC)"
	@echo "  $(GREEN)make build-base-images$(NC) Build shared Docker base images"
	@echo "  $(GREEN)make validate-dockerfiles$(NC) Lint all Dockerfiles with hadolint"
	@echo "  $(GREEN)make validate-structure$(NC) Validate directory structure"
	@echo "  $(GREEN)make validate-all$(NC)      Run all validation checks"
	@echo ""
	@echo "$(YELLOW)Dependency Analysis & Security:$(NC)"
	@echo "  $(GREEN)make analyze-deps$(NC)      Analyze Docker image dependencies"
	@echo "  $(GREEN)make build-impact$(NC)      Show which services need rebuilding (FILE=path)"
	@echo "  $(GREEN)make security-scan$(NC)     Run trivy security scan on images"
	@echo "  $(GREEN)make security-report$(NC)   Generate security compliance report"
	@echo ""
	@echo "$(YELLOW)Build Performance:$(NC)"
	@echo "  $(GREEN)make track-build-times$(NC) Track build times for all services"
	@echo "  $(GREEN)make check-image-sizes$(NC) Validate image sizes against targets"
	@echo ""
	@echo "$(YELLOW)Code Quality Suite:$(NC)"
	@echo "  $(GREEN)make check-all$(NC)         Run ALL checks (Lint + Test + Security) with summary"
	@echo "  $(GREEN)make lint-all$(NC)          Run all linters (Go, Python, Shell, Docker)"
	@echo "  $(GREEN)make test-all$(NC)          Run all tests (Go, Python)"
	@echo "  $(GREEN)make fmt-all$(NC)           Format all code (Go, Python)"
	@echo ""
	@echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(WHITE)Documentation: docs/OPERATIONS.md$(NC)"
	@echo "$(WHITE)Architecture:  docs/architecture/README.md$(NC)"
	@echo ""

# ==============================================================================
# Initialization
# ==============================================================================
init: init-env init-network
	@echo "$(GREEN)✓ Environment initialized successfully$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Review and update .env file with your settings"
	@echo "  2. Run: make up-minimal"

init-env:
	@echo "$(BLUE)Initializing environment configuration...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)No .env file found. Choose initialization method:$(NC)"; \
		echo "  1. Generate with secure random secrets (recommended)"; \
		echo "  2. Copy from template (requires manual configuration)"; \
		read -p "Enter choice (1 or 2): " choice; \
		if [ "$$choice" = "1" ]; then \
			$(SETUP_SCRIPTS)/generate-secrets.sh; \
		else \
			cp .env.example .env; \
			echo "$(GREEN)✓ Created .env from template$(NC)"; \
			echo "$(YELLOW)⚠ SECURITY WARNING: Update all CHANGE_ME values before deployment!$(NC)"; \
		fi \
	else \
		echo "$(YELLOW)⚠ .env already exists, skipping...$(NC)"; \
	fi

generate-secrets:
	@echo "$(BLUE)Generating secure secrets...$(NC)"
	@$(SETUP_SCRIPTS)/generate-secrets.sh

validate-secrets:
	@echo "$(BLUE)Validating secrets configuration...$(NC)"
	@$(SETUP_SCRIPTS)/validate-secrets.sh

init-network:
	@echo "$(BLUE)Creating Docker network...$(NC)"
	@if ! docker network inspect arc_net >/dev/null 2>&1; then \
		docker network create arc_net --driver bridge --subnet 172.20.0.0/16; \
		echo "$(GREEN)✓ Network 'arc_net' created$(NC)"; \
	else \
		echo "$(YELLOW)✓ Network 'arc_net' already exists$(NC)"; \
	fi

# Environment check (dependency for most targets)
.env:
	@if [ ! -f .env ]; then \
		echo "$(RED)✗ .env file not found!$(NC)"; \
		echo "$(YELLOW)Run: make init-env$(NC)"; \
		exit 1; \
	fi

# ==============================================================================
# Deployment Profiles
# ==============================================================================
up-minimal: .env init-network
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Starting MINIMAL Profile (Core Services Only)                     ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	$(COMPOSE_CORE) up -d --build
	@make wait-for-core

up-core-services: .env validate-secrets init-network
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Starting CORE + SERVICES Profile (Core + Application Services)  ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	$(COMPOSE_CORE_SERVICES) up -d --build
	@make wait-for-core-services

up-dev: .env validate-secrets init-network
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Starting DEV Profile (Core + Observability + Application Services)║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	$(COMPOSE_CORE_OBS_SERVICES) up -d --build
	@make wait-for-dev

up-observability: .env init-network
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Starting OBSERVABILITY Profile (Core + Observability)           ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	$(COMPOSE_OBS) up -d --build
	@make wait-for-observability-profile

up-security: .env init-network
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Starting SECURITY Profile (Core + Obs + Security)               ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	$(COMPOSE_SEC) up -d --build
	@make wait-for-security-profile

up-full: .env validate-secrets init-network
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Starting FULL STACK Profile (All Services)                      ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	$(COMPOSE_FULL) up -d --build
	@make wait-for-full

# Default up target points to full stack
up: up-full

# ==============================================================================
# Shutdown Profiles
# ==============================================================================
down-minimal:
	@echo "$(BLUE)Stopping minimal profile...$(NC)"
	$(COMPOSE_CORE) down
	@echo "$(GREEN)✓ Core services stopped$(NC)"

down-core-services:
	@echo "$(BLUE)Stopping core + services profile...$(NC)"
	$(COMPOSE_CORE_SERVICES) down
	@echo "$(GREEN)✓ Core and application services stopped$(NC)"

down-dev:
	@echo "$(BLUE)Stopping dev profile (core + observability + services)...$(NC)"
	$(COMPOSE_CORE_OBS_SERVICES) down
	@echo "$(GREEN)✓ Core, observability, and application services stopped$(NC)"

down-observability:
	@echo "$(BLUE)Stopping observability profile...$(NC)"
	$(COMPOSE_OBS) down
	@echo "$(GREEN)✓ Core and observability services stopped$(NC)"

down-security:
	@echo "$(BLUE)Stopping security profile...$(NC)"
	$(COMPOSE_SEC) down
	@echo "$(GREEN)✓ Core, observability, and security services stopped$(NC)"

down-full:
	@echo "$(BLUE)Stopping full stack...$(NC)"
	$(COMPOSE_FULL) down
	@echo "$(GREEN)✓ All services stopped$(NC)"

down: down-full

# ==============================================================================
# Lifecycle Operations
# ==============================================================================
restart: down up

build: .env
	@echo "$(BLUE)Building custom images...$(NC)"
	$(COMPOSE_FULL) build --parallel
	@echo "$(GREEN)✓ Images built successfully$(NC)"

clean:
	@echo "$(BLUE)Stopping and removing containers, networks, and all data volumes...$(NC)"
	$(COMPOSE_FULL) down -v
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

reset:
	@echo "$(RED)⚠ WARNING: This will remove ALL containers, volumes, and networks!$(NC)"
	@echo "$(RED)⚠ All data will be lost!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		make clean; \
		docker network rm arc_net 2>/dev/null || true; \
		echo "$(GREEN)✓ Complete reset done$(NC)"; \
	else \
		echo "$(YELLOW)Reset cancelled$(NC)"; \
	fi

# ==============================================================================
# Container Management & Health
# ==============================================================================
ps:
	@echo "$(BLUE)Running containers:$(NC)"
	@docker ps --filter "network=arc_net" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

status: ps
	@echo ""
	@make health-all

# Generic wait function with enhanced UX
# Usage: $(call _wait-for,TARGET_NAME,TIMEOUT,HEALTH_TARGET,INFO_TARGET)
define _wait-for
	@printf "$(BLUE)⏳ Waiting for $(1) to become healthy (timeout: $(2)s)...$(NC)\n"
	@ELAPSED=0; \
	INTERVAL=5; \
	MAX_WAIT=$(2); \
	SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"; \
	while [ $$ELAPSED -lt $$MAX_WAIT ]; do \
		HEALTH_OUTPUT=$$($(MAKE) $(3) 2>&1); \
		TOTAL_COUNT=$$(echo "$$HEALTH_OUTPUT" | grep -E "(✓|✗)" | wc -l | tr -d ' '); \
		HEALTHY_COUNT=$$(echo "$$HEALTH_OUTPUT" | grep -c "✓ Healthy" || true); \
		UNHEALTHY_COUNT=$$(echo "$$HEALTH_OUTPUT" | grep -c "✗ Unhealthy" || true); \
		if [ $$UNHEALTHY_COUNT -eq 0 ] && [ $$HEALTHY_COUNT -gt 0 ]; then \
			printf "\r$(GREEN)✓ All $(1) are healthy! ($$HEALTHY_COUNT/$$TOTAL_COUNT services, took $$ELAPSED s)                                              $(NC)\n\n"; \
			$(if $(4),$(MAKE) info-$(4),$(MAKE) info); \
			exit 0; \
		fi; \
		PERCENT=$$((ELAPSED * 100 / MAX_WAIT)); \
		BAR_LEN=$$((PERCENT / 2)); \
		BAR=$$(printf '%*s' $$BAR_LEN | tr ' ' '█'); \
		EMPTY=$$(printf '%*s' $$((50 - BAR_LEN)) | tr ' ' '░'); \
		SPIN_IDX=$$((ELAPSED % 10)); \
		SPIN_CHAR=$$(echo "$$SPINNER" | cut -c$$((SPIN_IDX + 1))); \
		printf "\r  $$SPIN_CHAR [$$BAR$$EMPTY] $$PERCENT%% ($$ELAPSED/$$MAX_WAIT s) | $(GREEN)Healthy: $$HEALTHY_COUNT$(NC) $(YELLOW)Waiting: $$UNHEALTHY_COUNT$(NC)                    "; \
		sleep $$INTERVAL; \
		ELAPSED=$$((ELAPSED + INTERVAL)); \
	done; \
	printf "\r$(RED)✗ Timeout waiting for $(1) ($$MAX_WAIT s exceeded)                                                                  $(NC)\n\n"; \
	HEALTH_OUTPUT=$$($(MAKE) $(3) 2>&1); \
	UNHEALTHY_COUNT=$$(echo "$$HEALTH_OUTPUT" | grep -c "✗ Unhealthy" || true); \
	echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	echo "$(RED)❌ UNHEALTHY SERVICES: $$UNHEALTHY_COUNT$(NC)"; \
	echo "$(RED)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	echo "$$HEALTH_OUTPUT" | grep "✗ Unhealthy" | while read -r line; do \
		SERVICE_NAME=$$(echo "$$line" | awk '{print $$1}'); \
		echo "  $(RED)✗$(NC) $$SERVICE_NAME"; \
	done; \
	echo ""; \
	echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	echo "$(YELLOW)FULL HEALTH STATUS:$(NC)"; \
	echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	$(MAKE) $(3); \
	echo ""; \
	echo "$(YELLOW)Troubleshooting:$(NC)"; \
	echo "  1. Check logs: $(CYAN)make logs$(NC)"; \
	echo "  2. Check status: $(CYAN)docker ps -a | grep arc$(NC)"; \
	echo "  3. Inspect specific service: $(CYAN)docker logs <service_name>$(NC)"; \
	echo "  4. Retry: $(CYAN)make down && make up-<profile>$(NC)"; \
	exit 1
endef

wait-for-core:
	$(call _wait-for,core services,120,health-core,core)

wait-for-core-services:
	$(call _wait-for,core and application services,180,health-core-services,core)

wait-for-dev:
	$(call _wait-for,core+observability+application services,180,health-dev,core)

wait-for-observability-profile:
	$(call _wait-for,core and observability services,180,health-observability-profile,core)

wait-for-security-profile:
	$(call _wait-for,core+observability+security services,180,health-security-profile,core)

wait-for-full:
	$(call _wait-for,all services,180,health-all,) # No specific info target, so call generic info

health-success:
	@echo  "$(GREEN)✓ All services are healthy!$(NC)";

health-all: health-core health-observability health-security health-services

health-core-services: health-core health-services
health-dev: health-core health-observability health-services
health-observability-profile: health-core health-observability
health-security-profile: health-core health-observability health-security

roster:
	@./scripts/show-roster.sh

health-core:
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Core Services Health Status                                     ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@printf "  %-25s" "Traefik (Gateway):"
	@curl -sf http://localhost:80/ping >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@printf "  %-25s" "OTel Collector:"
	@docker exec arc-widow-otel /health_check http://localhost:13133 >/dev/null 2>&1 && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@printf "  %-25s" "PostgreSQL:"
	@docker exec arc-oracle-sql pg_isready -U arc -q && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@printf "  %-25s" "Redis:"
	@docker exec arc-sonic-cache redis-cli ping | grep -q PONG && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@printf "  %-25s" "NATS:"
	@curl -sf http://localhost:8222/healthz >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@printf "  %-25s" "Pulsar:"
	@docker exec arc-strange-stream bin/pulsar-admin brokers healthcheck >/dev/null 2>&1 && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@printf "  %-25s" "Infisical:"
	@curl -sf http://localhost:3001/api/status >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@printf "  %-25s" "Unleash:"
	@curl -sf http://localhost:4242/health >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"
	@echo ""

health-observability:
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Observability Plugins Health Status                             ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@printf "  %-25s" "Loki (Logging):"
	@curl -sf http://localhost:3100/ready >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy/Not Running$(NC)"
	@printf "  %-25s" "Prometheus (Metrics):"
	@curl -sf http://localhost:9090/-/healthy >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy/Not Running$(NC)"
	@printf "  %-25s" "Jaeger (Tracing):"
	@curl -sf http://localhost:16686 >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy/Not Running$(NC)"
	@printf "  %-25s" "Grafana (Visualization):"
	@curl -sf http://localhost:3000/api/health >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy/Not Running$(NC)"
	@echo ""

health-security:
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Security Plugins Health Status                                  ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@printf "  %-25s" "Kratos (Identity):"
	@curl -sf http://localhost:4434/health/alive >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy/Not Running$(NC)"
	@echo ""

health-services:
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Application Services Health Status                              ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@printf "  %-25s" "Raymond:"
	@curl -sf http://localhost:8081/health >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy/Not Running$(NC)"
	@echo ""

# ==============================================================================
# Database Operations
# ==============================================================================
migrate-db:
	@echo "$(BLUE)Running database migrations...$(NC)"
	@echo "$(BLUE)Running Kratos migrations...$(NC)"
	@docker exec arc-deckard-identity kratos migrate sql -e --yes
	@echo "$(GREEN)✓ Kratos migrations complete$(NC)"

backup-db:
	@echo "$(BLUE)Backing up database...$(NC)"
	@mkdir -p ./backups
	@docker exec arc-oracle-sql pg_dump -U arc arc_db > ./backups/arc_db_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✓ Database backed up to ./backups/$(NC)"

restore-db:
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)✗ BACKUP_FILE not specified$(NC)"; \
		echo "$(YELLOW)Usage: make restore-db BACKUP_FILE=./backups/arc_db_20231109_120000.sql$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring database from $(BACKUP_FILE)...$(NC)"
	@docker exec -i arc-oracle-sql psql -U arc arc_db < $(BACKUP_FILE)
	@echo "$(GREEN)✓ Database restored$(NC)"

reset-db:
	@echo "$(RED)⚠ WARNING: This will drop and recreate the database!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker exec arc-oracle-sql psql -U arc -c "DROP DATABASE IF EXISTS arc_db;"; \
		docker exec arc-oracle-sql psql -U arc -c "CREATE DATABASE arc_db;"; \
		make migrate-db; \
		echo "$(GREEN)✓ Database reset complete$(NC)"; \
	else \
		echo "$(YELLOW)Reset cancelled$(NC)"; \
	fi

# ==============================================================================
# Shell Access
# ==============================================================================
shell-postgres:
	@docker exec -it arc-oracle-sql psql -U arc -d arc_db

shell-redis:
	@docker exec -it arc-sonic-cache redis-cli

shell-nats:
	@docker exec -it arc-flash-pulse sh

# ==============================================================================
# Validation & Testing
# ==============================================================================
validate: validate-compose validate-architecture validate-paths validate-labels
	@echo "$(GREEN)✓ All validations passed$(NC)"

validate-compose:
	@echo "$(BLUE)Validating docker-compose files...$(NC)"
	@$(COMPOSE_BASE) config > /dev/null && echo "$(GREEN)✓ Base compose valid$(NC)" || echo "$(RED)✗ Base compose invalid$(NC)"
	@$(COMPOSE_CORE) config > /dev/null && echo "$(GREEN)✓ Core compose valid$(NC)" || echo "$(RED)✗ Core compose invalid$(NC)"
	@$(COMPOSE_CORE_SERVICES) config > /dev/null && echo "$(GREEN)✓ Core Services compose valid$(NC)" || echo "$(RED)✗ Core Services compose invalid$(NC)"
	@$(COMPOSE_OBS) config > /dev/null && echo "$(GREEN)✓ Observability compose valid$(NC)" || echo "$(RED)✗ Observability compose invalid$(NC)"
	@$(COMPOSE_CORE_OBS_SERVICES) config > /dev/null && echo "$(GREEN)✓ Core Observability Services compose valid$(NC)" || echo "$(RED)✗ Core Observability Services compose invalid$(NC)"
	@$(COMPOSE_SEC) config > /dev/null && echo "$(GREEN)✓ Security compose valid$(NC)" || echo "$(RED)✗ Security compose invalid$(NC)"
	@$(COMPOSE_FULL) config > /dev/null && echo "$(GREEN)✓ Full compose valid$(NC)" || echo "$(RED)✗ Full compose invalid$(NC)"

validate-architecture:
	@echo "$(BLUE)Validating architecture alignment...$(NC)"
	@echo "$(YELLOW)Checking directory structure...$(NC)"
	@[ -d "core" ] && echo "$(GREEN)✓ core/ directory exists$(NC)" || echo "$(RED)✗ core/ directory missing$(NC)"
	@[ -d "plugins" ] && echo "$(GREEN)✓ plugins/ directory exists$(NC)" || echo "$(RED)✗ plugins/ directory missing$(NC)"
	@[ -d "services" ] && echo "$(GREEN)✓ services/ directory exists$(NC)" || echo "$(RED)✗ services/ directory missing$(NC)"
	@echo "$(GREEN)✓ Architecture validation complete$(NC)"

validate-paths:
	@echo "$(BLUE)Validating volume mount paths...$(NC)"
	@echo "$(YELLOW)Checking if referenced paths exist...$(NC)"
	@for path in \
		core/telemetry/otel-collector-config.yml \
		core/persistence/postgres/init.sql \
		core/gateway/traefik/traefik.yml \
		plugins/observability/visualization/grafana/provisioning \
		plugins/observability/metrics/prometheus/prometheus.yaml \
		services/utilities/raymond; do \
		if [ -e "$$path" ]; then \
			echo "$(GREEN)✓ $$path$(NC)"; \
		else \
			echo "$(RED)✗ $$path (missing)$(NC)"; \
		fi; \
	done

validate-labels:
	@echo "$(BLUE)Validating service labels...$(NC)"
	@./scripts/verify-labels.sh

test-connectivity:
	@echo "$(BLUE)Testing service connectivity...$(NC)"
	@docker exec arc-oracle-sql pg_isready -h localhost > /dev/null 2>&1 && echo "$(GREEN)✓ Postgres$(NC)" || echo "$(RED)✗ Postgres$(NC)"
	@docker exec arc-sonic-cache redis-cli -h localhost ping > /dev/null 2>&1 && echo "$(GREEN)✓ Redis$(NC)" || echo "$(RED)✗ Redis$(NC)"
	@docker exec arc-flash-pulse wget -q -O- http://localhost:8222/healthz > /dev/null 2>&1 && echo "$(GREEN)✓ NATS$(NC)" || echo "$(RED)✗ NATS$(NC)"

ci-validate: validate build
	@echo "$(GREEN)✓ CI validation complete$(NC)"

# ==============================================================================
# Information & Utilities
# ==============================================================================
info-core:
	@echo ""
	@echo "$(YELLOW)━━━ Core Services ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "  $(WHITE)Traefik (Gateway):$(NC)      http://localhost:8080 (dashboard)"
	@echo "  $(WHITE)PostgreSQL:$(NC)             localhost:5432 (user: arc)"
	@echo "    $(CYAN)Connect: docker exec -it arc-oracle-sql psql -U arc -d arc_db$(NC)"
	@echo "  $(WHITE)Redis:$(NC)                  localhost:6379"
	@echo "  $(WHITE)NATS:$(NC)                   localhost:4222 (monitoring: http://localhost:8222)"
	@echo "  $(WHITE)Pulsar:$(NC)                 localhost:6650 (admin: http://localhost:8082)"
	@echo "  $(WHITE)Infisical:$(NC)              http://localhost:3001"
	@echo "  $(WHITE)Unleash:$(NC)                http://localhost:4242"
	@echo ""

info:
	@make info-core
	@echo "$(YELLOW)━━━ Observability Plugins ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "  $(WHITE)Grafana:$(NC)                http://localhost:3000 (admin/admin)"
	@echo "  $(WHITE)Prometheus:$(NC)             http://localhost:9090"
	@echo "  $(WHITE)Jaeger:$(NC)                 http://localhost:16686"
	@echo "  $(WHITE)Loki:$(NC)                   http://localhost:3100"
	@echo "  $(WHITE)Pulsar Dashboard:$(NC)       http://localhost:8083"
	@echo ""
	@echo "$(YELLOW)━━━ Security Plugins ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "  $(WHITE)Kratos (Public):$(NC)        http://localhost:4433"
	@echo "  $(WHITE)Kratos (Admin):$(NC)         http://localhost:4434"
	@echo ""
	@echo "$(YELLOW)━━━ Application Services ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "  $(WHITE)Raymond:$(NC)                http://localhost:8081"
	@echo ""
	@echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(WHITE)Documentation:$(NC)           docs/OPERATIONS.md"
	@echo "$(WHITE)Architecture:$(NC)            docs/architecture/README.md"
	@echo ""

version:
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║  Component Versions                                               ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "  $(WHITE)Docker:$(NC)         $$(docker --version | cut -d' ' -f3 | tr -d ',')"
	@echo "  $(WHITE)Docker Compose:$(NC) $$(docker compose version --short)"
	@echo "  $(WHITE)Makefile:$(NC)       2.0.0"
	@echo "  $(WHITE)Architecture:$(NC)   Core + Plugins Pattern"
	@echo ""

# ==============================================================================
# Logs
# ==============================================================================
logs:
	@echo "$(BLUE)Streaming logs from all services...$(NC)"
	$(COMPOSE_FULL) logs -f

logs-core:
	@echo "$(BLUE)Streaming logs from core services...$(NC)"
	$(COMPOSE_CORE) logs -f

logs-observability:
	@echo "$(BLUE)Streaming logs from observability services...$(NC)"
	$(COMPOSE_FULL) logs -f loki prometheus jaeger grafana

logs-security:
	@echo "$(BLUE)Streaming logs from security services...$(NC)"
	$(COMPOSE_FULL) logs -f kratos

logs-services:
	@echo "$(BLUE)Streaming logs from application services...$(NC)"
	$(COMPOSE_FULL) logs -f raymond

# ==============================================================================
# Development Helpers
# ==============================================================================
dev: up-dev
	@echo "$(GREEN)✓ Development environment ready$(NC)"
	@echo "$(YELLOW)Core + Observability + Application services are running$(NC)"

prod: up-full
	@echo "$(GREEN)✓ Production environment ready$(NC)"
	@echo "$(YELLOW)All services are running$(NC)"

# ==============================================================================
# PR & Git Workflow
# ==============================================================================

# PR generation variables
PR_BASE_BRANCH ?= main

pr: ## Generate feature PR description (full feature summary)
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Generating Feature PR Description                    ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@./scripts/generate-pr-description.sh $(PR_BASE_BRANCH)

task-commit: ## Generate commit message for intermediate task commits
	@./scripts/generate-task-commit.sh

# ==============================================================================
# Docker Base Images & Validation
# ==============================================================================

build-base-images: ## Build shared Docker base images
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Building Base Images                                 ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo "$(BLUE)Building arc-base-python-ai...$(NC)"
	@docker build -t arc-base-python-ai:local .docker/base/python-ai/
	@echo "$(GREEN)✓ arc-base-python-ai built successfully$(NC)"
	@docker images arc-base-python-ai:local --format "  Size: {{.Size}}"
	@echo ""
	@if [ -d ".docker/base/go-infra" ] && [ -f ".docker/base/go-infra/Dockerfile" ]; then \
		echo "$(BLUE)Building arc-base-go-infra...$(NC)"; \
		docker build -t arc-base-go-infra:local .docker/base/go-infra/; \
		echo "$(GREEN)✓ arc-base-go-infra built successfully$(NC)"; \
		docker images arc-base-go-infra:local --format "  Size: {{.Size}}"; \
	fi

validate-dockerfiles: ## Lint all Dockerfiles with hadolint
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Validating Dockerfiles                               ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@if command -v hadolint >/dev/null 2>&1; then \
		find . -name "Dockerfile" -not -path "*/node_modules/*" -not -path "*/.git/*" | while read -r dockerfile; do \
			echo "$(BLUE)Linting: $$dockerfile$(NC)"; \
			hadolint "$$dockerfile" && echo "$(GREEN)  ✓ Passed$(NC)" || echo "$(RED)  ✗ Failed$(NC)"; \
		done; \
	else \
		echo "$(YELLOW)⚠️  hadolint not installed. Install with: brew install hadolint$(NC)"; \
		exit 1; \
	fi

validate-structure: ## Validate directory structure against SERVICE.MD
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Validating Structure                                 ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@if [ -f "scripts/validate/check-structure.py" ]; then \
		python3 scripts/validate/check-structure.py; \
	else \
		echo "$(YELLOW)⚠️  Validation script not yet implemented$(NC)"; \
		echo "$(BLUE)Checking basic structure...$(NC)"; \
		echo "  core/: $$([ -d core ] && echo '$(GREEN)✓$(NC)' || echo '$(RED)✗$(NC)')"; \
		echo "  plugins/: $$([ -d plugins ] && echo '$(GREEN)✓$(NC)' || echo '$(RED)✗$(NC)')"; \
		echo "  services/: $$([ -d services ] && echo '$(GREEN)✓$(NC)' || echo '$(RED)✗$(NC)')"; \
		echo "  SERVICE.MD: $$([ -f SERVICE.MD ] && echo '$(GREEN)✓$(NC)' || echo '$(RED)✗$(NC)')"; \
	fi

validate-all: validate-structure validate-dockerfiles ## Run all validation checks
	@echo ""
	@echo "$(GREEN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║              All Validations Complete                             ║$(NC)"
	@echo "$(GREEN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"

# ==============================================================================
# Dependency Analysis & Security
# ==============================================================================

analyze-deps: ## Analyze Docker image dependencies
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Analyzing Docker Dependencies                        ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@python3 scripts/validate/analyze-dependencies.py --output tree

analyze-deps-mermaid: ## Generate Mermaid diagram of dependencies
	@python3 scripts/validate/analyze-dependencies.py --output mermaid

analyze-deps-json: ## Export dependencies as JSON
	@python3 scripts/validate/analyze-dependencies.py --output json

build-impact: ## Analyze which services need rebuilding
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Build Impact Analysis                                ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@./scripts/validate/check-build-impact.sh $(FILE)

security-scan: ## Run security scan on Docker images
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Running Security Scan                                ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@if command -v trivy >/dev/null 2>&1; then \
		./scripts/validate/check-security.sh; \
	else \
		echo "$(YELLOW)⚠️  trivy not installed. Install with: brew install trivy$(NC)"; \
		exit 1; \
	fi

security-report: ## Generate security compliance report
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Generating Security Report                           ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@python3 scripts/validate/generate-security-report.py --output markdown

# ==============================================================================
# Build Performance
# ==============================================================================

track-build-times: ## Track build times for all services
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Tracking Build Times                                 ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@./scripts/validate/track-build-times.sh --warm

track-build-times-cold: ## Track cold build times (no cache)
	@./scripts/validate/track-build-times.sh --cold

check-image-sizes: ## Validate image sizes against targets
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Checking Image Sizes                                 ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@python3 scripts/validate/check-image-sizes.py

check-image-sizes-strict: ## Validate image sizes (fail on violation)
	@python3 scripts/validate/check-image-sizes.py --strict

# ==============================================================================
# MODULAR LINT & CHECK TARGETS (Building Blocks)
# ==============================================================================
# These are reusable primitives that can be composed into larger commands.
# Use these for targeted checks during development.
# ==============================================================================

# --- Go Linting ---
_lint-go: ## Lint Go code (raymond service)
	@echo "$(BLUE)Linting Go code...$(NC)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		cd services/utilities/raymond && golangci-lint run --timeout 5m ./...; \
	else \
		echo "$(YELLOW)⚠️  golangci-lint not installed. Install with: brew install golangci-lint$(NC)"; \
		exit 1; \
	fi

_fmt-go: ## Format Go code
	@echo "$(BLUE)Formatting Go code...$(NC)"
	@if command -v gofumpt >/dev/null 2>&1; then \
		find services/utilities/raymond -name "*.go" -exec gofumpt -w {} \;; \
	else \
		echo "$(YELLOW)⚠️  gofumpt not installed. Install with: go install mvdan.cc/gofumpt@latest$(NC)"; \
		gofmt -w services/utilities/raymond; \
	fi

_test-go: ## Run Go tests
	@echo "$(BLUE)Running Go tests...$(NC)"
	@cd services/utilities/raymond && go test -v -race -coverprofile=coverage.out ./...

# --- Python Linting ---
_lint-py: ## Lint Python code with ruff
	@echo "$(BLUE)Linting Python code...$(NC)"
	@if command -v ruff >/dev/null 2>&1; then \
		ruff check libs/python-sdk scripts/validate services/arc-sherlock-brain services/arc-scarlett-voice services/arc-piper-tts 2>/dev/null || true; \
	else \
		echo "$(YELLOW)⚠️  ruff not installed. Install with: pip install ruff$(NC)"; \
		exit 1; \
	fi

_fmt-py: ## Format Python code with black
	@echo "$(BLUE)Formatting Python code...$(NC)"
	@if command -v black >/dev/null 2>&1; then \
		black libs/python-sdk scripts/validate services/arc-sherlock-brain services/arc-scarlett-voice services/arc-piper-tts 2>/dev/null || true; \
	else \
		echo "$(YELLOW)⚠️  black not installed. Install with: pip install black$(NC)"; \
		exit 1; \
	fi

_test-py: ## Run Python tests
	@echo "$(BLUE)Running Python tests...$(NC)"
	@cd libs/python-sdk && python -m pytest -v tests/ 2>/dev/null || true

_typecheck-py: ## Type check Python code with mypy
	@echo "$(BLUE)Type checking Python code...$(NC)"
	@if command -v mypy >/dev/null 2>&1; then \
		mypy libs/python-sdk/arc_common --ignore-missing-imports 2>/dev/null || true; \
	else \
		echo "$(YELLOW)⚠️  mypy not installed. Install with: pip install mypy$(NC)"; \
	fi

# --- Shell Linting ---
_lint-sh: ## Lint shell scripts with shellcheck
	@echo "$(BLUE)Linting shell scripts...$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		find scripts -name "*.sh" -exec shellcheck --severity=warning {} \; 2>/dev/null || true; \
	else \
		echo "$(YELLOW)⚠️  shellcheck not installed. Install with: brew install shellcheck$(NC)"; \
		exit 1; \
	fi

# --- Docker Linting ---
_lint-docker: ## Lint Dockerfiles with hadolint
	@echo "$(BLUE)Linting Dockerfiles...$(NC)"
	@if command -v hadolint >/dev/null 2>&1; then \
		find . -name "Dockerfile" -not -path "*/node_modules/*" -not -path "*/.git/*" -exec hadolint --config .hadolint.yaml {} \; 2>/dev/null || true; \
	else \
		echo "$(YELLOW)⚠️  hadolint not installed. Install with: brew install hadolint$(NC)"; \
		exit 1; \
	fi

# --- Security Scanning ---
_security-scan: ## Run security scan with trivy
	@echo "$(BLUE)Running security scan...$(NC)"
	@if command -v trivy >/dev/null 2>&1; then \
		./scripts/validate/check-security.sh 2>/dev/null || true; \
	else \
		echo "$(YELLOW)⚠️  trivy not installed. Install with: brew install trivy$(NC)"; \
		exit 1; \
	fi

# ==============================================================================
# RESILIENT SUITE RUNNER (The "check-all" Command)
# ==============================================================================
# This runs ALL checks regardless of individual failures.
# Uses failure markers to track which steps failed.
# Reports a summary at the end and exits with appropriate code.
# ==============================================================================

# Temporary directory for failure markers
SUITE_MARKER_DIR := /tmp/arc-suite-markers-$$$$

check-all: ## Run ALL checks (Lint + Format + Test + Security) with full summary
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║        A.R.C. Framework - Complete Validation Suite              ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@rm -rf $(SUITE_MARKER_DIR) && mkdir -p $(SUITE_MARKER_DIR)
	@SUITE_FAILED=0; \
	\
	echo "$(YELLOW)━━━ Phase 1: Linting ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	echo ""; \
	\
	echo "$(BLUE)[1/8] Go Lint$(NC)"; \
	if $(MAKE) _lint-go 2>/dev/null; then \
		echo "$(GREEN)  ✓ Go lint passed$(NC)"; \
	else \
		echo "$(RED)  ✗ Go lint failed$(NC)"; \
		touch $(SUITE_MARKER_DIR)/lint-go-failed; \
		SUITE_FAILED=1; \
	fi; \
	echo ""; \
	\
	echo "$(BLUE)[2/8] Python Lint$(NC)"; \
	if $(MAKE) _lint-py 2>/dev/null; then \
		echo "$(GREEN)  ✓ Python lint passed$(NC)"; \
	else \
		echo "$(RED)  ✗ Python lint failed$(NC)"; \
		touch $(SUITE_MARKER_DIR)/lint-py-failed; \
		SUITE_FAILED=1; \
	fi; \
	echo ""; \
	\
	echo "$(BLUE)[3/8] Shell Lint$(NC)"; \
	if $(MAKE) _lint-sh 2>/dev/null; then \
		echo "$(GREEN)  ✓ Shell lint passed$(NC)"; \
	else \
		echo "$(RED)  ✗ Shell lint failed$(NC)"; \
		touch $(SUITE_MARKER_DIR)/lint-sh-failed; \
		SUITE_FAILED=1; \
	fi; \
	echo ""; \
	\
	echo "$(BLUE)[4/8] Docker Lint$(NC)"; \
	if $(MAKE) _lint-docker 2>/dev/null; then \
		echo "$(GREEN)  ✓ Docker lint passed$(NC)"; \
	else \
		echo "$(RED)  ✗ Docker lint failed$(NC)"; \
		touch $(SUITE_MARKER_DIR)/lint-docker-failed; \
		SUITE_FAILED=1; \
	fi; \
	echo ""; \
	\
	echo "$(YELLOW)━━━ Phase 2: Type Checking ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	echo ""; \
	\
	echo "$(BLUE)[5/8] Python Type Check$(NC)"; \
	if $(MAKE) _typecheck-py 2>/dev/null; then \
		echo "$(GREEN)  ✓ Python type check passed$(NC)"; \
	else \
		echo "$(RED)  ✗ Python type check failed$(NC)"; \
		touch $(SUITE_MARKER_DIR)/typecheck-py-failed; \
		SUITE_FAILED=1; \
	fi; \
	echo ""; \
	\
	echo "$(YELLOW)━━━ Phase 3: Testing ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	echo ""; \
	\
	echo "$(BLUE)[6/8] Go Tests$(NC)"; \
	if $(MAKE) _test-go 2>/dev/null; then \
		echo "$(GREEN)  ✓ Go tests passed$(NC)"; \
	else \
		echo "$(RED)  ✗ Go tests failed$(NC)"; \
		touch $(SUITE_MARKER_DIR)/test-go-failed; \
		SUITE_FAILED=1; \
	fi; \
	echo ""; \
	\
	echo "$(BLUE)[7/8] Python Tests$(NC)"; \
	if $(MAKE) _test-py 2>/dev/null; then \
		echo "$(GREEN)  ✓ Python tests passed$(NC)"; \
	else \
		echo "$(RED)  ✗ Python tests failed$(NC)"; \
		touch $(SUITE_MARKER_DIR)/test-py-failed; \
		SUITE_FAILED=1; \
	fi; \
	echo ""; \
	\
	echo "$(YELLOW)━━━ Phase 4: Security ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	echo ""; \
	\
	echo "$(BLUE)[8/8] Security Scan$(NC)"; \
	if $(MAKE) _security-scan 2>/dev/null; then \
		echo "$(GREEN)  ✓ Security scan passed$(NC)"; \
	else \
		echo "$(RED)  ✗ Security scan failed$(NC)"; \
		touch $(SUITE_MARKER_DIR)/security-failed; \
		SUITE_FAILED=1; \
	fi; \
	echo ""; \
	\
	echo "$(CYAN)╔═══════════════════════════════════════════════════════════════════╗$(NC)"; \
	echo "$(CYAN)║                        SUITE SUMMARY                              ║$(NC)"; \
	echo "$(CYAN)╚═══════════════════════════════════════════════════════════════════╝$(NC)"; \
	echo ""; \
	FAILED_CHECKS=$$(ls $(SUITE_MARKER_DIR)/ 2>/dev/null | wc -l | tr -d ' '); \
	TOTAL_CHECKS=8; \
	PASSED_CHECKS=$$((TOTAL_CHECKS - FAILED_CHECKS)); \
	\
	if [ "$$FAILED_CHECKS" -eq 0 ]; then \
		echo "$(GREEN)  ✓ All $$TOTAL_CHECKS checks passed!$(NC)"; \
		echo ""; \
		rm -rf $(SUITE_MARKER_DIR); \
		exit 0; \
	else \
		echo "$(RED)  ✗ $$FAILED_CHECKS of $$TOTAL_CHECKS checks failed:$(NC)"; \
		echo ""; \
		for marker in $(SUITE_MARKER_DIR)/*-failed; do \
			if [ -f "$$marker" ]; then \
				CHECK_NAME=$$(basename "$$marker" | sed 's/-failed//'); \
				echo "$(RED)    • $$CHECK_NAME$(NC)"; \
			fi; \
		done; \
		echo ""; \
		echo "$(YELLOW)  Passed: $$PASSED_CHECKS | Failed: $$FAILED_CHECKS$(NC)"; \
		echo ""; \
		rm -rf $(SUITE_MARKER_DIR); \
		exit 1; \
	fi

# Convenience aliases
lint-all: _lint-go _lint-py _lint-sh _lint-docker ## Run all linters
test-all: _test-go _test-py ## Run all tests
fmt-all: _fmt-go _fmt-py ## Format all code
