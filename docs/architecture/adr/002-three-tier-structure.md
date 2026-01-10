# ADR-002: Three-Tier Directory Structure

**Task:** T069
**Status:** Accepted
**Date:** 2026-01-11
**Decision Makers:** A.R.C. Platform Team

---

## Context

The A.R.C. platform contains diverse services: databases, message queues, observability tools, identity management, AI agents, and utility services. As the platform grows, developers need a clear organizational structure to:

1. Quickly find any service's source code and Dockerfile
2. Understand a service's role and importance
3. Know which services are required vs. optional
4. Make informed decisions about where new services belong

### Problem Statement

How should we organize services in the directory structure to optimize for discoverability, clarity, and scalability?

### Relevant Constraints

- Must support 50+ services without becoming unwieldy
- New developers should understand structure in <5 minutes
- Must distinguish between required and optional components
- Must support both infrastructure and application services
- Directory structure should guide architectural decisions

---

## Decision Drivers

- **Discoverability**: Find any service in <2 minutes
- **Clarity**: Immediately understand a service's role
- **Scalability**: Structure works from 10 to 100+ services
- **Decision support**: Structure helps categorization decisions
- **Operational clarity**: Know what's essential vs. optional

---

## Considered Options

### Option 1: Flat Structure

All services at the same level.

```
services/
├── postgres/
├── redis/
├── grafana/
├── sherlock-brain/
└── raymond/
```

**Pros:**
- Simple to understand
- No categorization debates

**Cons:**
- Doesn't scale beyond 15-20 services
- No indication of service importance
- Hard to identify required vs. optional
- All services appear equally important

### Option 2: Two-Tier (Infrastructure/Application)

Split between infrastructure and application code.

```
infrastructure/
├── postgres/
├── redis/
└── grafana/
application/
├── sherlock-brain/
└── raymond/
```

**Pros:**
- Clear infrastructure vs. application split
- Better than flat

**Cons:**
- Doesn't distinguish required vs. optional infrastructure
- Still limited categorization
- "Infrastructure" is too broad a category

### Option 3: Three-Tier (Core/Plugins/Services)

Separate essential, optional infrastructure, and application services.

```
core/           # Required - platform fails without these
├── postgres/
├── redis/
└── nats/
plugins/        # Optional - swappable infrastructure
├── grafana/
├── prometheus/
└── kratos/
services/       # Application - business logic
├── sherlock-brain/
└── raymond/
```

**Pros:**
- Clear distinction: required vs. optional vs. application
- Scales well (subcategories possible within each tier)
- Guides operational decisions (what to monitor closely)
- Supports swappability thinking for plugins
- Matches deployment profiles (minimal, observability, full)

**Cons:**
- More complex initial structure
- Requires categorization decisions
- Some edge cases require judgment

### Option 4: Domain-Driven Structure

Organize by business domain.

```
observability/
├── grafana/
├── prometheus/
└── loki/
persistence/
├── postgres/
└── redis/
agents/
├── sherlock-brain/
└── scarlett-voice/
```

**Pros:**
- Groups related services
- Domain-focused organization

**Cons:**
- Doesn't indicate importance/requirement level
- Cross-cutting concerns (where does OTEL go?)
- Requires more directories upfront
- Less clear deployment story

---

## Decision

We will use **Option 3: Three-Tier Structure** with the following organization:

```
platform-spike/
├── core/           # ESSENTIAL - Platform fails without these
│   ├── persistence/
│   │   ├── postgres/
│   │   └── redis/
│   ├── messaging/
│   │   ├── nats/
│   │   └── pulsar/
│   ├── gateway/
│   │   └── traefik/
│   └── telemetry/
│       └── otel-collector/
│
├── plugins/        # OPTIONAL - Swappable, not always needed
│   ├── observability/
│   │   ├── grafana/
│   │   ├── prometheus/
│   │   ├── jaeger/
│   │   └── loki/
│   └── identity/
│       └── kratos/
│
├── services/       # APPLICATION - Business logic and AI agents
│   ├── arc-sherlock-brain/
│   ├── arc-scarlett-voice/
│   ├── arc-piper-tts/
│   └── utilities/
│       └── raymond/
│
└── .docker/        # Shared base images
    └── base/
        ├── python-ai/
        └── go-infra/
```

### Tier Definitions

| Tier | Definition | Deployment | SLA |
|------|------------|------------|-----|
| `core/` | Required for platform operation | Always | 99.99% |
| `plugins/` | Optional infrastructure, swappable | Profile-based | 99.9% |
| `services/` | Application logic | Feature-based | 99.9% |

### Rationale

1. **Operational clarity**: Immediately know which services are critical
2. **Deployment profiles**: Tiers map to `make up-minimal`, `make up-observability`, `make up-full`
3. **Scalability**: Each tier can add subcategories as it grows
4. **Decision support**: Clear criteria for categorization (see SERVICE-CATEGORIZATION.md)
5. **Swappability**: Plugins tier encourages thinking about alternatives

---

## Consequences

### Positive

- Developers find services quickly (<2 minutes)
- New team members understand structure immediately
- Deployment profiles are obvious from directory structure
- Encourages proper categorization of new services
- Supports scaling to 50+ services with subcategories

### Negative

- Some services require judgment (is OTEL core or plugin?)
- Requires maintaining categorization documentation
- Moving services between tiers requires migration

### Neutral

- Edge cases will arise and require ADRs
- Structure may evolve as platform grows

---

## Implementation

### Directory Creation

```bash
mkdir -p core/{persistence,messaging,gateway,telemetry}
mkdir -p plugins/{observability,identity,search}
mkdir -p services/utilities
mkdir -p .docker/base/{python-ai,go-infra}
```

### Categorization Guide

See [SERVICE-CATEGORIZATION.md](../SERVICE-CATEGORIZATION.md) for detailed decision tree.

### Validation

The structure is validated by:
- `scripts/validate/check-structure.py` - Validates directory structure
- `scripts/validate/check-service-registry.py` - Validates SERVICE.MD alignment

---

## Related

- [SERVICE-CATEGORIZATION.md](../SERVICE-CATEGORIZATION.md) - Decision tree
- [SCALING-STRATEGY.md](../SCALING-STRATEGY.md) - When to restructure
- [SERVICE.MD](../../../SERVICE.MD) - Service registry
- [ADR-001](./001-codename-convention.md) - Naming conventions

---

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-01-11 | Platform Team | Initial acceptance |
