# CI/CD Architecture

This document describes the architecture of the A.R.C. CI/CD system, including workflow organization, execution flows, and design decisions.

## Table of Contents

- [System Overview](#system-overview)
- [Layered Architecture](#layered-architecture)
- [Workflow Catalog](#workflow-catalog)
- [Execution Flows](#execution-flows)
- [Component Diagrams](#component-diagrams)
- [Design Decisions](#design-decisions)

---

## System Overview

The A.R.C. CI/CD system is built on GitHub Actions and follows enterprise patterns for scalability, maintainability, and cost efficiency.

### Key Characteristics

| Characteristic | Implementation |
|----------------|----------------|
| **Layered Design** | 3-tier: Orchestration → Reusable → Composite |
| **Configuration-Driven** | JSON configs for services, caching, publishing |
| **Multi-Architecture** | linux/amd64 and linux/arm64 support |
| **Security-First** | SBOM, CVE scanning, license compliance |
| **Cost-Aware** | Monitoring, alerts, cache optimization |

### Goals

1. **Fast Feedback**: PR checks complete in <3 minutes
2. **Reliable Publishing**: Automated with rollback capability
3. **Security Compliance**: SBOM + vulnerability scanning on every build
4. **Cost Control**: Stay within GitHub Actions free tier

---

## Layered Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TRIGGER CONTEXTS                                   │
│  Pull Request │ Push to Main │ Git Tag │ Schedule │ Manual (workflow_dispatch)│
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ORCHESTRATION WORKFLOWS                              │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │  pr-checks   │  │ main-deploy  │  │   release    │  │ scheduled-maint  │ │
│  │     .yml     │  │    .yml      │  │    .yml      │  │      .yml        │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘ │
│         │                 │                 │                    │           │
│         │    Entry points, trigger handling, job coordination    │           │
└─────────┼─────────────────┼─────────────────┼────────────────────┼───────────┘
          │                 │                 │                    │
          ▼                 ▼                 ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          REUSABLE WORKFLOWS                                  │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐           │
│  │ _reusable-       │  │ _reusable-       │  │ _reusable-       │           │
│  │   validate.yml   │  │   build.yml      │  │   security.yml   │           │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘           │
│           │                     │                     │                      │
│           │    Shared logic, consistent patterns, parameterized             │
└───────────┼─────────────────────┼─────────────────────┼──────────────────────┘
            │                     │                     │
            ▼                     ▼                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          COMPOSITE ACTIONS                                   │
│                                                                              │
│  ┌───────────┐  ┌────────────────┐  ┌─────────────────┐  ┌───────────────┐  │
│  │ arc-setup │  │arc-docker-build│  │arc-security-scan│  │arc-job-summary│  │
│  └───────────┘  └────────────────┘  └─────────────────┘  └───────────────┘  │
│                                                                              │
│                 Atomic operations, tool setup, reusable steps                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Layer Details

#### Orchestration Layer

**Purpose**: Entry points that respond to GitHub events and coordinate jobs.

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `pr-checks.yml` | `pull_request` | Fast PR validation |
| `main-deploy.yml` | `push` to main | Deploy to registry |
| `release.yml` | `v*` tags | Staged release pipeline |
| `scheduled-maintenance.yml` | `cron` | Daily security scans |
| `publish-vendor-images.yml` | `cron` weekly | Vendor image updates |
| `cost-monitoring.yml` | `cron` daily | Cost tracking |
| `cache-management.yml` | `cron` weekly | Cache cleanup |

#### Reusable Layer

**Purpose**: Shared workflow logic that can be called with parameters.

| Workflow | Inputs | Purpose |
|----------|--------|---------|
| `_reusable-validate.yml` | service, dockerfile_path | Lint and validate |
| `_reusable-build.yml` | service, platforms, push | Build Docker images |
| `_reusable-security.yml` | image, severity | Security scanning |
| `_reusable-publish-group.yml` | config_file, group_name | Batch publishing |

#### Composite Actions Layer

**Purpose**: Atomic, reusable steps for common operations.

| Action | Purpose | Key Inputs |
|--------|---------|------------|
| `arc-setup` | Environment setup | go-version, node-version |
| `arc-docker-build` | Build with caching | context, platforms, push |
| `arc-security-scan` | Trivy scanning | image, severity |
| `arc-job-summary` | Generate summaries | type, status, metrics |

---

## Workflow Catalog

### PR Validation Flow

```
pr-checks.yml
     │
     ├─► validate (parallel)
     │      ├── Dockerfile lint (hadolint)
     │      ├── YAML lint (yamllint)
     │      ├── Shell lint (shellcheck)
     │      └── Python lint (ruff)
     │
     ├─► build-matrix
     │      └── Generate service matrix from SERVICE.MD
     │
     ├─► build (matrix: services)
     │      ├── Setup QEMU + Buildx
     │      ├── Build multi-arch image
     │      ├── Run tests in container
     │      └── Generate SBOM
     │
     ├─► security-scan (matrix: services)
     │      ├── Trivy vulnerability scan
     │      ├── Gitleaks secret scan
     │      └── License check
     │
     └─► summary
            └── Generate job summary with metrics
```

### Main Branch Deploy Flow

```
main-deploy.yml
     │
     ├─► validate
     │      └── Same as PR validation
     │
     ├─► build-and-push (matrix: services)
     │      ├── Build multi-arch image
     │      ├── Push to GHCR
     │      ├── Generate SBOM
     │      └── Attest provenance
     │
     ├─► security-scan
     │      ├── Full Trivy scan
     │      ├── Upload to dependency graph
     │      └── Create CVE issues if needed
     │
     └─► notify
            └── Post deployment summary
```

### Release Pipeline Flow

```
release.yml (v* tag)
     │
     ├─► validate-version
     │      └── Semantic version check
     │
     ├─► build
     │      └── Build all services
     │
     ├─► security-gate
     │      └── Block on Critical/High CVEs
     │
     ├─► deploy-staging
     │      ├── Deploy to staging namespace
     │      └── Run smoke tests
     │
     ├─► approval (manual)
     │      └── Require maintainer approval
     │
     ├─► deploy-production
     │      ├── Deploy to production namespace
     │      └── Run smoke tests
     │
     ├─► create-release
     │      └── GitHub release with artifacts
     │
     └─► rollback (on failure)
            └── Restore previous version
```

### Vendor Image Publishing Flow

```
publish-vendor-images.yml (weekly)
     │
     ├─► gateway-images
     │      ├── traefik
     │      ├── kratos
     │      ├── unleash
     │      └── infisical
     │
     ├─► data-images (depends: gateway)
     │      ├── postgres
     │      ├── redis
     │      ├── qdrant
     │      ├── minio
     │      └── clickhouse
     │
     ├─► communication-images (depends: gateway)
     │      ├── nats
     │      ├── pulsar
     │      └── livekit
     │
     ├─► observability-images (depends: data, comm)
     │      ├── prometheus
     │      ├── grafana
     │      ├── loki
     │      ├── tempo
     │      ├── jaeger
     │      └── alertmanager
     │
     └─► tools-images (depends: data, comm)
            ├── otel-collector
            ├── curl
            ├── busybox
            ├── chaos-mesh
            └── pgadmin
```

---

## Execution Flows

### PR Check Timeline

```
0s    ─────┬───────────────────────────────────────────────► ~180s
           │
      ┌────┴────┐
      │ Trigger │ PR opened/synchronized
      └────┬────┘
           │
      ┌────┴─────────────────────────────────────────┐
      │              PARALLEL VALIDATION              │
      │  lint ─────────────────────────► 20s         │
      │  structure ────────────────────► 15s         │
      │  matrix-gen ───────────────────► 5s          │
      └────┬─────────────────────────────────────────┘
           │                              ~25s
      ┌────┴─────────────────────────────────────────┐
      │              PARALLEL BUILD                   │
      │  service-a (amd64) ────────────► 60s         │
      │  service-a (arm64) ────────────► 75s         │
      │  service-b (amd64) ────────────► 45s         │
      │  service-b (arm64) ────────────► 55s         │
      └────┬─────────────────────────────────────────┘
           │                              ~100s
      ┌────┴─────────────────────────────────────────┐
      │              PARALLEL SECURITY                │
      │  trivy-scan ───────────────────► 30s         │
      │  gitleaks ─────────────────────► 10s         │
      │  license-check ────────────────► 15s         │
      └────┬─────────────────────────────────────────┘
           │                              ~130s
      ┌────┴────┐
      │ Summary │ Generate job summary
      └────┬────┘
           │                              ~180s
           ▼
      ✅ Complete
```

### Cache Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      CACHE RESTORE                           │
│                                                              │
│   Key: go-mod-Linux-abc123def456...                         │
│   ┌─────────────┐                                           │
│   │ Try exact   │──► Hit? ──► Use cache ──► Done           │
│   │    match    │                                           │
│   └──────┬──────┘                                           │
│          │ Miss                                              │
│          ▼                                                   │
│   ┌─────────────┐                                           │
│   │ Try restore │──► Hit? ──► Use partial ──► Update deps  │
│   │    keys     │              cache                        │
│   └──────┬──────┘                                           │
│          │ Miss                                              │
│          ▼                                                   │
│   ┌─────────────┐                                           │
│   │ Cold start  │──► Download all deps ──► Save new cache  │
│   └─────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Diagrams

### Docker Build Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     DOCKER BUILD PIPELINE                        │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   Source     │    │   BuildKit   │    │   Registry   │       │
│  │   Context    │───►│   Builder    │───►│   (GHCR)     │       │
│  └──────────────┘    └──────┬───────┘    └──────────────┘       │
│                             │                                    │
│                      ┌──────┴──────┐                            │
│                      │             │                            │
│                      ▼             ▼                            │
│               ┌───────────┐ ┌───────────┐                       │
│               │linux/amd64│ │linux/arm64│                       │
│               └─────┬─────┘ └─────┬─────┘                       │
│                     │             │                              │
│                     └──────┬──────┘                             │
│                            ▼                                     │
│                    ┌───────────────┐                            │
│                    │ Multi-arch    │                            │
│                    │ Manifest      │                            │
│                    └───────┬───────┘                            │
│                            │                                     │
│                            ▼                                     │
│  Tags: ghcr.io/arc-framework/{service}:{version}                │
│        ghcr.io/arc-framework/{service}:sha-{short}              │
│        ghcr.io/arc-framework/{service}:latest                   │
└─────────────────────────────────────────────────────────────────┘
```

### Security Scanning Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     SECURITY SCANNING                            │
│                                                                  │
│  ┌─────────────┐                                                │
│  │ Docker      │                                                │
│  │ Image       │                                                │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    PARALLEL SCANS                        │    │
│  │                                                          │    │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐           │    │
│  │  │  Trivy    │  │  Syft     │  │ Gitleaks  │           │    │
│  │  │  (CVEs)   │  │  (SBOM)   │  │ (Secrets) │           │    │
│  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘           │    │
│  │        │              │              │                  │    │
│  └────────┼──────────────┼──────────────┼──────────────────┘    │
│           │              │              │                        │
│           ▼              ▼              ▼                        │
│  ┌─────────────┐  ┌───────────┐  ┌───────────┐                  │
│  │ SARIF       │  │ SPDX/     │  │ Findings  │                  │
│  │ Report      │  │ CycloneDX │  │ Report    │                  │
│  └──────┬──────┘  └─────┬─────┘  └─────┬─────┘                  │
│         │               │              │                         │
│         ▼               ▼              ▼                         │
│  ┌───────────────────────────────────────────┐                  │
│  │         GitHub Security Tab               │                  │
│  │  - Code scanning alerts                   │                  │
│  │  - Dependency graph                       │                  │
│  │  - Secret scanning                        │                  │
│  └───────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

### Cost Monitoring System

```
┌─────────────────────────────────────────────────────────────────┐
│                     COST MONITORING                              │
│                                                                  │
│  ┌─────────────┐                                                │
│  │ GitHub      │                                                │
│  │ Actions API │                                                │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────────┐                                            │
│  │ calculate-      │                                            │
│  │ costs.py        │                                            │
│  └────────┬────────┘                                            │
│           │                                                      │
│           ▼                                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    COST ANALYSIS                         │    │
│  │                                                          │    │
│  │  Linux:    xxx min × $0.008 = $x.xx                     │    │
│  │  Windows:  xxx min × $0.016 = $x.xx                     │    │
│  │  macOS:    xxx min × $0.080 = $x.xx                     │    │
│  │  ─────────────────────────────────                      │    │
│  │  Total:    xxxx min           $xx.xx                    │    │
│  │  Free Tier: xx.x% used (xxxx / 2000)                    │    │
│  │                                                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│           │                                                      │
│           ▼                                                      │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │ generate-       │    │ Threshold       │                     │
│  │ cost-report.py  │    │ Check           │                     │
│  └────────┬────────┘    └────────┬────────┘                     │
│           │                      │                               │
│           ▼                      ▼                               │
│  ┌─────────────┐         ┌─────────────┐                        │
│  │ Reports     │         │ Alert       │                        │
│  │ (MD/HTML)   │         │ Issue       │                        │
│  └─────────────┘         └─────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Design Decisions

### ADR-001: Layered Workflow Architecture

**Context**: Need maintainable, reusable CI/CD workflows.

**Decision**: Adopt 3-tier architecture (Orchestration → Reusable → Composite).

**Rationale**:
- Orchestration layer handles triggers and coordination
- Reusable layer enables DRY principles across workflows
- Composite actions provide atomic, testable units

### ADR-002: Configuration-Driven Service Discovery

**Context**: Services change frequently; hardcoding is error-prone.

**Decision**: Use `SERVICE.MD` as source of truth with matrix generation.

**Rationale**:
- Single location for service metadata
- Automatic CI/CD pickup for new services
- Human-readable documentation doubles as config

### ADR-003: Multi-Architecture by Default

**Context**: Need to support both x86 and ARM deployments.

**Decision**: Build linux/amd64 and linux/arm64 for all images.

**Rationale**:
- ARM instances are increasingly common (AWS Graviton, M1 Macs)
- BuildKit enables efficient multi-arch builds
- Single manifest simplifies deployment

### ADR-004: Security Scanning as Gate

**Context**: Security vulnerabilities must be caught before deployment.

**Decision**: Block merges on Critical/High CVEs.

**Rationale**:
- Shift-left security catches issues early
- Automated gates ensure consistent enforcement
- Allow override for known false positives via `.trivyignore`

### ADR-005: Cost-Aware Design

**Context**: GitHub Actions has 2,000 min/month free tier.

**Decision**: Implement aggressive caching, monitoring, and alerts.

**Rationale**:
- Caching can reduce build times by 50%+
- Daily monitoring catches runaway costs
- Alerts enable proactive management

---

## Related Documentation

- [CI/CD Developer Guide](../guides/CICD-DEVELOPER-GUIDE.md)
- [Docker Standards](../standards/DOCKER-STANDARDS.md)
- [Service Categorization](./SERVICE-CATEGORIZATION.md)
- [ADR: Three-Tier Structure](./adr/002-three-tier-structure.md)
