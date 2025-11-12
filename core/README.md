# Core Services

**Required** infrastructure components that the A.R.C. Framework depends on. These services are essential and cannot be removed.

---

## Overview

Core services provide foundational capabilities that all other services depend on. Unlike plugins, these are mandatory for framework operation and have deep integration points throughout the system.

---

## Core Service Categories

### [Gateway](./gateway/)
API Gateway and service mesh

#### [Traefik](./gateway/traefik/)
- **Purpose:** API Gateway, reverse proxy, automatic service discovery
- **Port:** 80 (HTTP), 443 (HTTPS), 8080 (Dashboard)
- **Config:** `traefik.yml`
- **Status:** ✅ Configured

### [Telemetry](./telemetry/)
Observability pipeline

#### [OpenTelemetry Collector](./telemetry/)
- **Purpose:** Unified telemetry collection hub (logs, metrics, traces)
- **Port:** 4317 (gRPC), 4318 (HTTP), 13133 (health)
- **Config:** `otel-collector-config.yml`
- **Status:** ✅ Configured
- **Note:** Custom-built with health check endpoint

### [Messaging](./messaging/)
Event and message distribution

#### [Ephemeral - NATS](./messaging/ephemeral/nats/)
- **Purpose:** Agent-to-agent messaging, job queues, pub/sub
- **Port:** 4222 (client), 8222 (monitoring)
- **Status:** ✅ Configured
- **Use Case:** Real-time agent communication

#### [Durable - Pulsar](./messaging/durable/pulsar/)
- **Purpose:** Event streaming "Conveyor Belt", durable event log
- **Port:** 6650 (broker), 8080 (HTTP)
- **Status:** ✅ Configured
- **Use Case:** Event sourcing, cross-service events

### [Persistence](./persistence/)
Data storage

#### [Postgres](./persistence/postgres/)
- **Purpose:** Primary database, agent state, vector storage (pgvector)
- **Port:** 5432
- **Config:** `init.sql`, `.env.example`
- **Status:** ✅ Configured
- **Extensions:** pgvector for RAG/embeddings

### [Caching](./caching/)
In-memory data store

#### [Redis](./caching/redis/)
- **Purpose:** Cache, sessions, rate limiting, temporary data
- **Port:** 6379
- **Status:** ✅ Configured

### [Secrets](./secrets/)
Secrets management

#### [Infisical](./secrets/infisical/)
- **Purpose:** Self-hosted secrets vault
- **Port:** 3001
- **Status:** ✅ Configured in stack
- **Note:** Optional for development, required for production

### [Feature Management](./feature-management/)
Feature flags and A/B testing

#### [Unleash](./feature-management/unleash/)
- **Purpose:** Feature flags, experiments, gradual rollouts
- **Port:** 4242
- **Status:** ✅ Configured in stack

---

## Architecture Pattern

```
Pattern: category/[subcategory]/implementation/

Example:
core/
├── gateway/
│   └── traefik/           # Implementation
├── messaging/
│   ├── ephemeral/
│   │   └── nats/          # Implementation
│   └── durable/
│       └── pulsar/        # Implementation
```

---

## Core vs Plugin Decision Criteria

A component is **core** if:
- ✅ Framework breaks without it
- ✅ Deep integration with multiple services
- ✅ Required by agent architecture
- ✅ No reasonable alternative for the use case

A component is a **plugin** if:
- ❌ Framework works without it
- ❌ Multiple alternatives exist
- ❌ Can be swapped at runtime
- ❌ Only some deployments need it

---

## Deployment

### Minimal Core (Development)
```bash
# Start observability core only
make up-observability
```

Includes:
- OpenTelemetry Collector
- Sample application (toolbox)

### Full Core (Production)
```bash
# Start everything
make up
```

Includes:
- All observability services
- Traefik gateway
- NATS + Pulsar messaging
- Postgres + Redis data layer
- Kratos identity
- Unleash feature flags
- Infisical secrets

---

## Configuration

Each core service has:
- **README.md** - Service documentation (coming soon)
- **.env.example** - Environment variables template
- **Config files** - Service-specific configuration

### Quick Setup
```bash
# Initialize all core service configs
make .env

# Or manually for specific service
cp core/postgres/.env.example core/postgres/.env
# Edit .env with your values
```

---

## Service Health

Check core service health:

```bash
# All services
make health-all

# Specific service
make health-postgres
make health-redis
make health-nats
```

---

## See Also

- [Main README](../README.md) - Project overview
- [Plugins](../plugins/) - Optional plugin services
- [Services](../services/) - Application services
- [Operations Guide](../docs/OPERATIONS.md) - Operational procedures
