# Arc Framework - Platform Spike (Observability + Infrastructure)

This project is a technical spike demonstrating a complete, production-ready platform for the **A.R.C. (Agentic Reasoning Core)** framework. It showcases:

1. **End-to-end observability** (OpenTelemetry, Prometheus, Loki, Jaeger, Grafana)
2. **Production infrastructure** (Postgres + pgvector, Redis, NATS, Pulsar, Traefik, Kratos, Unleash, Infisical)
3. **Enterprise-grade service orchestration** (Makefile, multi-compose overlays, per-service `.env` configs)

The project serves as a blueprint for building, deploying, and scaling stateful AI agents with a battery-included platform.

---

## Quick Start

### Prerequisites
---

## Architecture Overview

The A.R.C. platform is composed of three logical layers:

### Layer 1: Base Application
- **`swiss-army-go`** - Sample Go app emitting telemetry (logs, metrics, traces) via OpenTelemetry SDK.

### Layer 2: Observability (Base Compose)
Deployed with `docker-compose.yml` by default:

| Service | Purpose | Port | Dashboard |
|---------|---------|------|-----------|
| **otel-collector** | Telemetry collector (gRPC/HTTP receivers) | 4317/4318, 13133 | Health: http://localhost:13133 |
| **loki** | Log storage and indexing | 3100 | API: http://localhost:3100 |
| **prometheus** | Metrics scraper and time-series DB | 9090 | Query: http://localhost:9090 |
| **jaeger** | Distributed trace storage and visualization | 16686 | UI: http://localhost:16686 |
| **grafana** | Unified visualization & dashboards | 3000 | UI: http://localhost:3000 |

### Layer 3: Platform Infrastructure (Stack Overlay)
Deployed with `docker-compose.stack.yml` overlay (optional):

| Service | Purpose | Port(s) | Config `.env` |
|---------|---------|--------|-----------|
| **postgres** | Primary data store + pgvector (for RAG/embeddings) | 5432 | `config/postgres/.env.example` |
| **redis** | Cache, sessions, rate limiting | 6379 | `config/redis/.env.example` |
| **nats** | Ephemeral messaging / job queues | 4222, 8222 | `config/nats/.env.example` |
| **pulsar** | Durable event streaming (Conveyor Belt) | 6650, 8080 | `config/pulsar/.env.example` |
| **kratos** | Identity & authentication (Ory) | 4433, 4434 | `config/kratos/.env.example` |
| **unleash** | Feature flags and experiments | 4242 | `config/unleash/.env.example` |
| **infisical** | Secrets management (self-hosted vault) | 3001 | `config/infisical/.env.example` |
| **traefik** | API gateway + auto-discovery reverse proxy | 80, 443, 8080 | `config/traefik/.env.example` |
- Make (for service orchestration)
---

## Service Management with Make

All services are orchestrated via a comprehensive **Makefile**. Key commands:

# Initialize environment files for all services
make .env

# Start all services (observability + platform stack)
make up

# Check health status
make health-all

# View service URLs and credentials
make info
```

### Next Steps
- **View observability**: Open http://localhost:3000 (Grafana, admin/admin)
- **Explore traces**: Open http://localhost:16686 (Jaeger)
- **Trigger app work**: `curl http://localhost:8081/ondemand-work`
- **Stop all services**: `make down`

For detailed per-service setup, see [Service Reference](#service-reference) below.

## Components

The `docker-compose.yml` file orchestrates the following services:

-   **`swiss-army-go`**: The sample Go application that generates telemetry data (logs, metrics, traces).
-   **`otel-collector`**: The OpenTelemetry Collector receives telemetry from the Go app, processes it (e.g., adds trace context to logs), and exports it to the appropriate backends.
-   **`loki`**: The log aggregation backend, which stores logs received from the collector.
-   **`prometheus`**: The time-series database that scrapes and stores metrics from the collector.
-   **`jaeger`**: The distributed tracing backend that stores and visualizes traces.
-   **`grafana`**: The primary visualization dashboard for viewing logs from Loki and metrics from Prometheus.

### Common Makefile Targets

```bash
# Lifecycle
make up                    # Start all services
make up-observability      # Start observability only
make up-stack              # Start platform stack only
make down                  # Stop all services
make restart               # Restart all services
make clean                 # Remove all containers, volumes, networks

# Diagnostics
make ps                    # List running containers
make logs                  # Stream logs from all services
make logs-service SERVICE=postgres  # Stream logs from one service
make health-all            # Check health of all services

# Database Operations
make init-postgres         # Initialize Postgres with pgvector
make migrate-kratos        # Run Kratos migrations
make shell-postgres        # Open psql shell
make shell-redis           # Open redis-cli shell

# Information
make info                  # Display all service URLs and credentials
make status                # Show running containers and health
make help                  # Display all available targets
```

For the full list of targets, run `make help`.

---

## Service Reference: Detailed Setup & Troubleshooting

### 1. Postgres (Data Storage)

**Purpose**: Primary relational database with pgvector extension for AI embeddings and semantic search.

**Quick Start**:
```bash
make health-postgres
make shell-postgres
```

**Configuration**:
- Config: `config/postgres/.env.example`
- Init SQL: `config/postgres/init.sql` (auto-runs on first start to enable pgvector)
- Port: 5432
- Default credentials: `arc` / `postgres` (from `.env`)

**Common Operations**:
```bash
# Check Postgres is ready
make health-postgres

# Connect to Postgres CLI
make shell-postgres

# Create a new database for an application
docker exec arc_postgres createdb -U arc my_app_db

# Backup database
docker exec arc_postgres pg_dump -U arc arc_db > backup.sql

# Restore database
docker exec arc_postgres psql -U arc arc_db < backup.sql
```

**Troubleshooting**:
- Connection refused → Wait 10s after start; Postgres needs time to initialize.
- pgvector not available → Run `make init-postgres` after first start.
- Out of space → Check Docker volume: `docker volume ls | grep postgres`

---

### 2. Redis (Cache & Sessions)

**Purpose**: In-memory data store for caching, sessions, and rate limiting.

**Quick Start**:
```bash
make health-redis
make shell-redis
```

**Configuration**:
- Config: `config/redis/.env.example`
- Port: 6379
- Volume: `redis-data:/data` (persistent)

**Common Operations**:
```bash
# Check Redis is ready
make health-redis

# Open Redis CLI
make shell-redis

# Inside Redis CLI:
PING                       # Check connectivity
INFO stats                 # View stats
KEYS *                     # List all keys
FLUSHALL                   # Clear all data
```

**Troubleshooting**:
- Connection refused → Wait 5s and retry.
- Memory full → Check `REDIS_MAXMEMORY_POLICY` in `config/redis/.env.example` or run `FLUSHALL`.

---

### 3. NATS (Ephemeral Messaging)

**Purpose**: Lightweight message broker for fire-and-forget messaging and job queues.

**Quick Start**:
```bash
make health-nats
```

**Configuration**:
- Config: `config/nats/.env.example`
- Ports: 4222 (server), 8222 (monitoring)
- Monitoring: http://localhost:8222

**Common Operations**:
```bash
# Check NATS is ready
make health-nats

# View NATS monitoring dashboard
curl http://localhost:8222

# Test NATS connectivity
docker exec arc_nats nats sub test_subject
# In another terminal:
docker exec arc_nats nats pub test_subject "hello"
```

**Troubleshooting**:
- Connection refused → NATS needs 5-10s to start.
- Check monitoring at http://localhost:8222 for connection stats.

---

### 4. Apache Pulsar (Durable Streaming)

**Purpose**: Enterprise-grade event streaming for the "Conveyor Belt" (durable log of all system events).

**Quick Start**:
```bash
make health-pulsar
```

**Configuration**:
- Config: `config/pulsar/.env.example`
- Ports: 6650 (broker), 8080 (HTTP/metrics)
- Mode: Standalone (local dev)
- Memory: 128MB–512MB (adjustable in compose for production)

**Common Operations**:
```bash
# Check Pulsar is ready
make health-pulsar

# View Pulsar metrics
curl http://localhost:8080/metrics | grep -i pulsar

# Create a topic
docker exec arc_pulsar ./bin/pulsar-admin topics create persistent://public/default/my-topic

# Publish to a topic
docker exec arc_pulsar ./bin/pulsar-client produce persistent://public/default/my-topic -m "hello"

# Consume from a topic
docker exec arc_pulsar ./bin/pulsar-client consume persistent://public/default/my-topic -s my-subscription -n 10
```

**Important Notes**:
- Pulsar is memory-intensive; consider removing it from `docker-compose.stack.yml` if you have <4GB RAM available.
- Standalone mode is for development only; production setups require Zookeeper + BookKeeper.

**Troubleshooting**:
- Slow startup → Pulsar can take 30-60s to initialize. Check logs: `make logs-service SERVICE=pulsar`
- Out of memory → Reduce `PULSAR_MEM` in `config/pulsar/.env.example`.

---

### 5. Ory Kratos (Identity & Authentication)

**Purpose**: Production-grade identity platform for user registration, login, and account recovery.

**Quick Start** (requires configuration):
```bash
make health-kratos
```

**Configuration**:
- Config guide: `config/kratos/README.md`
- Config template: `config/kratos/.env.example`
- Ports: 4433 (public), 4434 (admin)
- Database: Uses Postgres (auto-initialized on first start)

**Setup Steps** (one-time):
1. Copy `.env` from `config/kratos/.env.example` to `config/kratos/.env`
2. Create `config/kratos/kratos.yml` with identity configuration (see Ory docs)
3. Run migrations: `make migrate-kratos`
4. Start services: `make up` or `make up-stack`

**Common Operations**:
```bash
# Check Kratos admin API is ready
make health-kratos

# View Kratos admin API docs
curl http://localhost:4434/admin/

# List identities
curl http://localhost:4434/admin/identities

# Get health status
curl http://localhost:4434/health/alive
```

**Troubleshooting**:
- "config not found" → Create `config/kratos/kratos.yml` (see `config/kratos/README.md`).
- DB migration errors → Ensure Postgres is healthy: `make health-postgres`
- Port already in use → Check what's using 4433/4434: `lsof -i :4433`

---

### 6. Unleash (Feature Flags)

**Purpose**: Progressive feature rollout and A/B testing via feature flags.

**Quick Start**:
```bash
make health-unleash
```

**Configuration**:
- Config: `config/unleash/.env.example`
- Port: 4242
- Database: Uses Postgres
- Default URL: http://localhost:4242

**First Access**:
1. Open http://localhost:4242
2. Click "Sign Up" to create an admin account
3. Log in and enable/create feature flags

**Common Operations**:
```bash
# Check Unleash is ready
make health-unleash

# View admin API
curl http://localhost:4242/api/admin/

# List features
curl http://localhost:4242/api/admin/features

# Get feature flags for your app
curl http://localhost:4242/client/features
```

**Troubleshooting**:
- "Database error" → Ensure Postgres is healthy: `make health-postgres`
- UI not loading → Wait 10-20s for migrations to complete; check logs: `make logs-service SERVICE=unleash`

---

### 7. Infisical (Secrets Management)

**Purpose**: Self-hosted vault for managing API keys, credentials, and sensitive configuration.

**Quick Start**:
```bash
make health-infisical
```

**Configuration**:
- Config: `config/infisical/.env.example`
- Port: 3001
- Database: Uses Postgres
- Default URL: http://localhost:3001

**First Access**:
1. Open http://localhost:3001
2. Click "Sign Up" to create an account
3. Create a project and add secrets

**Troubleshooting**:
- "Database error" → Ensure Postgres is healthy: `make health-postgres`
- Master key issues → Check logs: `make logs-service SERVICE=infisical`

---

### 8. Traefik (API Gateway)

**Purpose**: Reverse proxy and auto-discovery gateway for routing traffic to microservices.

**Quick Start**:
```bash
make health-traefik
```

**Configuration**:
- Config: `config/traefik/traefik.yml`
- Env: `config/traefik/.env.example`
- Ports: 80 (HTTP), 443 (HTTPS), 8080 (dashboard)
- Dashboard: http://localhost:8080/dashboard/

**How It Works**:
- Traefik watches Docker container labels and auto-discovers services.
- Services expose themselves via Docker labels (e.g., `traefik.enable=true`).
- Example: See `docker-compose.yml` for how services can add labels.

**Common Operations**:
```bash
# Access Traefik dashboard
open http://localhost:8080/dashboard/

# View active routes
curl http://localhost:8080/api/http/routers

# View services
curl http://localhost:8080/api/http/services
```

**Troubleshooting**:
- Dashboard not loading → Check logs: `make logs-service SERVICE=traefik`
- Routes not auto-discovered → Ensure Docker labels are correct on services.

---

### 9-13. Observability Stack (Grafana, Prometheus, Jaeger, Loki, OTel Collector)

These services are core to the observability layer and should be started first via `make up-observability`.

**Grafana (Visualization)**:
- URL: http://localhost:3000
- Login: admin / admin (change on first login in production)
- Auto-provisioned data sources: Prometheus, Loki, Jaeger

**Prometheus (Metrics)**:
- URL: http://localhost:9090
- Scrapes metrics from OTel Collector and infra services
- Retention: 15d (configurable)

**Jaeger (Distributed Tracing)**:
- URL: http://localhost:16686
- Stores traces from OTel Collector
- In-memory storage (production should use Elasticsearch or Badger)

**Loki (Log Aggregation)**:
- URL: http://localhost:3100
- Stores logs from OTel Collector
- Lightweight and cost-efficient for high-volume logging

**OTel Collector (Telemetry Pipeline)**:
- Ports: 4317 (gRPC), 4318 (HTTP), 13133 (health)
- Receives signals from apps and exports to Jaeger, Prometheus, Loki
- Config: `config/otel-collector-config.yml`

**Health Checks**:
```bash
make health-observability
make health-grafana
make health-prometheus
make health-jaeger
make health-loki
make health-otel
```

---

## Running Specific Service Combinations

### Observability Only (for testing telemetry pipeline)
```bash
make up-observability
# Services: loki, prometheus, jaeger, grafana, otel-collector, swiss-army-go
```

### Observability + Data Layer (for agent development)
```bash
make up  # Starts all services

# Or selectively:
make up-observability
make up postgres redis  # Add data layer only
```

### Full Platform (for end-to-end testing)
```bash
make up  # Starts everything
make health-all
```

---

## Environment Variables & Secrets Management

### Multi-Service `.env` Strategy

Each service has its own `.env.example` file in `config/{service}/.env.example`:

```
config/
  postgres/.env.example       # Database config
  redis/.env.example          # Cache config
  kratos/.env.example         # Identity config
  unleash/.env.example        # Feature flags config
  ... (one per service)
```

**Security Best Practices**:

1. **Never commit `.env` files**:
   ```bash
   echo ".env" >> .gitignore
   echo "config/**/.env" >> .gitignore
   ```

2. **Use `.env.example` for templates** (safe to commit):
   ```bash
   # Repository contains only .env.example (no secrets)
   # Users must copy and customize locally:
   cp config/postgres/.env.example config/postgres/.env
   # Edit config/postgres/.env with real values
   ```

3. **For production**, use Docker secrets or environment variable injection:
   ```bash
   # Example with Docker secrets
   docker secret create db_password <(echo "my-secure-password")
   ```

4. **Rotate secrets regularly** and use strong, unique passwords for each service.

---

## Troubleshooting & Common Issues

### All Services Fail to Start
```bash
# Check Docker and compose versions
docker --version
docker compose --version

# Validate compose files
make validate-compose

# Check logs for all services
make logs

# Ensure .env exists
make .env
```

### Port Already in Use
```bash
# Find what's using a port (example: 5432 for Postgres)
lsof -i :5432

# Kill the process or remap the port in docker-compose.stack.yml
```

### Out of Memory
```bash
# Check Docker resources
docker stats

# Reduce Pulsar memory (high by default)
# Edit config/pulsar/.env.example:
# PULSAR_MEM=-Xms64m -Xmx256m

# Restart
make restart
```

### Services Won't Connect
```bash
# Test connectivity between services
make test-connectivity

# Check network
docker network ls
docker network inspect arc_net

# Restart networking
make down && make up
```

### Persistent Data Loss on Restart
```bash
# Ensure volumes are persistent
docker volume ls | grep arc_

# Don't use 'make clean' unless you want to wipe data
make down        # Keeps volumes
make clean       # Removes volumes
```

---

## Performance & Resource Requirements

### Minimum (Observability Only)
- CPU: 2 cores
- Memory: 2GB
- Disk: 10GB

### Recommended (Observability + Platform Stack)
- CPU: 4 cores
- Memory: 8GB
- Disk: 20GB

### Production (with HA, clustering, external storage)
- CPU: 16+ cores
- Memory: 32+GB
- Disk: 100+GB
- External storage: Elasticsearch, S3, managed Postgres

---

## Next Steps

1. **Deploy a test service**: Add a new microservice and wire it to observability.
2. **Create Grafana dashboards**: Custom dashboards for your application metrics.
3. **Implement LangGraph agents**: Add Python agent services using LangGraph framework.
4. **Configure Kratos identity flows**: Set up login, registration, password recovery.
5. **Wire up Pulsar topics**: Create topics for your domain events.

---

## Contributing

This spike is part of the A.R.C. framework. For contributions, see `CONTRIBUTING.md` in the parent repository.

## License

Apache 2.0 (see `LICENSE` file)
