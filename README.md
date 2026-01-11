# A.R.C. Framework - Platform Spike

**Agentic Reasoning Core** - A production-ready platform demonstrating enterprise-grade infrastructure for AI agent systems.

[![Status](https://img.shields.io/badge/status-active-success.svg)]()
[![Security](https://img.shields.io/badge/security-hardened-blue.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

<!-- CI/CD Status Badges -->
[![PR Checks](https://github.com/arc-framework/platform-spike/actions/workflows/pr-checks.yml/badge.svg)](https://github.com/arc-framework/platform-spike/actions/workflows/pr-checks.yml)
[![Main Deploy](https://github.com/arc-framework/platform-spike/actions/workflows/main-deploy.yml/badge.svg)](https://github.com/arc-framework/platform-spike/actions/workflows/main-deploy.yml)
[![Security Scan](https://github.com/arc-framework/platform-spike/actions/workflows/security-scan.yml/badge.svg)](https://github.com/arc-framework/platform-spike/actions/workflows/security-scan.yml)
[![Scheduled Maintenance](https://github.com/arc-framework/platform-spike/actions/workflows/scheduled-maintenance.yml/badge.svg)](https://github.com/arc-framework/platform-spike/actions/workflows/scheduled-maintenance.yml)

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

| Service     | Purpose            | Port | Status    |
| ----------- | ------------------ | ---- | --------- |
| **Raymond** | Platform utilities | 8081 | 📋 Active |

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

**Includes**: Security + Raymond utility service

---

## 📖 Documentation

### Getting Started

- [Quickstart Guide](specs/002-stabilize-framework/quickstart.md) - 5-minute onboarding
- [Operations Guide](docs/OPERATIONS.md) - Deployment and management
- [Validation Failures](docs/guides/VALIDATION-FAILURES.md) - Troubleshooting

### Architecture

- [Directory Design](docs/architecture/DIRECTORY-DESIGN.md) - Three-tier structure
- [Service Categorization](docs/architecture/SERVICE-CATEGORIZATION.md) - Where services belong
- [Service Roadmap](docs/architecture/SERVICE-ROADMAP.md) - Development plan
- [Docker Image Hierarchy](docs/architecture/DOCKER-IMAGE-HIERARCHY.md) - Image relationships

### Standards & Guides

- [Docker Standards](docs/standards/DOCKER-STANDARDS.md) - Container best practices
- [Docker Build Optimization](docs/guides/DOCKER-BUILD-OPTIMIZATION.md) - Performance tuning
- [Security Scanning](docs/guides/SECURITY-SCANNING.md) - Security processes
- [Migration Guide](docs/guides/MIGRATION-GUIDE.md) - Service migration

### Architecture Decision Records

- [ADR Index](docs/architecture/adr/README.md) - All decisions
- [ADR-001](docs/architecture/adr/001-codename-convention.md) - Codename convention
- [ADR-002](docs/architecture/adr/002-three-tier-structure.md) - Directory structure

### Reports

- [Progress Tracker](PROGRESS.md) - Development status
- [Changelog](CHANGELOG.md) - Version history
- [Security Baseline](reports/security-baseline.json) - Security status

---

## 🔄 CI/CD Pipeline

The A.R.C. platform includes an enterprise-grade CI/CD system built on GitHub Actions.

### Workflow Overview

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **PR Checks** | Pull Request | Fast validation, build, security scan (<3 min) |
| **Main Deploy** | Push to main | Build and publish images to GHCR |
| **Release** | Git tag `v*` | Staged deployment with approval gates |
| **Security Scan** | Daily schedule | CVE scanning, SBOM generation |
| **Cost Monitoring** | Daily schedule | Track GitHub Actions usage |

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATION LAYER                       │
│  pr-checks │ main-deploy │ release │ scheduled-maintenance   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     REUSABLE LAYER                           │
│  _reusable-validate │ _reusable-build │ _reusable-security   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    COMPOSITE ACTIONS                         │
│     arc-setup │ arc-docker-build │ arc-security-scan         │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

- **Multi-Architecture**: All images built for linux/amd64 and linux/arm64
- **Security-First**: SBOM generation, CVE scanning, license compliance
- **Cost-Aware**: Aggressive caching, usage monitoring, budget alerts
- **Configuration-Driven**: JSON configs for services, caching, publishing

### Quick Commands

```bash
# Trigger PR checks manually
gh workflow run pr-checks.yml --ref your-branch

# View recent workflow runs
gh run list --limit 10

# Download build artifacts
gh run download <run-id>
```

### Documentation

- [CI/CD Developer Guide](docs/guides/CICD-DEVELOPER-GUIDE.md) - How to work with workflows
- [CI/CD Architecture](docs/architecture/CICD-ARCHITECTURE.md) - System design and diagrams
- [Security Scanning Guide](docs/guides/SECURITY-SCANNING.md) - Security processes

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
2. Select service: `raymond`
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

**Current Version**: 2.1.0 (Spec 002 - Framework Stabilization)
**Status**: Active Development
**Last Updated**: January 11, 2026

### Recent Updates (Spec 002)

- ✅ Three-tier directory structure (core/plugins/services)
- ✅ Docker base images and templates
- ✅ Validation tooling (10+ scripts)
- ✅ CI/CD pipelines (GitHub Actions)
- ✅ Comprehensive documentation (25+ guides)
- ✅ Service roadmap (34 services mapped)

### Service Reality Check

| Category | Count | Status |
|----------|-------|--------|
| External (Docker config) | 18 | ✅ Ready |
| Built (raymond) | 1 | 🟢 Working |
| Stubs (sherlock, scarlett, piper) | 3 | 🟡 Skeleton |
| Planned (not built) | 12 | ⚪ Roadmapped |

### Next Phases

- [ ] Phase 1: Sherlock LLM Integration
- [ ] Phase 2: Voice Pipeline (Piper, Scarlett)
- [ ] Phase 3: Safety Layer (Guard, Ramsay)
- [ ] Phase 4: Specialized Workers

See [PROGRESS.md](PROGRESS.md) and [SERVICE-ROADMAP.md](docs/architecture/SERVICE-ROADMAP.md) for details.

---

**Built with ❤️ for the A.R.C. Framework**
