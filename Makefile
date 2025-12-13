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
        info-core

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
APP_SERVICES := toolbox

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

# Docker Compose optimization
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
		UNHEALTHY_COUNT=$$(echo "$$HEALTH_OUTPUT" | grep -c "✗ Unhealthy" || true); \
		if [ $$UNHEALTHY_COUNT -eq 0 ]; then \
			printf "\r$(GREEN)✓ $(1) are healthy! (took $$ELAPSED s)                                    $(NC)\n"; \
			$(if $(4),$(MAKE) info-$(4),$(MAKE) info); \
			exit 0; \
		fi; \
		PERCENT=$$((ELAPSED * 100 / MAX_WAIT)); \
		BAR_LEN=$$((PERCENT / 2)); \
		BAR=$$(printf '%*s' $$BAR_LEN | tr ' ' '█'); \
		EMPTY=$$(printf '%*s' $$((50 - BAR_LEN)) | tr ' ' '░'); \
		SPIN_IDX=$$((ELAPSED % 10)); \
		SPIN_CHAR=$$(echo "$$SPINNER" | cut -c$$((SPIN_IDX + 1))); \
		printf "\r  $$SPIN_CHAR [$$BAR$$EMPTY] $$PERCENT%% ($$ELAPSED/$$MAX_WAIT s) "; \
		UNHEALTHY_SERVICES=$$(echo "$$HEALTH_OUTPUT" | grep "✗ Unhealthy" | sed 's/.*: //' | head -3 | tr '\n' ', ' | sed 's/,$$//'); \
		if [ -n "$$UNHEALTHY_SERVICES" ]; then \
			printf "$(YELLOW)Waiting: $$UNHEALTHY_SERVICES$(NC)"; \
		fi; \
		sleep $$INTERVAL; \
		ELAPSED=$$((ELAPSED + INTERVAL)); \
	done; \
	printf "\r$(RED)✗ Timeout waiting for $(1) ($$MAX_WAIT s exceeded)                        $(NC)\n\n"; \
	echo "$(YELLOW)━━━ Failed Service Details ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
	$(MAKE) $(3); \
	echo ""; \
	echo "$(YELLOW)Troubleshooting:$(NC)"; \
	echo "  1. Check logs: $(CYAN)make logs$(NC)"; \
	echo "  2. Check status: $(CYAN)docker ps -a | grep arc_$(NC)"; \
	echo "  3. Check specific service: $(CYAN)docker logs arc_<service_name>$(NC)"; \
	echo "  4. Retry: $(CYAN)make down && make $(1)$(NC)"; \
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
	@printf "  %-25s" "Toolbox:"
	@curl -sf http://localhost:8081/health >/dev/null && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy/Not Running$(NC)"
	@echo ""

# ==============================================================================
# Database Operations
# ==============================================================================
migrate-db:
	@echo "$(BLUE)Running database migrations...$(NC)"
	@docker exec arc-oracle-sql psql -U arc -d arc_db -c "CREATE EXTENSION IF NOT EXISTS vector;"
	@echo "$(GREEN)✓ PostgreSQL extensions installed$(NC)"
	@echo "$(BLUE)Running Kratos migrations...$(NC)"
	@docker run --rm \
		-v $(PWD)/plugins/security/identity/kratos:/etc/config/kratos \
		--network arc_net \
		oryd/kratos:v1.0.0 \
		migrate sql -e --yes postgres://arc:postgres@arc-oracle:5432/arc_db?sslmode=disable
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
		services/utilities/toolbox; do \
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
	@echo "  $(WHITE)Toolbox:$(NC)                http://localhost:8081"
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
	$(COMPOSE_FULL) logs -f toolbox

# ==============================================================================
# Development Helpers
# ==============================================================================
dev: up-dev
	@echo "$(GREEN)✓ Development environment ready$(NC)"
	@echo "$(YELLOW)Core + Observability + Application services are running$(NC)"

prod: up-full
	@echo "$(GREEN)✓ Production environment ready$(NC)"
	@echo "$(YELLOW)All services are running$(NC)"
