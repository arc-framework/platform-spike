# Directory Structure Design & Guidelines

**Feature:** 002-stabilize-framework  
**Date:** January 10, 2026  
**Status:** Current Implementation + Future Growth Strategy

---

## Current Structure (Validated & Working)

```
platform-spike/
├── core/                        # Essential infrastructure (required to run)
├── plugins/                     # Optional/swappable components
├── services/                    # Application logic (A.R.C.-specific)
├── deployments/                 # Deployment configurations
├── libs/                        # Shared libraries
├── docs/                        # Documentation
├── scripts/                     # Automation scripts
├── tools/                       # Development tools
├── tests/                       # Integration tests
├── Makefile                     # Orchestration
├── SERVICE.MD                   # Service registry (SOURCE OF TRUTH)
└── .env.example                 # Environment template
```

**Decision:** Keep this structure. It's working. Don't fix what ain't broken.

---

## Tier 1: core/ (Essential Infrastructure)

### Criteria for core/

**Ask yourself:** If this service dies, does the platform stop functioning?

- ✅ **YES** → `core/`
- ❌ **NO** → `plugins/` or `services/`

### Current core/ Structure

```
core/
├── caching/
│   └── redis/                   # arc-sonic-cache
│       ├── Dockerfile
│       ├── redis.conf
│       └── README.md
├── feature-management/
│   └── unleash/                 # arc-mystique-flags
│       ├── docker-compose.yml
│       └── README.md
├── gateway/
│   └── traefik/                 # arc-heimdall-gateway
│       ├── traefik.yml
│       ├── dynamic/
│       └── README.md
├── media/
│   └── livekit/                 # arc-daredevil-voice
│       ├── livekit.yaml
│       └── README.md
├── messaging/
│   ├── ephemeral/
│   │   └── nats/                # arc-flash-pulse
│   │       ├── nats.conf
│   │       └── README.md
│   └── durable/
│       └── pulsar/              # arc-strange-stream
│           ├── standalone.conf
│           └── README.md
├── persistence/
│   └── postgres/                # arc-oracle-sql
│       ├── Dockerfile
│       ├── init.sql
│       └── README.md
├── secrets/
│   └── infisical/               # arc-fury-vault
│       └── README.md
└── telemetry/
    └── otel-collector/          # arc-widow-otel
        ├── Dockerfile
        ├── otel-collector-config.yml
        └── README.md
```

### Naming Convention: core/{category}/{technology}/

**Why technology name, not codename?**
- `core/gateway/traefik/` is clearer than `core/gateway/heimdall/`
- Developers searching for "Traefik config" find it immediately
- Codenames are for container names and SERVICE.MD, not directories

**Categories:**
- `gateway/` - API gateway, ingress
- `persistence/` - Databases (SQL, vector)
- `caching/` - In-memory caches
- `messaging/` - Message brokers (ephemeral/durable)
- `secrets/` - Secret management
- `telemetry/` - Observability infrastructure
- `media/` - Real-time media (WebRTC, SFUs)
- `feature-management/` - Feature flags

---

## Tier 2: plugins/ (Optional/Swappable Components)

### Criteria for plugins/

**Ask yourself:** Could I swap this for an alternative without major refactoring?

- ✅ **YES** → `plugins/`
- ❌ **NO** → `core/`

### Current plugins/ Structure

```
plugins/
├── observability/
│   ├── logging/
│   │   └── loki/                # arc-watson-logs
│   │       └── README.md
│   ├── metrics/
│   │   └── prometheus/          # arc-house-metrics
│   │       ├── prometheus.yml
│   │       └── README.md
│   ├── tracing/
│   │   └── jaeger/              # arc-columbo-traces
│   │       └── README.md
│   └── visualization/
│       └── grafana/             # arc-friday-viz
│           ├── dashboards/
│           ├── datasources/
│           └── README.md
├── search/                      # Future: Qdrant, Elasticsearch
│   └── README.md
├── security/
│   └── identity/
│       └── kratos/              # arc-jarvis-identity
│           ├── Dockerfile
│           ├── kratos.yml
│           └── README.md
└── storage/                     # Future: MinIO, S3
    └── README.md
```

### Naming Convention: plugins/{category}/{technology}/

**Alternatives are possible:**
- Identity: Kratos → Keycloak, Auth0, Cognito
- Logging: Loki → Elasticsearch, Splunk
- Metrics: Prometheus → InfluxDB, Datadog
- Tracing: Jaeger → Zipkin, Tempo
- Search: Qdrant → Elasticsearch, Meilisearch

---

## Tier 3: services/ (Application Logic)

### Criteria for services/

**Ask yourself:** Is this A.R.C.-specific business logic?

- ✅ **YES** → `services/`
- ❌ **NO** → `core/` or `plugins/`

### Current services/ Structure

```
services/
├── arc-piper-tts/               # Text-to-speech (Piper model)
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── src/
│   ├── models/
│   ├── tests/
│   └── README.md
├── arc-scarlett-voice/          # Voice agent (CORE type)
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── src/
│   ├── tests/
│   └── README.md
├── arc-sherlock-brain/          # LangGraph reasoning engine (CORE type)
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── src/
│   ├── config/
│   ├── tests/
│   └── README.md
└── utilities/
    └── raymond/                 # Utility service
        ├── Dockerfile
        ├── ARCHITECTURE.md
        └── README.md
```

### Naming Convention: services/{arc-codename}/

**Why codename in directory name?**
- These are A.R.C.-specific services (not generic technologies)
- `arc-sherlock-brain` tells you exactly what it is
- Aligns with container names and GHCR image names
- Prevents confusion (What's "brain"? Oh, `arc-sherlock-brain` - the LangGraph reasoner)

### Future Growth Strategy

**When services/ has 15+ entries, consider sub-categorization:**

```
services/
├── agents/                      # Reasoning, planning agents
│   ├── arc-sherlock-brain/
│   └── arc-scarlett-voice/
├── workers/                     # Background workers
│   ├── arc-ramsay-critic/       # QA worker
│   └── arc-drago-gym/           # Adversarial trainer
├── utilities/                   # Supporting services
│   ├── arc-piper-tts/
│   └── raymond/
└── guardrails/                  # Safety, compliance
    └── arc-robocop-guard/
```

**Trigger for reorganization:** When `ls services/` outputs >15 directories.

---

## Supporting Directories

### deployments/

**Purpose:** Deployment configurations (Docker Compose, Kubernetes, Terraform)

```
deployments/
├── docker/
│   ├── docker-compose.base.yml
│   ├── docker-compose.core.yml
│   ├── docker-compose.observability.yml
│   ├── docker-compose.security.yml
│   ├── docker-compose.services.yml
│   └── README.md
├── kubernetes/                  # Future: K8s manifests
│   └── README.md
└── terraform/                   # Future: IaC
    └── README.md
```

**Principle:** Code lives in `core/`, `plugins/`, `services/`. Deployment configs live here.

### libs/

**Purpose:** Shared libraries used by multiple services

```
libs/
└── python-sdk/                  # arc_common Python SDK
    ├── arc_common/
    │   ├── __init__.py
    │   ├── config.py
    │   ├── logging.py
    │   ├── nats_client.py
    │   └── telemetry.py
    ├── tests/
    ├── pyproject.toml
    ├── requirements.txt
    └── README.md
```

**Future possibilities:**
- `libs/go-common/` - Shared Go packages
- `libs/proto/` - Protobuf definitions
- `libs/contracts/` - API contracts

### docs/

**Purpose:** Architecture, guides, references

```
docs/
├── architecture/
│   ├── adr/                     # Architecture Decision Records
│   ├── nats-subjects.md
│   ├── pulsar-topics.md
│   └── README.md
├── guides/
│   ├── DOCKER_LABELS.md
│   ├── ENV-MIGRATION.md
│   ├── NAMING-CONVENTIONS.md
│   └── README.md
├── reference/                   # Future: API docs
└── API_DOCUMENTATION_PLAN.md
```

**Principle:** Documentation lives separately from code.

### scripts/

**Purpose:** Automation scripts (setup, validation, migration)

```
scripts/
├── setup/
│   ├── generate-secrets.sh
│   ├── migrate-postgres.sh
│   └── validate-secrets.sh
├── validate/                    # NEW: Validation automation
│   ├── check-structure.py
│   ├── check-dockerfiles.sh
│   ├── check-security.sh
│   └── check-image-sizes.py
├── livekit/
│   ├── generate-token.sh
│   └── validate-dns.sh
├── messaging/
│   ├── test-nats.sh
│   └── test-pulsar.sh
└── README.md
```

### tools/

**Purpose:** Development tools (linters, generators, analysis)

```
tools/
├── analysis/                    # Analysis tools
├── journal/                     # Development journal
├── prompts/                     # AI prompts
└── README.md
```

### tests/

**Purpose:** Integration tests (unit tests live with services)

```
tests/
├── integration/                 # Cross-service integration tests
└── README.md
```

---

## New Additions (Phase 2 Implementation)

### .docker/ (Shared Base Images)

```
.docker/
├── base/
│   ├── go-infra/
│   │   ├── Dockerfile
│   │   └── README.md
│   └── python-ai/
│       ├── Dockerfile
│       └── README.md
└── README.md
```

**Why hidden directory?**
- Not a service, just build infrastructure
- Keeps root clean
- Convention from `.github/`, `.vscode/`

### .templates/ (Dockerfile Templates)

```
.templates/
├── Dockerfile.go.template
├── Dockerfile.python.template
└── README.md
```

**Why not `templates/`?**
- Avoids confusion with runtime templates (email, report templates)
- Clearly build-time, not runtime
- Consistent with `.github/`, `.docker/`

---

## Decision Tree: Where Does X Go?

### Is it a service/container?

**YES** → Continue to next question  
**NO** → Is it a script? → `scripts/`  
**NO** → Is it docs? → `docs/`  
**NO** → Is it a shared library? → `libs/`  
**NO** → Is it a deployment config? → `deployments/`

### Is it required for the platform to function?

**YES** → `core/{category}/{technology}/`  
**NO** → Continue to next question

### Is it swappable with alternatives?

**YES** → `plugins/{category}/{technology}/`  
**NO** → Continue to next question

### Is it A.R.C.-specific business logic?

**YES** → `services/{arc-codename}/`  
**NO** → Reconsider if it belongs in the platform

---

## SERVICE.MD Alignment

**Every service in SERVICE.MD MUST have a corresponding directory.**

**Mapping Rules:**

| SERVICE.MD Type | Directory Location | Example |
|----------------|-------------------|---------|
| INFRA (Traefik, Postgres, Redis) | `core/{category}/{tech}/` | `core/gateway/traefik/` |
| INFRA (Loki, Prometheus, Jaeger) | `plugins/{category}/{tech}/` | `plugins/observability/logging/loki/` |
| CORE (Sherlock, Scarlett) | `services/{codename}/` | `services/arc-sherlock-brain/` |
| WORKER (Ramsay, Drago) | `services/{codename}/` | `services/arc-ramsay-critic/` |
| SIDECAR (Pathfinder, Sentry) | `services/{codename}/` or `{parent}/sidecars/` | TBD based on coupling |

**Validation:** `scripts/validate/check-structure.py` enforces this mapping.

---

## Growth Strategy (Future-Proofing)

### At 30 Services
- Current structure still works
- Consider sub-categorizing `services/` (agents/, workers/, utilities/)

### At 50 Services
- **Definitely** sub-categorize `services/`
- Consider splitting large categories in `plugins/` (e.g., `plugins/observability/` might become separate directories)

### At 100+ Services
- Revisit monorepo vs. polyrepo decision
- Consider workspace/module system (Bazel, Nx, Turborepo)
- Current structure still provides foundation

---

## README.md Requirements

**Every directory with a service MUST have a README.md:**

```markdown
# Service Name (Codename)

**Type:** INFRA / CORE / WORKER / SIDECAR  
**Codename:** Sherlock, Heimdall, etc.  
**Technology:** LangGraph, Traefik, etc.  

## What It Does

[One-sentence description]

## Configuration

- Environment variables
- Config files
- Secrets required

## Dependencies

- Depends on: [Other services]
- Required by: [Other services]

## Health Check

How to verify it's working

## Troubleshooting

Common issues and fixes
```

---

## Validation

**Automated checks (runs in CI/CD):**

```bash
# Verify directory structure consistency
make validate-structure

# Checks:
# 1. Every SERVICE.MD entry has a directory
# 2. Every directory has a README.md
# 3. Naming conventions followed
# 4. No orphaned directories
```

---

## Migration Impact

**This spec does NOT require moving existing services.**

Current structure is already good. This document:
1. **Formalizes** what we're already doing
2. **Documents** decision criteria
3. **Provides** growth strategy
4. **Enables** validation automation

**No breaking changes.**

---

## References

- **SERVICE.MD** - Service registry (source of truth)
- **PROGRESS.MD** - Naming convention history (Option C)
- **Architecture README** - `docs/architecture/README.md`

---

**Status:** ✅ Current Structure Validated + Growth Strategy Defined

**Last Updated:** January 10, 2026

**"If you can't navigate the codebase in 2 minutes, the structure has failed."** - The A.R.C. Architect

