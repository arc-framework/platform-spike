# Docker Compose Deployments

**Location:** `deployments/docker/`  
**Pattern:** Core + Plugins Architecture  
**Status:** ✅ Active  

---

## Overview

This directory contains Docker Compose configurations organized by the A.R.C. Framework's three-layer architecture pattern (Core, Plugins, Services).

---

## File Structure

```
deployments/docker/
├── docker-compose.base.yml           # Shared resources (networks, volumes)
├── docker-compose.core.yml           # Required core services
├── docker-compose.observability.yml  # Observability plugins
├── docker-compose.security.yml       # Security plugins
├── docker-compose.services.yml       # Application services
├── legacy/                           # Old compose files (deprecated)
│   ├── docker-compose.yml
│   └── docker-compose.stack.yml
└── README.md                         # This file
```

---

## Deployment Profiles

### Minimal Profile (~2GB RAM)
**Use Case:** Local development, core services only  
**Services:** Traefik, OTel Collector, Postgres, Redis, NATS, Pulsar, Infisical, Unleash

```bash
make up-minimal
```

**Compose Files Used:**
- `docker-compose.base.yml`
- `docker-compose.core.yml`

---

### Observability Profile (~4GB RAM)
**Use Case:** Staging, development with full observability  
**Services:** Core + Loki, Prometheus, Jaeger, Grafana

```bash
make up-observability
```

**Compose Files Used:**
- `docker-compose.base.yml`
- `docker-compose.core.yml`
- `docker-compose.observability.yml`

---

### Security Profile (~5GB RAM)
**Use Case:** Testing with authentication/authorization  
**Services:** Core + Observability + Kratos

```bash
make up-security
```

**Compose Files Used:**
- `docker-compose.base.yml`
- `docker-compose.core.yml`
- `docker-compose.observability.yml`
- `docker-compose.security.yml`

---

### Full Stack Profile (~6GB RAM)
**Use Case:** Production-like environment with all services  
**Services:** All core, observability, security, and application services

```bash
make up-full
# or simply
make up
```

**Compose Files Used:**
- `docker-compose.base.yml`
- `docker-compose.core.yml`
- `docker-compose.observability.yml`
- `docker-compose.security.yml`
- `docker-compose.services.yml`

---

## Architecture Mapping

### docker-compose.base.yml
**Purpose:** Shared resources  
**Contains:**
- Network definitions (`arc_net`)
- Volume definitions (postgres, redis, pulsar, prometheus, grafana, loki)
- No services

---

### docker-compose.core.yml
**Purpose:** Required infrastructure services  
**Maps to:** `core/` directory

| Service | Category | Location |
|---------|----------|----------|
| `arc_traefik` | Gateway | `core/gateway/traefik/` |
| `arc_otel_collector` | Telemetry | `core/telemetry/otel-collector/` |
| `arc_postgres` | Persistence | `core/persistence/postgres/` |
| `arc_redis` | Caching | `core/caching/redis/` |
| `arc_nats` | Messaging (Ephemeral) | `core/messaging/ephemeral/nats/` |
| `arc_pulsar` | Messaging (Durable) | `core/messaging/durable/pulsar/` |
| `arc_infisical` | Secrets | `core/secrets/infisical/` |
| `arc_unleash` | Feature Management | `core/feature-management/unleash/` |

---

### docker-compose.observability.yml
**Purpose:** Optional observability stack  
**Maps to:** `plugins/observability/`

| Service | Category | Location |
|---------|----------|----------|
| `arc_loki` | Logging | `plugins/observability/logging/loki/` |
| `arc_prometheus` | Metrics | `plugins/observability/metrics/prometheus/` |
| `arc_jaeger` | Tracing | `plugins/observability/tracing/jaeger/` |
| `arc_grafana` | Visualization | `plugins/observability/visualization/grafana/` |

---

### docker-compose.security.yml
**Purpose:** Optional security services  
**Maps to:** `plugins/security/`

| Service | Category | Location |
|---------|----------|----------|
| `arc_kratos` | Identity & Auth | `plugins/security/identity/kratos/` |

---

### docker-compose.services.yml
**Purpose:** Application-level services  
**Maps to:** `services/`

| Service | Category | Location |
|---------|----------|----------|
| `arc_toolbox` | Utility | `services/utilities/toolbox/` |

---

## Volume Mounts

All volume mounts reference the actual directory structure:

```yaml
# Core services
./core/telemetry/otel-collector-config.yml
./core/persistence/postgres/init.sql
./core/gateway/traefik/traefik.yml

# Plugin services
./plugins/observability/visualization/grafana/provisioning
./plugins/observability/metrics/prometheus/prometheus.yaml
./plugins/security/identity/kratos

# Application services
./services/utilities/toolbox
```

**Note:** All paths are relative to the repository root, not this directory.

---

## Container Naming Convention

All containers use the `arc_` prefix for namespace isolation:

```
arc_traefik
arc_otel_collector
arc_postgres
arc_redis
arc_nats
arc_pulsar
arc_infisical
arc_unleash
arc_loki
arc_prometheus
arc_jaeger
arc_grafana
arc_kratos
arc_toolbox
```

---

## Network Configuration

**Network Name:** `arc_net`  
**Driver:** bridge  
**Subnet:** 172.20.0.0/16

All services connect to this shared network for inter-service communication.

---

## Volume Configuration

### Core Service Volumes
- `arc_postgres_data` - PostgreSQL data directory
- `arc_redis_data` - Redis persistence
- `arc_pulsar_data` - Pulsar message storage

### Observability Volumes
- `arc_prometheus_data` - Prometheus time-series data
- `arc_grafana_data` - Grafana dashboards and settings
- `arc_loki_data` - Loki log storage

---

## Usage Examples

### Start specific profile
```bash
cd /path/to/arc/platform-spike
make up-minimal
```

### Check health
```bash
make health-all
make health-core
make health-observability
```

### View logs
```bash
make logs-core
make logs-observability
make logs-services
```

### Stop services
```bash
make down
```

---

## Direct Docker Compose Usage

If you need to use docker compose directly:

```bash
# From repository root
docker compose -f deployments/docker/docker-compose.base.yml \
  -f deployments/docker/docker-compose.core.yml \
  up -d

# Or for full stack
docker compose -f deployments/docker/docker-compose.base.yml \
  -f deployments/docker/docker-compose.core.yml \
  -f deployments/docker/docker-compose.observability.yml \
  -f deployments/docker/docker-compose.security.yml \
  -f deployments/docker/docker-compose.services.yml \
  up -d
```

**Recommended:** Use Makefile targets instead for better UX.

---

## Environment Variables

The compose files use environment variables from `.env` file in the repository root:

```bash
# Required variables
POSTGRES_USER=arc
POSTGRES_PASSWORD=postgres
POSTGRES_DB=arc_db

# Optional overrides
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
LOG_LEVEL=info
```

---

## Health Checks

All services include health checks:
- **Startup Period:** Time to allow service to start before health checks
- **Interval:** Time between health checks
- **Timeout:** Maximum time for health check to complete
- **Retries:** Number of consecutive failures before unhealthy

---

## Service Dependencies

Services use `depends_on` with health check conditions:

```yaml
depends_on:
  arc_postgres:
    condition: service_healthy
  arc_otel_collector:
    condition: service_healthy
```

This ensures proper startup ordering.

---

## Labels

All services include standardized labels:

```yaml
labels:
  - "arc.service.layer=core|plugin|application"
  - "arc.service.category=gateway|persistence|observability|etc"
  - "arc.service.subcategory=..." # if applicable
  - "arc.service.swappable=true|false"
  - "arc.service.alternatives=..." # if swappable
```

---

## Migration from Legacy

**Legacy Files:** `deployments/docker/legacy/`  
**Status:** ⚠️ Deprecated (November 9, 2025)  
**Removal Date:** November 16, 2025

See `docs/guides/MIGRATION-v1-to-v2.md` for migration instructions.

---

## Troubleshooting

### Issue: Network not found
```bash
make init-network
```

### Issue: Volume not found
```bash
make init-volumes
```

### Issue: Services not starting
```bash
# Validate compose files
make validate-compose

# Check paths
make validate-paths

# Check logs
make logs
```

---

## Best Practices

1. **Always use profiles** - Don't start services you don't need
2. **Use Makefile targets** - Better than raw docker compose commands
3. **Check health before testing** - Ensure services are ready
4. **Monitor resource usage** - Each profile has different requirements
5. **Use .env files** - Never hardcode credentials in compose files
6. **Backup before updates** - Use `make backup-db` regularly

---

## Related Documentation

- **Makefile:** `/Makefile` (root)
- **Operations Guide:** `/docs/OPERATIONS.md`
- **Architecture:** `/docs/architecture/README.md`
- **Migration Guide:** `/docs/guides/MIGRATION-v1-to-v2.md`
- **Analysis Report:** `/reports/2025/11/0911-MAKEFILE-ARCHITECTURE-ANALYSIS.md`

---

**Last Updated:** November 9, 2025  
**Version:** 2.0.0  
**Status:** ✅ Production Ready
