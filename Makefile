.PHONY: help up down ps logs health clean restart build push pull \
        up-observability up-stack down-observability down-stack \
        logs-observability logs-stack health-all \
        health-postgres health-redis health-nats health-pulsar \
        health-kratos health-unleash health-infisical health-traefik \
        health-loki health-prometheus health-jaeger health-grafana \
        health-otel init-postgres migrate-kratos migrate-unleash \
        shell-postgres shell-redis shell-nats \
        test-connectivity validate-compose info status version

# Configuration
COMPOSE_BASE := docker-compose -f docker-compose.yml
COMPOSE_STACK := docker-compose -f docker-compose.yml -f docker-compose.stack.yml
PROJECT_NAME ?= arc-platform-spike
ENV_FILE ?= .env

# Color output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# ============================================================================
# Help
# ============================================================================
help:
	@echo "$(BLUE)A.R.C. Platform Spike - Service Orchestration$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make [target]"
	@echo ""
	@echo "$(YELLOW)Lifecycle:$(NC)"
	@echo "  make up              Start all services (observability + stack)"
	@echo "  make up-observability Start only observability services"
	@echo "  make up-stack        Start only platform stack services"
	@echo "  make down            Stop all services"
	@echo "  make restart         Restart all services"
	@echo "  make clean           Remove all containers, volumes, networks"
	@echo ""
	@echo "$(YELLOW)Diagnostics:$(NC)"
	@echo "  make ps              List running containers"
	@echo "  make logs            Stream logs from all services"
	@echo "  make logs-service SERVICE=postgres  Stream logs from specific service"
	@echo "  make health-all      Check health of all services"
	@echo "  make status          Show status and health"
	@echo ""
	@echo "$(YELLOW)Database:$(NC)"
	@echo "  make init-postgres   Initialize Postgres with pgvector"
	@echo "  make migrate-kratos  Run Kratos DB migrations"
	@echo "  make shell-postgres  Open psql shell"
	@echo "  make shell-redis     Open redis-cli shell"
	@echo ""
	@echo "$(YELLOW)Information:$(NC)"
	@echo "  make info            Display all service URLs and credentials"
	@echo "  make version         Display component versions"
	@echo ""

# ============================================================================
# Environment Setup
# ============================================================================
.env:
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Creating .env from .env.example$(NC)"; \
		cp .env.example .env; \
		echo "$(GREEN)✓ .env created. Please review and adjust credentials.$(NC)"; \
	else \
		echo "$(YELLOW).env file already exists. Skipping...$(NC)"; \
	fi

env-check:
	@if [ ! -f .env ]; then \
		echo "$(RED)✗ .env file not found. Run 'make .env' first.$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ .env file exists.$(NC)"

# ============================================================================
# Lifecycle Management
# ============================================================================
up: env-check
	@echo "$(BLUE)Starting A.R.C. Platform Spike...$(NC)"
	$(COMPOSE_STACK) up -d --build
	@sleep 5
	@make health-all

down:
	@echo "$(BLUE)Stopping all services...$(NC)"
	$(COMPOSE_STACK) down -v
	@echo "$(GREEN)✓ All services stopped.$(NC)"

restart: down up

clean: down
	@echo "$(BLUE)Cleaning up...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ Cleanup complete.$(NC)"

up-observability: env-check
	@echo "$(BLUE)Starting observability stack...$(NC)"
	$(COMPOSE_BASE) up -d --build
	@sleep 5
	@make health-observability

down-observability:
	@echo "$(BLUE)Stopping observability services...$(NC)"
	$(COMPOSE_BASE) down -v
	@echo "$(GREEN)✓ Observability services stopped.$(NC)"

up-stack: env-check
	@echo "$(BLUE)Starting platform stack...$(NC)"
	$(COMPOSE_STACK) up -d postgres redis nats pulsar kratos unleash infisical traefik
	@sleep 10
	@make health-stack

down-stack:
	@echo "$(BLUE)Stopping platform stack...$(NC)"
	$(COMPOSE_STACK) down postgres redis nats pulsar kratos unleash infisical traefik
	@echo "$(GREEN)✓ Platform stack stopped.$(NC)"

build: env-check
	@echo "$(BLUE)Building images...$(NC)"
	$(COMPOSE_STACK) build
	@echo "$(GREEN)✓ Images built.$(NC)"

# ============================================================================
# Container Management
# ============================================================================
ps: env-check
	@echo "$(BLUE)Running containers:$(NC)"
	$(COMPOSE_STACK) ps

logs: env-check
	$(COMPOSE_STACK) logs -f

logs-observability:
	$(COMPOSE_BASE) logs -f loki prometheus jaeger grafana otel-collector

logs-stack:
	$(COMPOSE_STACK) logs -f postgres redis nats pulsar kratos unleash infisical traefik

logs-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)✗ SERVICE not specified. Usage: make logs-service SERVICE=postgres$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Streaming logs from $(SERVICE)...$(NC)"
	$(COMPOSE_STACK) logs -f $(SERVICE)

# ============================================================================
# Health Checks
# ============================================================================
health-all:
	@echo "$(BLUE)Checking health of all services...$(NC)"
	@echo "  Postgres:"
	@docker exec arc_postgres pg_isready -U arc 2>/dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Redis:"
	@docker exec arc_redis redis-cli ping 2>/dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  NATS:"
	@curl -s http://localhost:8222 > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Pulsar:"
	@curl -s http://localhost:8080/metrics > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Kratos:"
	@curl -s http://localhost:4434/health/alive > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Unleash:"
	@curl -s http://localhost:4242/api/admin/health > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Loki:"
	@curl -s http://localhost:3100/ready > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Prometheus:"
	@curl -s http://localhost:9090/-/healthy > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Jaeger:"
	@curl -s http://localhost:16686 > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Grafana:"
	@curl -s http://localhost:3000 > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"

health-observability:
	@echo "$(BLUE)Checking observability services...$(NC)"
	@echo "  Loki:"
	@curl -s http://localhost:3100/ready > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Prometheus:"
	@curl -s http://localhost:9090/-/healthy > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Jaeger:"
	@curl -s http://localhost:16686 > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Grafana:"
	@curl -s http://localhost:3000 > /dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"

health-stack:
	@echo "$(BLUE)Checking platform stack...$(NC)"
	@echo "  Postgres:"
	@docker exec arc_postgres pg_isready -U arc 2>/dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"
	@echo "  Redis:"
	@docker exec arc_redis redis-cli ping 2>/dev/null && echo "$(GREEN) ✓$(NC)" || echo "$(RED) ✗$(NC)"

health-postgres:
	@docker exec arc_postgres pg_isready -U arc -d arc_db

health-redis:
	@docker exec arc_redis redis-cli ping

health-nats:
	@curl -s http://localhost:8222

health-pulsar:
	@curl -s http://localhost:8080/metrics | head -20

health-kratos:
	@curl -s http://localhost:4434/health/alive

health-unleash:
	@curl -s http://localhost:4242/api/admin/health

health-infisical:
	@curl -s http://localhost:3001/health

health-traefik:
	@curl -s http://localhost:8080/dashboard/ | head -20

health-loki:
	@curl -s http://localhost:3100/ready

health-prometheus:
	@curl -s http://localhost:9090/-/healthy

health-jaeger:
	@curl -s http://localhost:16686

health-grafana:
	@curl -s http://localhost:3000

health-otel:
	@curl -s http://localhost:13133

# ============================================================================
# Database Operations
# ============================================================================
init-postgres:
	@echo "$(BLUE)Initializing Postgres...$(NC)"
	@docker exec arc_postgres psql -U arc -d arc_db -c "CREATE EXTENSION IF NOT EXISTS vector;"
	@echo "$(GREEN)✓ Postgres initialized with pgvector.$(NC)"

migrate-kratos:
	@echo "$(BLUE)Running Kratos migrations...$(NC)"
	docker run --rm -v $(PWD)/config/kratos:/etc/kratos --network arc_net \
		oryd/kratos:v1.17.0 migrate sql -c /etc/kratos/kratos.yml --yes

migrate-unleash:
	@echo "$(BLUE)Unleash migrations run automatically on startup.$(NC)"

# ============================================================================
# Shell Access
# ============================================================================
shell-postgres:
	@docker exec -it arc_postgres psql -U arc -d arc_db

shell-redis:
	@docker exec -it arc_redis redis-cli

shell-nats:
	@docker exec -it arc_nats sh

# ============================================================================
# Validation & Testing
# ============================================================================
validate-compose:
	@echo "$(BLUE)Validating docker-compose files...$(NC)"
	@$(COMPOSE_BASE) config > /dev/null && echo "$(GREEN)✓ Base compose valid.$(NC)" || echo "$(RED)✗ Base compose invalid.$(NC)"
	@$(COMPOSE_STACK) config > /dev/null && echo "$(GREEN)✓ Stack compose valid.$(NC)" || echo "$(RED)✗ Stack compose invalid.$(NC)"

test-connectivity:
	@echo "$(BLUE)Testing service connectivity...$(NC)"
	@docker exec arc_postgres pg_isready -h postgres > /dev/null 2>&1 && echo "$(GREEN)✓ Postgres$(NC)" || echo "$(RED)✗ Postgres$(NC)"
	@docker exec arc_redis redis-cli -h redis ping > /dev/null 2>&1 && echo "$(GREEN)✓ Redis$(NC)" || echo "$(RED)✗ Redis$(NC)"

# ============================================================================
# Information & Utilities
# ============================================================================
info:
	@echo "$(BLUE)A.R.C. Platform Spike - Service Information$(NC)"
	@echo ""
	@echo "$(YELLOW)Observability Services:$(NC)"
	@echo "  Grafana:        http://localhost:3000 (admin/admin)"
	@echo "  Prometheus:     http://localhost:9090"
	@echo "  Jaeger:         http://localhost:16686"
	@echo "  Loki:           http://localhost:3100"
	@echo ""
	@echo "$(YELLOW)Platform Stack Services:$(NC)"
	@echo "  Postgres:       localhost:5432 (arc/postgres)"
	@echo "  Redis:          localhost:6379"
	@echo "  NATS:           localhost:4222 (monitoring: 8222)"
	@echo "  Pulsar:         localhost:6650 (http: 8080)"
	@echo "  Kratos:         http://localhost:4433 (admin: 4434)"
	@echo "  Unleash:        http://localhost:4242"
	@echo "  Infisical:      http://localhost:3001"
	@echo "  Traefik:        http://localhost:80 (dashboard: 8080)"
	@echo ""

status: ps health-all

version:
	@echo "$(BLUE)Component Versions:$(NC)"
	@echo "  Docker Compose: $$(docker-compose --version)"
	@echo "  Docker:         $$(docker --version)"
	@echo "  Make:           $$(make --version | head -1)"

