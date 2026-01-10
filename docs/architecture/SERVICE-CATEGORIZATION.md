# Service Categorization Guide

**Task:** T063
**Last Updated:** January 2026

This guide helps architects and developers determine where a new service belongs in the A.R.C. platform's three-tier structure.

---

## Quick Reference

| Tier | Purpose | Examples |
|------|---------|----------|
| `core/` | Essential infrastructure | PostgreSQL, Redis, NATS, Traefik |
| `plugins/` | Optional, swappable components | Grafana, Prometheus, Kratos |
| `services/` | Application logic & agents | Sherlock, Scarlett, Raymond |

---

## Decision Tree

Use this flowchart to categorize any new service:

```
                    ┌─────────────────────────────────────┐
                    │   Is the service required for the   │
                    │      platform to START?             │
                    └─────────────────┬───────────────────┘
                                      │
                    ┌─────────────────┴───────────────────┐
                    │                                     │
                   YES                                   NO
                    │                                     │
                    ▼                                     ▼
            ┌───────────────┐               ┌─────────────────────────────┐
            │   core/       │               │  Does the service provide   │
            │               │               │  INFRASTRUCTURE capability? │
            │  Essential    │               │  (observability, auth,      │
            │  Platform     │               │   search, messaging)        │
            │  Services     │               └─────────────┬───────────────┘
            └───────────────┘                             │
                                          ┌───────────────┴───────────────┐
                                          │                               │
                                         YES                             NO
                                          │                               │
                                          ▼                               ▼
                              ┌─────────────────────┐         ┌───────────────────┐
                              │  Is it SWAPPABLE    │         │    services/      │
                              │  with alternatives? │         │                   │
                              │                     │         │   Application     │
                              │  (e.g., Prometheus  │         │   Logic &         │
                              │   → InfluxDB)       │         │   AI Agents       │
                              └──────────┬──────────┘         └───────────────────┘
                                         │
                              ┌──────────┴──────────┐
                              │                     │
                             YES                   NO
                              │                     │
                              ▼                     ▼
                      ┌───────────────┐     ┌───────────────┐
                      │   plugins/    │     │   core/       │
                      │               │     │               │
                      │   Optional    │     │   (Rare case) │
                      │   Swappable   │     │               │
                      └───────────────┘     └───────────────┘
```

---

## Detailed Criteria

### Core Services (`core/`)

**Definition**: Services that MUST be running for the platform to function at all.

**Inclusion Criteria**:
- [ ] Platform fails to start without this service
- [ ] Cannot be swapped without major refactoring
- [ ] All other services depend on it (directly or transitively)
- [ ] Provides fundamental capability (storage, messaging, routing)

**Examples**:
| Service | Codename | Reason |
|---------|----------|--------|
| PostgreSQL | arc-oracle | Primary data persistence |
| Redis | arc-sonic | Session storage, caching |
| NATS | arc-flash | Inter-service messaging |
| Pulsar | arc-strange | Durable event streaming |
| Traefik | arc-heimdall | API gateway, routing |
| OTEL Collector | arc-widow | Telemetry pipeline |

**Anti-patterns** (NOT core):
- ❌ Visualization tools (Grafana → plugins)
- ❌ Optional auth providers (Kratos → plugins)
- ❌ Business logic services (agents → services)

---

### Plugin Services (`plugins/`)

**Definition**: Optional components that enhance the platform but aren't required for basic operation.

**Inclusion Criteria**:
- [ ] Platform works without this service (degraded but functional)
- [ ] Alternative implementations exist (can swap)
- [ ] Provides infrastructure capability (not business logic)
- [ ] Not all deployments need it

**Examples**:
| Service | Codename | Swappable With |
|---------|----------|----------------|
| Grafana | arc-friday | Datadog, Kibana |
| Prometheus | arc-house | InfluxDB, Datadog |
| Jaeger | arc-columbo | Zipkin, Honeycomb |
| Loki | arc-watson | Elasticsearch, Datadog |
| Kratos | arc-jarvis | Keycloak, Auth0 |

**Subcategories**:
```
plugins/
├── observability/    # Monitoring, logging, tracing
│   ├── grafana/
│   ├── prometheus/
│   ├── jaeger/
│   └── loki/
├── identity/         # Authentication, authorization
│   └── kratos/
└── search/           # Search engines (future)
    └── typesense/    # (planned)
```

**Anti-patterns** (NOT plugins):
- ❌ Services with no alternatives (PostgreSQL → core)
- ❌ Business logic (agents → services)
- ❌ Client applications (→ services or separate repo)

---

### Application Services (`services/`)

**Definition**: Business logic, AI agents, and application-specific functionality.

**Inclusion Criteria**:
- [ ] Contains business logic specific to A.R.C.
- [ ] AI agents, reasoning engines, or workers
- [ ] Built on top of core/plugins infrastructure
- [ ] Implements domain-specific functionality

**Examples**:
| Service | Codename | Purpose |
|---------|----------|---------|
| arc-sherlock-brain | sherlock | LangGraph reasoning engine |
| arc-scarlett-voice | scarlett | Voice interaction agent |
| arc-piper-tts | piper | Text-to-speech service |
| raymond | raymond | Platform utilities (Go) |

**Subcategories**:
```
services/
├── arc-sherlock-brain/   # AI reasoning
├── arc-scarlett-voice/   # Voice agent
├── arc-piper-tts/        # TTS service
└── utilities/
    └── raymond/          # Platform utilities
```

**Anti-patterns** (NOT services):
- ❌ Generic infrastructure (Redis → core)
- ❌ Swappable monitoring (Grafana → plugins)
- ❌ External third-party tools (→ plugins or vendor/)

---

## Common Scenarios

### Scenario 1: Adding an Analytics Service

**Question**: Where does a new analytics/metrics aggregation service go?

**Analysis**:
1. Required for platform to start? **NO** (platform works without analytics)
2. Provides infrastructure capability? **YES** (metrics aggregation)
3. Swappable with alternatives? **YES** (could use Datadog, custom solution)

**Decision**: `plugins/analytics/` or `plugins/observability/`

---

### Scenario 2: Adding a New AI Agent

**Question**: Where does a new "research agent" go?

**Analysis**:
1. Required for platform to start? **NO**
2. Provides infrastructure capability? **NO** (business logic)
3. Application-specific functionality? **YES**

**Decision**: `services/arc-{codename}-research/`

---

### Scenario 3: Adding a Search Engine

**Question**: Where does Typesense or Meilisearch go?

**Analysis**:
1. Required for platform to start? **NO** (search is optional)
2. Provides infrastructure capability? **YES** (search capability)
3. Swappable with alternatives? **YES** (Typesense ↔ Meilisearch ↔ Elasticsearch)

**Decision**: `plugins/search/typesense/`

---

### Scenario 4: Adding a Message Queue

**Question**: Where does a new queue service go?

**Analysis**:
1. Required for platform to start? **DEPENDS**
   - If replacing NATS/Pulsar: **core/**
   - If supplementary: **plugins/**
2. Swappable? **DEPENDS** on coupling

**Decision**:
- Primary messaging: `core/messaging/`
- Optional/specialized: `plugins/messaging/`

---

## Edge Cases

### When Core vs Plugins is Unclear

If you're unsure whether something is core or plugins, ask:

1. **What happens if this service is down?**
   - Platform crashes → core
   - Features degraded but works → plugins

2. **How many services directly depend on it?**
   - >50% of services → likely core
   - <50% of services → likely plugins

3. **Is there a realistic alternative?**
   - No viable alternative → core
   - Multiple alternatives → plugins

### When Services vs Plugins is Unclear

Ask:

1. **Does it contain A.R.C.-specific business logic?**
   - Yes → services
   - No → plugins

2. **Could another company use this as-is?**
   - Yes → plugins (generic infrastructure)
   - No → services (application-specific)

---

## Naming Conventions

### Core Services
```
core/{category}/{technology}/
Example: core/persistence/postgres/
```

### Plugins
```
plugins/{category}/{technology}/
Example: plugins/observability/grafana/
```

### Application Services
```
services/arc-{codename}-{function}/
services/utilities/{name}/
Example: services/arc-sherlock-brain/
Example: services/utilities/raymond/
```

---

## Migration Checklist

When moving a service between tiers:

- [ ] Update `SERVICE.MD` with new location
- [ ] Move directory to correct tier
- [ ] Update Docker Compose file references
- [ ] Update any hardcoded import paths
- [ ] Run `scripts/validate/check-structure.py`
- [ ] Update documentation cross-references
- [ ] Create ADR documenting the change

---

## Related Documentation

- [Directory Design](./DIRECTORY-DESIGN.md) - Overall structure
- [Docker Image Hierarchy](./DOCKER-IMAGE-HIERARCHY.md) - Build dependencies
- [Scaling Strategy](./SCALING-STRATEGY.md) - When to restructure
- [ADR-002: Three-Tier Structure](./adr/002-three-tier-structure.md) - Why this design
