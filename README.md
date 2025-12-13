# A.R.C. Framework - Platform Spike

**Agentic Reasoning Core** - A production-ready platform demonstrating enterprise-grade infrastructure for AI agent systems.

[![Status](https://img.shields.io/badge/status-active-success.svg)]()
[![Security](https://img.shields.io/badge/security-hardened-blue.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## 🚀 Quick Start

Get the entire platform running in 3 commands:

```bash
# 1. Generate secure secrets
make generate-secrets

# 2. Start all services (Core + Observability + Security + Apps)
make up

# 3. View service URLs and credentials
make info

# 4. See your superhero lineup! 🦸
make roster
```

**That's it!** The platform is now running with:

- ✅ PostgreSQL + pgvector
- ✅ Redis cache
- ✅ NATS & Pulsar messaging
- ✅ Prometheus, Loki, Jaeger, Grafana
- ✅ Traefik gateway
- ✅ Kratos identity
- ✅ Unleash feature flags
- ✅ Infisical secrets

**Access the dashboards:**

- 📊 **Grafana**: http://localhost:3000 (credentials in `make info`)
- 🔍 **Jaeger**: http://localhost:16686
- 📈 **Prometheus**: http://localhost:9090
- 🔐 **Unleash**: http://localhost:4242

---

## 📋 Prerequisites

- **Docker** 24.0+ & **Docker Compose** v2.20+
- **Make** (built-in on macOS/Linux)
- **4GB+ RAM** for full stack (2GB for minimal)
- **OpenSSL** (for secret generation)

**macOS:**

```bash
brew install --cask docker
```

**Linux:**

```bash
# Install Docker Engine
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
sudo apt-get install docker-compose-plugin
```

---

## 🎯 What This Platform Provides

### Layer 1: Core Services

Required infrastructure that every service depends on:

| Service           | Purpose                       | Port      | Status      |
| ----------------- | ----------------------------- | --------- | ----------- |
| **PostgreSQL**    | Primary data store + pgvector | 5432      | ✅ Required |
| **Redis**         | Cache & sessions              | 6379      | ✅ Required |
| **NATS**          | Ephemeral messaging           | 4222      | ✅ Required |
| **Pulsar**        | Durable event streaming       | 6650      | ✅ Required |
| **Traefik**       | API gateway                   | 80/443    | ✅ Required |
| **OpenTelemetry** | Telemetry collection          | 4317/4318 | ✅ Required |
| **Infisical**     | Secrets management            | 3001      | ✅ Required |
| **Unleash**       | Feature flags                 | 4242      | ✅ Required |

### Layer 2: Observability Stack

Optional but recommended for production:

| Service        | Purpose               | Port  | Status    |
| -------------- | --------------------- | ----- | --------- |
| **Loki**       | Log aggregation       | 3100  | 🔌 Plugin |
| **Prometheus** | Metrics collection    | 9090  | 🔌 Plugin |
| **Jaeger**     | Distributed tracing   | 16686 | 🔌 Plugin |
| **Grafana**    | Unified visualization | 3000  | 🔌 Plugin |

### Layer 3: Security Stack

Production-ready identity and authentication:

| Service    | Purpose                   | Port      | Status    |
| ---------- | ------------------------- | --------- | --------- |
| **Kratos** | Identity & authentication | 4433/4434 | 🔌 Plugin |

### Layer 4: Application Services

Your custom services built on the framework:

| Service     | Purpose              | Port | Status     |
| ----------- | -------------------- | ---- | ---------- |
| **Toolbox** | Demo utility service | 8081 | 📋 Example |

---

## 🛠️ Make Commands

### Essential Commands

```bash
# Start everything (recommended for development)
make up

# Stop all services (preserves data)
make down

# Check health of all services
make health-all

# View service URLs and credentials
make info

# Stream logs from all services
make logs
```

### Initialization Commands

```bash
# Initialize environment (interactive)
make init

# Generate secure random secrets
make generate-secrets

# Validate secrets configuration
make validate-secrets

# Create Docker volumes
make init-volumes

# Create Docker network
make init-network
```

### Deployment Profiles

```bash
# Minimal - Core services only (~2GB RAM)
make up-minimal

# Dev - Core + application services (~3GB RAM)
make up-dev

# Observability - Core + monitoring (~4GB RAM)
make up-observability

# Security - Core + monitoring + auth (~5GB RAM)
make up-security

# Full - Everything including app services (~6GB RAM)
make up-full
# Alias: make up
```

### Lifecycle Management

```bash
# Restart all services
make restart

# Rebuild custom images
make build

# Stop and remove containers (keeps volumes)
make clean

# Complete reset (removes everything)
make reset

# List running containers
make ps

# Show comprehensive status
make status
```

### Health Checks

```bash
# Check all services
make health-all

# Check core services only
make health-core

# Check observability stack
make health-observability

# Check security services
make health-security
```

### Log Management

```bash
# Stream all logs
make logs

# Core services logs
make logs-core

# Observability logs
make logs-observability

# Security services logs
make logs-security

# Application services logs
make logs-services
```

### Database Operations

```bash
# Run database migrations
make migrate-db

# Backup database
make backup-db

# Restore from backup
make restore-db

# Open PostgreSQL shell
make shell-postgres

# Open Redis CLI
make shell-redis
```

### Validation & Testing

```bash
# Run all validations
make validate

# Validate architecture alignment
make validate-architecture

# Validate docker-compose files
make validate-compose

# Test service connectivity
make test-connectivity

# Validate secrets before deployment
make validate-secrets
```

### Information

```bash
# Display all service URLs and credentials
make info

# Show component versions
make version

# Show help menu
make help
```

---

## 🔒 Security & Configuration

### Initial Setup

The platform requires secure configuration before first use:

```bash
# Option 1: Automated (Recommended)
make generate-secrets  # Generates cryptographically secure secrets

# Option 2: Manual
cp .env.example .env
# Edit .env and replace all CHANGE_ME values
make validate-secrets  # Validate configuration
```

### Security Features

- ✅ **No weak defaults** - All passwords must be explicitly set
- ✅ **Automated validation** - Pre-flight checks before deployment
- ✅ **Resource limits** - CPU/memory limits on all services
- ✅ **Log rotation** - Prevents disk exhaustion (10MB × 3 files)
- ✅ **Secured admin interfaces** - No public exposure in production
- ✅ **Environment-based secrets** - No hardcoded credentials

### Configuration Files

```bash
.env                    # Main configuration (auto-generated)
.env.example            # Template with documentation
deployments/docker/     # Docker Compose files
  ├── docker-compose.base.yml
  ├── docker-compose.core.yml
  ├── docker-compose.observability.yml
  ├── docker-compose.security.yml
  ├── docker-compose.services.yml
  └── docker-compose.production.yml  # Production overrides
```

---## 🏗️ Architecture

### Three-Layer Design

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  (Your Services: Agents, APIs, Workers)                     │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                      Plugin Layer                            │
│  Observability: Loki, Prometheus, Jaeger, Grafana          │
│  Security: Kratos (Identity & Auth)                         │
│  Search: (Future: Typesense, Meilisearch)                  │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                       Core Layer                             │
│  Gateway: Traefik                                            │
│  Telemetry: OpenTelemetry Collector                         │
│  Persistence: PostgreSQL + pgvector                          │
│  Caching: Redis                                              │
│  Messaging: NATS (ephemeral) + Pulsar (durable)            │
│  Secrets: Infisical                                          │
│  Features: Unleash                                           │
└─────────────────────────────────────────────────────────────┘
```

### Swappable Components

Every component follows a **swappable design** pattern:

- **Observability**: Loki → Elasticsearch | Prometheus → InfluxDB | Jaeger → Zipkin
- **Database**: PostgreSQL → MySQL, MongoDB
- **Cache**: Redis → Memcached, Valkey
- **Messaging**: NATS → RabbitMQ | Pulsar → Kafka
- **Gateway**: Traefik → Kong, Nginx
- **Identity**: Kratos → Keycloak, Auth0
- **Secrets**: Infisical → HashiCorp Vault

### Data Flow

```
Application Service
    │
    ├─→ OpenTelemetry SDK
    │       ├─→ Logs → OTEL Collector → Loki → Grafana
    │       ├─→ Metrics → OTEL Collector → Prometheus → Grafana
    │       └─→ Traces → OTEL Collector → Jaeger → Grafana
    │
    ├─→ PostgreSQL (persistent data)
    ├─→ Redis (cache, sessions)
    ├─→ NATS (ephemeral messages)
    ├─→ Pulsar (durable events)
    ├─→ Traefik (HTTP routing)
    ├─→ Kratos (authentication)
    └─→ Unleash (feature flags)
```

---

## 🚦 Deployment Profiles

Choose the right profile for your needs:

### Development (2GB RAM)

```bash
make up-minimal  # Core services only
```

**Includes**: PostgreSQL, Redis, NATS, Pulsar, OTEL, Traefik, Infisical, Unleash

### Staging (4GB RAM)

```bash
make up-observability  # Core + monitoring
```

**Includes**: Minimal + Loki, Prometheus, Jaeger, Grafana

### Production-like (5GB RAM)

```bash
make up-security  # Core + monitoring + security
```

**Includes**: Observability + Kratos

### Full Stack (6GB RAM)

```bash
make up  # Everything including demo apps
```

**Includes**: Security + Toolbox service

---

## 📖 Documentation

### Getting Started

- [Operations Guide](docs/OPERATIONS.md) - Deployment and management
- [Security Fixes](docs/guides/SECURITY-FIXES.md) - Security hardening details
- [Environment Migration](docs/guides/ENV-MIGRATION.md) - Configuration updates

### Architecture

- [Architecture Overview](docs/architecture/README.md) - Design patterns and principles
- [Naming Conventions](docs/guides/NAMING-CONVENTIONS.md) - Coding standards

### Guides

- [Setup Scripts](scripts/setup/README.md) - Secret management tools
- [Migration Guide](docs/guides/MIGRATION-v1-to-v2.md) - Upgrade instructions

### Reports

- [Analysis Reports](reports/) - System analysis and recommendations

---

## 🔧 Troubleshooting

### Common Issues

#### "POSTGRES_PASSWORD must be set"

**Solution:**

```bash
make generate-secrets
```

#### "Cannot connect to PostgreSQL"

**Solution:**

```bash
# Wait for services to start (10-30 seconds)
make health-all

# Check logs
make logs-core
```

#### "Port already in use"

**Solution:**

```bash
# Find what's using the port
lsof -i :5432  # or whatever port

# Stop conflicting service or change port in .env
```

#### Services won't start

**Solution:**

```bash
# Clean restart
make down
make clean
make up
```

#### Out of disk space

**Solution:**

```bash
# Clean up Docker
docker system prune -a --volumes

# Or keep data but remove old images
docker system prune -a
```

### Health Check Failures

```bash
# Check individual service health
make health-core
make health-observability

# View detailed logs for failing service
docker logs arc_postgres
docker logs arc_redis

# Restart specific service
docker restart arc_postgres
```

### Performance Issues

```bash
# Check resource usage
docker stats

# Review resource limits
cat deployments/docker/docker-compose.core.yml | grep -A 5 resources

# Adjust limits in .env or use smaller profile
make up-minimal  # Instead of make up
```

---

## 🧪 Testing

### Service Connectivity

```bash
# Test all services
make test-connectivity

# Manual tests
curl http://localhost:3000/api/health      # Grafana
curl http://localhost:9090/-/healthy       # Prometheus
curl http://localhost:16686                # Jaeger
curl http://localhost:4242/health          # Unleash
```

### Database Connectivity

```bash
# PostgreSQL
make shell-postgres
# Inside psql: \l (list databases), \dt (list tables)

# Redis
make shell-redis
# Inside redis-cli: PING, INFO, KEYS *
```

### NATS Messaging

```bash
# Subscribe to test subject
docker exec arc_nats nats sub test

# Publish message (in another terminal)
docker exec arc_nats nats pub test "Hello World"
```

---

## 📊 Monitoring

### Access Dashboards

```bash
# Get all URLs and credentials
make info
```

### Grafana Setup

1. Open http://localhost:3000
2. Login with credentials from `make info`
3. Pre-configured data sources:
   - Loki (logs)
   - Prometheus (metrics)
   - Jaeger (traces)

### Prometheus Queries

Access http://localhost:9090 and try:

```promql
# CPU usage by service
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by service
container_memory_usage_bytes / 1024 / 1024

# HTTP request rate
rate(http_requests_total[5m])
```

### Jaeger Tracing

1. Open http://localhost:16686
2. Select service: `toolbox`
3. Click "Find Traces"
4. Explore distributed trace waterfall

---

## 🔐 Production Deployment

### Pre-flight Checklist

- [ ] Run `make generate-secrets`
- [ ] Run `make validate-secrets`
- [ ] Review `.env` configuration
- [ ] Set up TLS certificates for Traefik
- [ ] Configure backup strategy
- [ ] Set up monitoring alerts
- [ ] Review resource limits
- [ ] Test disaster recovery

### Production Mode

```bash
# Use production compose override
docker compose \
  -f deployments/docker/docker-compose.base.yml \
  -f deployments/docker/docker-compose.core.yml \
  -f deployments/docker/docker-compose.observability.yml \
  -f deployments/docker/docker-compose.security.yml \
  -f deployments/docker/docker-compose.production.yml \
  up -d
```

### Security Hardening

The platform includes:

- ✅ No weak default credentials checked into git
- 🔒 TLS entrypoint configured for service exposure
- 🔐 Traefik dashboard disabled by default; enable via secure override only
- 🛡️ Hardened compose profiles (no insecure legacy services)
- 🧪 Health checks wired into `make health-*`

See [SECURITY-FIXES.md](docs/guides/SECURITY-FIXES.md) for details.

---

## 🤝 Contributing

### Development Workflow

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes and test
make up
make test-connectivity
make validate

# 3. Commit changes
git add .
git commit -m "feat: add new feature"

# 4. Push and create PR
git push origin feature/my-feature
```

### Coding Standards

- Follow [Naming Conventions](docs/guides/NAMING-CONVENTIONS.md)
- Document all changes in appropriate README files
- Add health checks to new services
- Include resource limits
- Update Makefile with new targets

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙋 Support

- **Documentation**: Check [docs/](docs/) directory
- **Issues**: Create an issue with detailed description
- **Questions**: Start a discussion

---

## 🎯 Project Status

**Current Version**: 2.0.0  
**Status**: Active Development  
**Security Audit**: 67% Complete (12/18 issues fixed)  
**Last Updated**: November 9, 2025

### Recent Updates

- ✅ All critical security issues resolved
- ✅ Automated secret management
- ✅ Resource limits on all services
- ✅ Log rotation configured
- ✅ Production deployment mode
- ✅ Centralized configuration

### Roadmap

- [ ] TLS/SSL configuration
- [ ] Automated backup strategy
- [ ] Prometheus alerting rules
- [ ] Network segmentation
- [ ] CI/CD pipeline

See [PROGRESS.md](PROGRESS.md) for detailed status.

---

**Built with ❤️ for the A.R.C. Framework**# View Kratos admin API docs
curl http://localhost:4434/admin/

# List identities

curl http://localhost:4434/admin/identities

# Get health status

curl http://localhost:4434/health/alive

````

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
````

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

- Config: `core/gateway/traefik/traefik.yml`
- Env: project-level `.env`
- Ports: 80 (HTTP), 443 (HTTPS)
- Dashboard: internal-only; expose via Traefik router when needed

**How It Works**:

- Traefik watches Docker container labels and auto-discovers services.
- Services expose themselves via Docker labels (e.g., `traefik.enable=true`).
- Example: See `docker-compose.yml` for how services can add labels.

**Common Operations**:

```bash
# Temporarily expose the dashboard via secure router override
cat <<'EOF' > docker-compose.override.yml
services:
  arc_traefik:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik-dashboard.rule=Host(`traefik.localhost`)"
      - "traefik.http.routers.traefik-dashboard.entrypoints=websecure"
      - "traefik.http.routers.traefik-dashboard.tls=true"
      - "traefik.http.routers.traefik-dashboard.service=api@internal"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_DASHBOARD_AUTH:?Set secure credentials}"
      - "traefik.http.routers.traefik-dashboard.middlewares=traefik-auth"
EOF
make up

# Check Traefik health (ping endpoint exposed internally)
docker compose -f deployments/docker/docker-compose.core.yml exec arc_traefik traefik healthcheck --ping
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
# Services: loki, prometheus, jaeger, grafana, otel-collector, toolbox-go
```

### Observability + Data Layer (for agent development)

```bash
make up  # Starts all services

# Or selectively:
make up-observability
make up-minimal  # Core services only
make up-core-services  # Core + platform utilities
```

### Full Platform (for end-to-end testing)

```bash
make up  # Starts everything
make health-all
```

---

## Environment Variables & Secrets Management

### Multi-Service `.env` Strategy

All configuration is centralized in the root `.env` file generated by
`make generate-secrets`. Service-level `.env.example` files remain only as
deprecation stubs that point developers to the new workflow. See
`docs/guides/ENV-MIGRATION.md` for the mapping and migration steps.

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
