# Scaling Strategy

**Task:** T064
**Last Updated:** January 2026

This document provides guidance for scaling the A.R.C. platform's directory structure and service organization as the platform grows.

---

## Current State

### Service Count by Tier

| Tier | Current Count | Soft Limit | Hard Limit |
|------|---------------|------------|------------|
| `core/` | 6 | 10 | 15 |
| `plugins/` | 5 | 15 | 25 |
| `services/` | 4 | 15 | 30 |

### When to Restructure

**Add subdirectories when**:
- A tier exceeds 15 services
- Clear categorical groupings emerge (3+ services per category)
- Navigation becomes difficult

---

## Growth Strategies

### Strategy 1: Subdirectory Grouping

When a tier grows beyond 15 services, introduce categorical subdirectories.

**Before** (flat structure):
```
services/
├── arc-sherlock-brain/
├── arc-scarlett-voice/
├── arc-piper-tts/
├── arc-watson-research/
├── arc-friday-scheduler/
├── arc-jarvis-assistant/
├── arc-alfred-butler/
├── arc-cortana-search/
└── raymond/
```

**After** (grouped structure):
```
services/
├── agents/
│   ├── arc-sherlock-brain/
│   ├── arc-watson-research/
│   └── arc-jarvis-assistant/
├── voice/
│   ├── arc-scarlett-voice/
│   └── arc-piper-tts/
├── automation/
│   ├── arc-friday-scheduler/
│   └── arc-alfred-butler/
└── utilities/
    └── raymond/
```

### Strategy 2: Variant Handling (GPU/CPU)

When services need hardware-specific variants:

**Option A: Separate Dockerfiles** (Recommended for small differences)
```
services/arc-sherlock-brain/
├── Dockerfile          # CPU version (default)
├── Dockerfile.gpu      # GPU-accelerated version
├── src/
└── README.md
```

**Option B: Separate Directories** (For significant differences)
```
services/
├── arc-sherlock-brain/      # CPU version
└── arc-sherlock-brain-gpu/  # GPU version (separate codebase)
```

**Option C: Build Args** (For runtime selection)
```dockerfile
ARG COMPUTE_TARGET=cpu
FROM arc-base-python-ai:3.11-${COMPUTE_TARGET}
```

**Recommendation**: Use Option A for most cases. Option B only when GPU version requires completely different dependencies or architecture.

### Strategy 3: Multi-Tenancy

For services that need tenant-specific configurations:

**Shared Service Model** (Recommended):
```
services/arc-sherlock-brain/
├── Dockerfile
├── src/
├── config/
│   ├── default.yaml        # Default configuration
│   └── tenants/            # Tenant overrides
│       ├── tenant-a.yaml
│       └── tenant-b.yaml
└── README.md
```

**Separate Deployment Model** (For strict isolation):
```
deployments/
├── docker/
│   ├── docker-compose.tenant-a.yml
│   └── docker-compose.tenant-b.yml
└── kubernetes/
    ├── tenant-a/
    └── tenant-b/
```

---

## Thresholds and Triggers

### When to Add Subcategories

| Trigger | Action |
|---------|--------|
| 15+ services in a tier | Introduce subcategories |
| 5+ services of same type | Create type-specific subdirectory |
| 3+ related services | Consider grouping |
| Navigation takes >30 seconds | Restructure for clarity |

### When to Split Services

| Trigger | Action |
|---------|--------|
| Service >1000 LOC | Consider splitting |
| >3 distinct responsibilities | Split by responsibility |
| Different scaling requirements | Split for independent scaling |
| Different deployment frequencies | Split for independent deployment |

### When to Merge Services

| Trigger | Action |
|---------|--------|
| <100 LOC service | Consider merging with related service |
| Always deployed together | Consider single service |
| Tight coupling | Merge or refactor interface |

---

## Directory Structure Evolution

### Phase 1: MVP (Current)

```
platform-spike/
├── core/           # 6 services
├── plugins/        # 5 services
├── services/       # 4 services
└── libs/           # Shared libraries
```

### Phase 2: Growth (10-25 services)

```
platform-spike/
├── core/
│   ├── persistence/    # postgres, redis
│   ├── messaging/      # nats, pulsar
│   └── gateway/        # traefik, otel
├── plugins/
│   ├── observability/  # grafana, prometheus, jaeger, loki
│   ├── identity/       # kratos
│   └── search/         # typesense (new)
├── services/
│   ├── agents/         # AI reasoning agents
│   ├── voice/          # Voice-related services
│   └── utilities/      # Platform utilities
└── libs/
    ├── python/         # Shared Python libraries
    └── go/             # Shared Go libraries
```

### Phase 3: Enterprise (25-50 services)

```
platform-spike/
├── core/
│   ├── persistence/
│   ├── messaging/
│   ├── gateway/
│   └── telemetry/
├── plugins/
│   ├── observability/
│   ├── identity/
│   ├── search/
│   ├── analytics/
│   └── integrations/
├── services/
│   ├── agents/
│   │   ├── reasoning/
│   │   ├── research/
│   │   └── automation/
│   ├── voice/
│   ├── vision/         # New capability
│   ├── nlp/            # New capability
│   └── utilities/
├── libs/
│   ├── python/
│   ├── go/
│   └── shared/         # Cross-language contracts
└── apps/               # New tier for client applications
    ├── web/
    └── cli/
```

---

## Capacity Planning

### Resource Estimates per Service Type

| Service Type | CPU | Memory | Storage |
|--------------|-----|--------|---------|
| Core Infrastructure | 0.5-2 | 512MB-4GB | 1-100GB |
| Plugin Service | 0.25-1 | 256MB-2GB | 100MB-10GB |
| AI Agent (CPU) | 1-4 | 2-8GB | 1-10GB |
| AI Agent (GPU) | 2-8 | 8-32GB | 10-100GB |
| Utility Service | 0.1-0.5 | 128MB-512MB | 100MB-1GB |

### Scaling Recommendations

**Horizontal Scaling** (Add instances):
- Stateless services (agents, utilities)
- Read-heavy workloads
- Event processors

**Vertical Scaling** (Bigger instances):
- Databases (PostgreSQL)
- In-memory stores (Redis)
- GPU workloads

**Partitioning** (Split data/workload):
- Multi-tenant scenarios
- Geographic distribution
- Workload isolation

---

## Migration Procedures

### Adding a New Subcategory

1. **Plan**:
   ```bash
   # Create migration plan
   cat > docs/migrations/add-agents-subcategory.md << 'EOF'
   # Migration: Add agents/ subcategory

   ## Services to Move
   - arc-sherlock-brain → services/agents/
   - arc-watson-research → services/agents/

   ## Steps
   1. Create services/agents/ directory
   2. Move services
   3. Update SERVICE.MD
   4. Update Docker Compose references
   5. Run validation
   EOF
   ```

2. **Execute**:
   ```bash
   mkdir -p services/agents
   git mv services/arc-sherlock-brain services/agents/
   git mv services/arc-watson-research services/agents/
   ```

3. **Validate**:
   ```bash
   ./scripts/validate/validate-all.sh
   ```

4. **Update Documentation**:
   - SERVICE.MD
   - Docker Compose files
   - CI/CD workflows

### Splitting a Service

1. **Identify boundaries**:
   - Clear responsibility separation
   - API contract between parts
   - Independent deployability

2. **Create new service**:
   ```bash
   ./scripts/create-service.sh \
     --name arc-new-service \
     --tier services \
     --lang python \
     --from arc-original-service
   ```

3. **Migrate code**:
   - Extract relevant code
   - Define API contract
   - Update dependencies

4. **Deploy and validate**:
   - Deploy side-by-side
   - Verify functionality
   - Switch traffic
   - Remove old code

---

## Anti-Patterns

### ❌ Premature Optimization

**Bad**: Creating deep directory structures before needed
```
services/
└── agents/
    └── reasoning/
        └── language/
            └── arc-sherlock-brain/  # 4 levels deep!
```

**Good**: Keep flat until complexity requires structure
```
services/
└── arc-sherlock-brain/  # 1 level, simple
```

### ❌ Inconsistent Grouping

**Bad**: Mixed grouping strategies
```
services/
├── agents/           # By function
├── python/           # By language (wrong!)
├── arc-piper-tts/    # Ungrouped
└── experimental/     # By maturity (wrong!)
```

**Good**: Consistent grouping by function
```
services/
├── agents/
├── voice/
└── utilities/
```

### ❌ Over-Splitting

**Bad**: Separate service for every small function
```
services/
├── arc-tokenizer/      # 50 lines
├── arc-embedder/       # 100 lines
├── arc-ranker/         # 75 lines
└── arc-formatter/      # 30 lines
```

**Good**: Cohesive services with clear responsibility
```
services/
└── arc-nlp-pipeline/   # Contains tokenizer, embedder, ranker, formatter
```

---

## Decision Log

Record significant scaling decisions:

| Date | Decision | Rationale | ADR |
|------|----------|-----------|-----|
| 2026-01 | Three-tier structure | Clear separation of concerns | ADR-002 |
| TBD | Add agents/ subcategory | >5 AI agents expected | ADR-XXX |
| TBD | GPU variant strategy | ML workload requirements | ADR-XXX |

---

## Related Documentation

- [Service Categorization](./SERVICE-CATEGORIZATION.md) - Where services go
- [Directory Design](./DIRECTORY-DESIGN.md) - Current structure
- [ADR-002: Three-Tier Structure](./adr/002-three-tier-structure.md) - Design rationale
