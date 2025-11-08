# A.R.C. Framework Restructuring - Executive Summary

**Date**: November 9, 2025  
**Status**: Planning Complete - Ready for Implementation  
**Version**: 2.1 (Kratos moved to plugins)

---

## 🎯 Key Findings

### Your Insights Were Correct ✅

1. **NATS, Pulsar, Postgres ARE CORE** - Essential for agent communication and state
2. **Kratos is NOT CORE** - You have other plans for identity/auth

---

## 📋 Final Core Services List

| Service | Core? | Swappable? | Why Core? |
|---------|-------|------------|-----------|
| **OpenTelemetry Collector** | ✅ YES | ❌ NO | Central telemetry hub |
| **API Gateway** (Traefik) | ✅ YES | ✅ YES | Traffic routing |
| **Message Broker** (NATS) | ✅ YES | ✅ YES | Agent communication |
| **Event Store** (Pulsar) | ✅ YES | ✅ YES | Conveyor Belt pattern |
| **Database** (Postgres) | ✅ YES | ✅ YES | Agent state + vectors |
| **Cache** (Redis) | ✅ YES | ✅ YES | Session state, locks |
| **Secrets** (Infisical) | ✅ YES | ✅ YES | API keys, credentials |
| **Feature Flags** (Unleash) | ⚠️ OPTIONAL | ✅ YES | Can use env vars |
| | | | |
| **Identity** (Kratos) | ❌ NO | ✅ YES | Plugin - you have other plans |
| **Loki** (Log Storage) | ❌ NO | ✅ YES | Backend (pluggable) |
| **Prometheus** (Metrics) | ❌ NO | ✅ YES | Backend (pluggable) |
| **Jaeger** (Tracing) | ❌ NO | ✅ YES | Backend (pluggable) |
| **Grafana** (Visualization) | ❌ NO | ✅ YES | Dashboard (pluggable) |

---

## 🏗️ Architecture Pattern: "Core with Plugins"

### Core Services (7 + 1 Optional)
```
core/
├── gateway/              # Traefik (swappable: Kong, Envoy, NGINX)
├── telemetry/            # OpenTelemetry Collector (fixed)
├── messaging/
│   ├── ephemeral/        # NATS (swappable: RabbitMQ, Redis Streams)
│   └── durable/          # Pulsar (swappable: Kafka, EventStore)
├── persistence/          # Postgres (swappable: MySQL, CockroachDB)
├── caching/              # Redis (swappable: Valkey, DragonflyDB)
├── secrets/              # Infisical (swappable: Vault, AWS Secrets)
└── feature-management/   # Unleash (optional, swappable)
```

### Pluggable Services
```
plugins/
├── security/             # ← Kratos goes here
│   └── identity/         # Kratos, Keycloak, Auth0, custom JWT
├── observability/        # Loki, Prometheus, Jaeger, Grafana
├── storage/              # MinIO, S3, GCS
├── search/               # Elasticsearch, Meilisearch
└── ai-services/          # Ollama, vLLM
```

---

## 🚀 Deployment Profiles

### Minimal Profile (Development)
```bash
make up profile=minimal
```
**Includes**: 
- OTel Collector
- Traefik
- Postgres
- Redis
- NATS
- Infisical

**Resources**: ~2GB RAM  
**Note**: No IAM - agents communicate directly

### Observability Profile (Staging)
```bash
make up profile=observability
```
**Includes**: Minimal + Pulsar + Loki + Prometheus + Jaeger + Grafana  
**Resources**: ~4GB RAM

### Full Stack Profile (Production)
```bash
make up profile=full-stack
```
**Includes**: Everything (add Kratos if needed)  
**Resources**: ~8GB RAM

---

## 📁 Directory Structure (Simplified)

```
arc-framework/
├── core/                             # Required services
│   ├── gateway/                      # Traefik, Kong, Envoy
│   ├── telemetry/                    # OpenTelemetry
│   ├── messaging/                    # NATS, Pulsar
│   ├── persistence/                  # Postgres
│   ├── caching/                      # Redis
│   ├── secrets/                      # Infisical, Vault
│   └── feature-management/           # Unleash
│
├── plugins/                          # Optional services
│   ├── security/                     # Kratos, Keycloak (when needed)
│   ├── observability/                # Loki, Prometheus, Jaeger, Grafana
│   ├── storage/                      # MinIO, S3
│   └── search/                       # Elasticsearch
│
├── services/                         # Application services
│   ├── agents/                       # AI agent services
│   │   ├── examples/                 # Example agents
│   │   ├── templates/                # Agent templates
│   │   └── user-agents/              # User agents
│   └── utilities/                    # Utility services
│
├── libs/                             # SDKs
│   ├── arc-sdk-go/
│   ├── arc-sdk-python/
│   └── arc-sdk-typescript/
│
├── deployments/                      # Deployment configs
│   ├── docker/
│   ├── kubernetes/
│   └── terraform/
│
├── config/                           # Global configs
│   ├── environments/
│   └── profiles/
│
├── scripts/                          # Automation
│   ├── setup/
│   ├── operations/
│   └── plugin-manager/
│
├── tests/                            # Testing
│
├── docs/                             # Documentation
│   ├── architecture/
│   ├── guides/
│   └── reference/
│
└── tools/                            # Dev tools (YOUR TOOLS HERE)
    ├── arc-cli/
    ├── analysis/                     # Your analysis tools
    ├── journal/                      # Your journal tools
    ├── generators/
    └── validation/
```

---

## 🎯 Your Dynamic Core Approach

### The Strategy
1. **Start Building Agent Services** (5-10 services)
2. **Identify Hard Dependencies**
3. **Move to Core as Needed**
4. **Review Every Sprint**

### Decision Framework
```
Can agents function without it?
├─ NO  → Move to CORE
└─ YES → Keep as PLUGIN

Is it tightly coupled?
├─ YES → Keep in CORE
└─ NO  → Create interface, make plugin
```

---

## 📝 Next Steps

### Phase 1: Create Structure (1-2 days)
```bash
# Create directories
mkdir -p core/{gateway,telemetry,messaging,persistence,caching,secrets,feature-management}
mkdir -p plugins/{security/identity,observability,storage,search}
mkdir -p services/agents/{examples,templates,user-agents}
mkdir -p tools/{arc-cli,analysis,journal,generators}

# Move services
# (Kratos → plugins/security/identity/)
```

### Phase 2: Build First Agent (Week 2)
- Create example agent
- Validate core dependencies
- Identify any missing services
- Move to core if needed

### Phase 3: Iterate (Ongoing)
- Build 5-10 agent services
- Refine core based on real usage
- Document patterns

---

## ✅ Ready to Proceed

**Confirmed Decisions**:
- ✅ NATS, Pulsar, Postgres = CORE
- ✅ Kratos = PLUGIN (you have other plans)
- ✅ Dynamic core (move services as needed)
- ✅ Tools separated from framework

**Next**: Start Phase 1 implementation?

---

**Status**: ✅ Planning Complete  
**Version**: 2.1 (Kratos as plugin)  
**Date**: November 9, 2025

