# A.R.C. Framework Architecture

**Last Updated:** November 9, 2025  
**Version:** 2.1  
**Status:** ✅ Implemented

---

## Overview

The **A.R.C. (Agentic Reasoning Core) Framework** is a production-ready platform for building, deploying, and scaling stateful AI agents. It follows a **"Core with Plugins"** architecture pattern where essential services are in `core/` and optional/swappable services are in `plugins/`.

---

## 🏗️ Architecture Pattern

### Core Services (Required)

Services that agents fundamentally depend on:

```
core/
├── gateway/              # API Gateway (Traefik)
├── telemetry/            # OpenTelemetry Collector
├── messaging/
│   ├── ephemeral/        # Real-time messaging (NATS)
│   └── durable/          # Event streaming (Pulsar)
├── persistence/          # Database (Postgres + pgvector)
├── caching/              # Cache (Redis)
├── secrets/              # Secrets vault (Infisical)
└── feature-management/   # Feature flags (Unleash) - Optional
```

### Plugin Services (Optional/Swappable)

Services that can be added, removed, or swapped:

```
plugins/
├── security/
│   └── identity/         # Authentication (Kratos)
├── observability/
│   ├── logging/          # Log storage (Loki)
│   ├── metrics/          # Metrics storage (Prometheus)
│   ├── tracing/          # Trace storage (Jaeger)
│   └── visualization/    # Dashboards (Grafana)
├── storage/              # Object storage (MinIO/S3)
└── search/               # Full-text search (Elasticsearch)
```

---

## 📋 Core Services Reference

| #   | Service                     | Purpose                  | Swappable   | Location                    |
| --- | --------------------------- | ------------------------ | ----------- | --------------------------- |
| 1   | **OpenTelemetry Collector** | Central telemetry hub    | ❌ No       | `core/telemetry/`           |
| 2   | **Traefik**                 | API Gateway              | ✅ Yes      | `core/gateway/`             |
| 3   | **NATS**                    | Agent-to-agent messaging | ✅ Yes      | `core/messaging/ephemeral/` |
| 4   | **Pulsar**                  | Event Conveyor Belt      | ✅ Yes      | `core/messaging/durable/`   |
| 5   | **Postgres + pgvector**     | Agent state + RAG        | ✅ Yes      | `core/persistence/`         |
| 6   | **Redis**                   | Cache, sessions, locks   | ✅ Yes      | `core/caching/`             |
| 7   | **Infisical**               | Secrets (LLM API keys)   | ✅ Yes      | `core/secrets/`             |
| 8   | **Unleash**                 | Feature flags            | ⚠️ Optional | `core/feature-management/`  |

---

## 🔌 Plugin Services Reference

| Service           | Purpose         | Alternatives             | Location                               |
| ----------------- | --------------- | ------------------------ | -------------------------------------- |
| **Kratos**        | IAM             | Keycloak, Auth0, Cognito | `plugins/security/identity/`           |
| **Loki**          | Log storage     | Elasticsearch, Splunk    | `plugins/observability/logging/`       |
| **Prometheus**    | Metrics storage | InfluxDB, Datadog        | `plugins/observability/metrics/`       |
| **Jaeger**        | Trace storage   | Zipkin, Tempo            | `plugins/observability/tracing/`       |
| **Grafana**       | Visualization   | Kibana                   | `plugins/observability/visualization/` |
| **MinIO/S3**      | Object storage  | GCS, Azure Blob          | `plugins/storage/`                     |
| **Elasticsearch** | Search engine   | OpenSearch, Meilisearch  | `plugins/search/`                      |

---

## 🚀 Deployment Profiles

### Minimal (Development)

**Purpose:** Local development with essential services only

```bash
make up-minimal
```

**Includes:**

**Resources:** ~2GB RAM

### Observability (Staging)

**Purpose:** Full observability for testing and staging

```bash
make up-observability
```

**Includes:** Minimal +

**Resources:** ~4GB RAM

### Full Stack (Production)

**Purpose:** Complete platform with all services

```bash
make up
# or
make up-full
```

**Includes:** Everything (add Kratos if needed)

**Resources:** ~8GB RAM

---

## 🎯 Design Principles

### 1. Core vs Plugin Decision Criteria

**A service is CORE if:**

- ✅ Framework breaks without it
- ✅ Deep integration with multiple services
- ✅ Required by agent architecture
- ✅ No reasonable alternative for the use case

**A service is a PLUGIN if:**

- ❌ Framework works without it
- ❌ Multiple alternatives exist
- ❌ Can be swapped at runtime
- ❌ Only some deployments need it

### 2. Messaging Strategy

The framework uses **two messaging systems** for different purposes:

**NATS (Ephemeral):**

- Fast, sub-millisecond latency
- Real-time agent coordination
- Request/reply patterns
- No persistence needed

**Pulsar (Durable):**

- Persistent event storage
- Event sourcing & CQRS
- Audit logs & compliance
- Event replay capabilities

### 3. Observability Architecture

```
Services → OTel Collector → Observability Backends
                                  ↓
                              Grafana
```

All services send telemetry to the OpenTelemetry Collector (core), which exports to pluggable backends (Loki, Prometheus, Jaeger).

---

## 📁 Complete Directory Structure

```
arc-framework/
├── core/                    # Required services (8)
│   ├── gateway/             # Traefik
│   ├── telemetry/           # OpenTelemetry Collector
│   ├── messaging/
│   │   ├── ephemeral/       # NATS
│   │   └── durable/         # Pulsar
│   ├── persistence/         # Postgres
│   ├── caching/             # Redis
│   ├── secrets/             # Infisical
│   └── feature-management/  # Unleash
│
├── plugins/                 # Optional services
│   ├── security/identity/   # Kratos
│   ├── observability/       # Loki, Prometheus, Jaeger, Grafana
│   ├── storage/             # MinIO, S3
│   └── search/              # Elasticsearch
│
├── services/                # Application services
│   ├── agents/              # AI agent services
│   │   ├── examples/
│   │   └── templates/
│   ├── platform/            # Platform support services
│   └── utilities/           # Helper services
│
├── libs/                    # Shared libraries & SDKs
│   ├── arc-sdk-go/
│   ├── arc-sdk-python/
│   └── arc-sdk-typescript/
│
├── deployments/             # Deployment configurations
│   ├── docker/
│   ├── kubernetes/
│   └── terraform/
│
├── config/                  # Global configurations
├── scripts/                 # Operational scripts
├── tests/                   # Test suites
├── docs/                    # Documentation
│   ├── architecture/        # This directory
│   ├── guides/              # How-to guides
│   └── reference/           # Reference docs
│
└── tools/                   # Development tools
    ├── analysis/            # Repository analysis
    ├── journal/             # Development journal
    ├── prompts/             # AI prompt templates
    ├── generators/          # Code generators
    └── validation/          # Validators
```

---

## 🔄 Dynamic Core Strategy

The framework follows a **dynamic core** approach:

### Process

1. **Start building** agent services
2. **Identify** hard dependencies through usage
3. **Move to core** as needed
4. **Review regularly** (every sprint)

### Decision Framework

```
Can agents function without it?
├─ NO  → Move to CORE
└─ YES → Keep as PLUGIN

Is it tightly coupled to many services?
├─ YES → Keep in CORE
└─ NO  → Create interface, make pluggable
```

---

## 🛠️ Swapping Implementations

Most core services can be swapped with alternatives:

### Example: Swap NATS with RabbitMQ

```yaml
# core/messaging/ephemeral/rabbitmq/docker-compose.yml
services:
  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - '5672:5672'
      - '15672:15672'
```

Update service configurations to use new endpoint.

---

## 📊 Resource Requirements

| Profile           | Services     | Memory | CPU     | Disk |
| ----------------- | ------------ | ------ | ------- | ---- |
| **Minimal**       | 6 core       | ~2GB   | 2 cores | 10GB |
| **Observability** | 11 services  | ~4GB   | 4 cores | 20GB |
| **Full Stack**    | 15+ services | ~8GB   | 8 cores | 50GB |

---

## 🔐 Security Considerations

1. **Secrets Management** - All secrets in Infisical (core)
2. **Identity** - Optional Kratos (plugin) or custom auth
3. **Network Security** - Traefik handles SSL/TLS
4. **Access Control** - Service-level authentication
5. **Audit Logging** - All events to Pulsar

---

## 📚 Additional Documentation

### Architecture Documents (Historical)

See `archive/` directory for historical planning documents:

- `RESTRUCTURING-SUMMARY.md` - Original restructuring plan

### Related Documentation

- [Main README](../../README.md) - Project overview
- [Operations Guide](../OPERATIONS.md) - Operational procedures
- [Naming Conventions](../guides/NAMING-CONVENTIONS.md) - Standards
- [Core Services](../../core/) - Core service documentation
- [Plugins](../../plugins/) - Plugin documentation

---

## 🎯 Next Steps

1. **Deploy** using appropriate profile
2. **Build** first agent service
3. **Validate** core dependencies
4. **Iterate** on architecture as needed

**Questions?** See [documentation index](../README.md) or [operations guide](../OPERATIONS.md).
