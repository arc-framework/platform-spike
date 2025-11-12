# A.R.C. Framework - Naming & Folder Conventions Guide

**Version**: 1.0  
**Date**: November 9, 2025  
**Status**: Official Standard  
**Scope**: Microservices, Docker, Infrastructure Components

---

## 📋 TABLE OF CONTENTS

1. [Directory Naming Conventions](#directory-naming-conventions)
2. [File Naming Conventions](#file-naming-conventions)
3. [Service Organization Patterns](#service-organization-patterns)
4. [Docker Conventions](#docker-conventions)
5. [Configuration Management](#configuration-management)
6. [Infrastructure Components](#infrastructure-components)
7. [Multi-Language Support](#multi-language-support)
8. [Documentation Standards](#documentation-standards)
9. [Testing Organization](#testing-organization)
10. [Examples & Templates](#examples--templates)

---

## 1. DIRECTORY NAMING CONVENTIONS

### 1.1 Universal Rules

| Rule | Pattern | Example | Rationale |
|------|---------|---------|-----------|
| **Top-level** | `lowercase` | `core/`, `plugins/`, `services/` | Universal standard, clean URLs |
| **Components** | `kebab-case` | `user-service/`, `api-gateway/` | DNS-friendly, portable, readable |
| **Categories** | `lowercase` | `observability/`, `security/` | Organizational clarity |
| **Implementations** | `kebab-case` | `traefik/`, `otel-collector/` | Consistent with product names |

**Never Use:**
- ❌ `snake_case` (Python-specific, not universal)
- ❌ `PascalCase` (Language-specific, harder to type)
- ❌ `UPPERCASE` (Reserved for constants/env vars)
- ❌ Spaces or special characters

### 1.2 Core Framework Structure

Based on your architecture decision (core/plugins pattern):

```
arc-framework/
├── core/                              # Required components (kebab-case categories)
│   ├── gateway/                       # Category: lowercase
│   │   ├── traefik/                   # Implementation: kebab-case
│   │   ├── kong/
│   │   └── envoy/
│   ├── telemetry/
│   │   └── otel-collector/
│   ├── messaging/
│   │   ├── ephemeral/                 # Sub-category: lowercase
│   │   │   ├── nats/
│   │   │   └── rabbitmq/
│   │   └── durable/
│   │       ├── pulsar/
│   │       └── kafka/
│   ├── persistence/
│   │   ├── postgres/
│   │   └── mysql/
│   ├── caching/
│   │   ├── redis/
│   │   └── valkey/
│   ├── secrets/
│   │   ├── infisical/
│   │   └── vault/
│   └── feature-management/
│       └── unleash/
│
├── plugins/                           # Optional components
│   ├── security/
│   │   ├── identity/
│   │   │   ├── kratos/
│   │   │   └── keycloak/
│   │   └── authorization/
│   │       └── opa/
│   ├── observability/
│   │   ├── logging/
│   │   │   ├── loki/
│   │   │   └── elasticsearch/
│   │   ├── metrics/
│   │   │   └── prometheus/
│   │   ├── tracing/
│   │   │   └── jaeger/
│   │   └── visualization/
│   │       └── grafana/
│   ├── storage/
│   │   ├── minio/
│   │   └── s3/
│   └── search/
│       └── elasticsearch/
```

**Pattern**: `category/[subcategory]/implementation/`

### 1.3 Services Structure

Based on your AI agent focus with hybrid organization:

```
services/
├── agents/                            # AI agent services (domain-driven)
│   ├── reasoning-agent/               # kebab-case service names
│   ├── code-agent/
│   ├── rag-agent/
│   ├── examples/                      # Example implementations
│   │   ├── simple-agent/
│   │   └── multi-agent/
│   └── templates/                     # Service templates
│       ├── python-agent/
│       └── go-agent/
│
├── platform/                          # Platform services
│   ├── user-service/
│   ├── auth-api/
│   └── gateway-service/
│
└── utilities/                         # Utility services
    ├── toolbox/                       # Current example
    └── health-checker/
```

**Service Naming Pattern**: `[domain]-[type]`
- Examples: `user-service`, `auth-api`, `reasoning-agent`, `code-agent`
- Type suffixes: `-service`, `-api`, `-agent`, `-worker`, `-job`

---

## 2. FILE NAMING CONVENTIONS

### 2.1 By File Type

| File Type | Convention | Examples | Standard Source |
|-----------|------------|----------|-----------------|
| **Docker** | `Dockerfile` (exact) | `Dockerfile`, `Dockerfile.alpine` | Docker official |
| **Docker Compose** | `docker-compose[.env].yml` | `docker-compose.yml`, `docker-compose.dev.yml` | Docker official |
| **Documentation** | `UPPERCASE.md` | `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md` | GitHub standard |
| **Configuration** | `kebab-case.yml/yaml` | `app-config.yml`, `traefik.yml` | Kubernetes/YAML standard |
| **Scripts** | `kebab-case.sh` | `deploy.sh`, `run-tests.sh` | Unix convention |
| **Environment** | `.env[.environment]` | `.env`, `.env.dev`, `.env.prod` | 12-factor app |
| **Kubernetes** | `kebab-case.yaml` | `deployment.yaml`, `service.yaml` | K8s standard |
| **Terraform** | `lowercase.tf` | `main.tf`, `variables.tf` | Terraform standard |
| **Templates** | `template-[name].md` | `template-analysis.md` | Your current standard |
| **Generated** | `YYYYMMDD-[type].md` | `20251109-analysis.md` | ISO date prefix |

### 2.2 Special Cases

#### Multi-Stage Dockerfiles
```
Dockerfile              # Default
Dockerfile.alpine       # Alpine variant
Dockerfile.debian       # Debian variant
```

#### Docker Compose Overlays
```
docker-compose.yml              # Base
docker-compose.dev.yml          # Development overlay
docker-compose.staging.yml      # Staging overlay
docker-compose.prod.yml         # Production overlay
docker-compose.override.yml     # Local overrides (gitignored)
```

#### Service-Specific Compose Files
```
docker-compose.traefik.yml
docker-compose.postgres.yml
docker-compose.nats.yml
```

---

## 3. SERVICE ORGANIZATION PATTERNS

### 3.1 Decision: Hybrid by Function (Your Architecture)

**Rationale**: AI agent framework needs functional separation

```
services/
├── agents/              # AI-specific services (core business)
├── platform/            # Platform support services
└── utilities/           # Helper/utility services
```

**Why This Works:**
- Clear separation of AI workloads from platform services
- Easy to scale agents independently
- Aligns with your "Agentic Reasoning Core" mission
- Allows different operational policies per category

### 3.2 Service Directory Structure

**Standard Service Layout:**
```
service-name/
├── README.md                   # Service documentation
├── Dockerfile                  # Container definition
├── docker-compose.[name].yml   # Service-specific compose
├── .env.example                # Environment template
├── config/                     # Configuration files
│   ├── app.yml
│   └── [environment].yml
├── src/                        # Source code
│   └── (language-specific)
├── tests/                      # Service tests
│   ├── unit/
│   └── integration/
└── docs/                       # Additional documentation
    ├── API.md
    └── DEPLOYMENT.md
```

### 3.3 Service Naming Rules

**Format**: `[domain]-[type]`

**Type Suffixes:**
- `-service` - RESTful/gRPC service (general)
- `-api` - HTTP API specifically
- `-agent` - AI agent service
- `-worker` - Background worker/job processor
- `-job` - Scheduled/batch job
- `-gateway` - API gateway/proxy

**Examples:**
```
✅ user-service         # General service
✅ auth-api             # HTTP API
✅ reasoning-agent      # AI agent
✅ email-worker         # Background worker
✅ cleanup-job          # Scheduled job
✅ api-gateway          # Gateway service

❌ UserService          # Don't use PascalCase
❌ user_service         # Don't use snake_case
❌ user-svc             # Don't abbreviate
```

---

## 4. DOCKER CONVENTIONS

### 4.1 Container Image Naming

**Format**: `[registry/][namespace/]image-name:tag`

```
Examples:
docker.io/library/nginx:latest                    # Official image
docker.io/arc-framework/reasoning-agent:v1.2.3    # Semantic version
ghcr.io/arc-framework/user-service:sha-a1b2c3d    # Git SHA
internal-registry/team/order-api:prod             # Environment tag
```

**Tag Strategy:**
```
:latest                  # ❌ Never use in production
:v1.2.3                  # ✅ Semantic version (recommended)
:sha-a1b2c3d            # ✅ Git commit SHA
:v1.2.3-sha-a1b2c3d     # ✅ Combined (best for traceability)
:dev                     # ✅ Environment marker (non-prod only)
:prod                    # ⚠️ Use with caution (prefer semver)
```

### 4.2 Dockerfile Location & Naming

**Standard Location**: Root of service directory
```
services/
└── user-service/
    ├── Dockerfile              # Standard
    ├── Dockerfile.alpine       # Variant (if needed)
    └── src/
```

**Build Context**: Always from service root
```bash
docker build -t user-service:v1.0.0 -f Dockerfile .
```

### 4.3 Docker Compose File Organization

**Your Current Pattern** (Recommended):
```
# Root level
docker-compose.yml              # Base observability stack
docker-compose.stack.yml        # Platform infrastructure overlay

# Service-specific
core/gateway/traefik/
└── docker-compose.traefik.yml

core/messaging/ephemeral/nats/
└── docker-compose.nats.yml
```

**Compose File Naming Rules:**
1. Base file: `docker-compose.yml`
2. Environment overlays: `docker-compose.[env].yml`
3. Service-specific: `docker-compose.[service].yml`
4. Local overrides: `docker-compose.override.yml` (gitignored)

---

## 5. CONFIGURATION MANAGEMENT

### 5.1 Decision: Directory-Based (Your Current Pattern)

**Rationale**: Cleaner, more scalable, better organization

```
config/
├── README.md
├── otel-collector-config.yml          # Global config at root
├── observability/                     # Category-based
│   ├── grafana/
│   │   ├── provisioning/
│   │   └── .env.example
│   ├── loki/
│   ├── prometheus/
│   │   └── prometheus.yaml
│   └── jaeger/
└── platform/                          # Category-based
    ├── postgres/
    │   ├── init.sql
    │   └── .env.example
    ├── redis/
    ├── nats/
    ├── pulsar/
    ├── kratos/
    │   ├── README.md
    │   ├── CONFIGURATION.md
    │   ├── identity.schema.json
    │   └── kratos.yml
    └── traefik/
        ├── traefik.yml
        └── .env.example
```

**Pattern**: `config/[category]/[service]/[files]`

### 5.2 Configuration File Types

| Type | Naming | Example | Use Case |
|------|--------|---------|----------|
| **App Config** | `[service].yml` | `traefik.yml`, `kratos.yml` | Main configuration |
| **Environment** | `.env.example` | `.env.example` | Environment template |
| **Secrets Template** | `.env.example` | Never `.env` in git | Secrets documentation |
| **Init Scripts** | `init.[ext]` | `init.sql` | Initialization |
| **Dynamic Config** | `dynamic-[name].yml` | `dynamic-config.yml` | Runtime config |

### 5.3 Environment-Specific Configuration

**Pattern**: Same filename, different directories OR environment suffix

**Option A: Directory-based** (for many environments)
```
config/
└── traefik/
    ├── traefik.yml                   # Base config
    ├── environments/
    │   ├── dev/
    │   │   └── traefik.yml
    │   ├── staging/
    │   │   └── traefik.yml
    │   └── prod/
    │       └── traefik.yml
```

**Option B: Suffix-based** (simpler, your current style)
```
config/
└── traefik/
    ├── traefik.yml                   # Base
    ├── traefik.dev.yml               # Dev overlay
    ├── traefik.staging.yml           # Staging overlay
    └── traefik.prod.yml              # Prod overlay
```

**Recommendation**: Use **Option B (suffix)** for simplicity, matches your Docker Compose pattern

---

## 6. INFRASTRUCTURE COMPONENTS

### 6.1 Kubernetes Resources

**File Naming**: `[resource-type]-[name].yaml`

```
k8s/
├── base/                             # Kustomize base
│   ├── deployment-user-service.yaml
│   ├── service-user-api.yaml
│   ├── configmap-app-config.yaml
│   ├── secret-db-credentials.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    └── production/
```

**Resource Type Prefixes:**
- `deployment-[name].yaml`
- `service-[name].yaml`
- `configmap-[name].yaml`
- `secret-[name].yaml`
- `ingress-[name].yaml`
- `pvc-[name].yaml`

### 6.2 Terraform Modules

**Directory Structure:**
```
deployments/terraform/
├── modules/
│   ├── vpc/                          # Module: kebab-case
│   │   ├── main.tf                   # Terraform standard
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── eks/
│   └── rds/
└── environments/
    ├── dev/
    │   ├── main.tf
    │   └── terraform.tfvars
    ├── staging/
    └── prod/
```

**Terraform File Naming**: Use Terraform standards
- `main.tf` - Primary resources
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `providers.tf` - Provider configuration
- `versions.tf` - Version constraints
- `data.tf` - Data sources

### 6.3 Helm Charts

**Chart Structure:**
```
deployments/helm/
├── arc-framework/                    # Chart name: kebab-case
│   ├── Chart.yaml                    # Metadata
│   ├── values.yaml                   # Default values
│   ├── values.dev.yaml               # Environment-specific
│   ├── values.prod.yaml
│   ├── templates/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── _helpers.tpl
│   └── charts/                       # Sub-charts
└── reasoning-agent/
    └── (same structure)
```

---

## 7. MULTI-LANGUAGE SUPPORT

### 7.1 Decision: Hybrid by Function (Your Architecture)

**Current Pattern:**
```
services/
├── agents/                    # Language-agnostic (mixed)
│   ├── reasoning-agent/       # Python (LangGraph)
│   ├── code-agent/            # TypeScript
│   └── rag-agent/             # Python
├── platform/
│   ├── user-service/          # Go
│   └── auth-api/              # Go
└── utilities/
    └── toolbox/               # Go (current example)
```

**Why This Works:**
- Functional grouping more important than language
- Services grouped by purpose, not implementation
- Easier for operators (don't need to know language)
- Language-specific tooling handled at CI/CD level

### 7.2 Language-Specific Files

**Go:**
```
service-name/
├── go.mod
├── go.sum
├── main.go
└── cmd/
```

**Python:**
```
service-name/
├── requirements.txt
├── pyproject.toml
├── setup.py
└── src/
    └── [package]/
```

**TypeScript/Node:**
```
service-name/
├── package.json
├── package-lock.json
├── tsconfig.json
└── src/
```

**Language Detection**: Tools should auto-detect from files (go.mod, package.json, requirements.txt)

---

## 8. DOCUMENTATION STANDARDS

### 8.1 Decision: Hybrid (Your Current Pattern)

**Framework-Level Docs** (Centralized):
```
docs/
├── README.md                         # Documentation index
├── QUICKSTART.md                     # Framework quick start
├── OPERATIONS.md                     # Operations guide
├── architecture/
│   ├── README.md
│   ├── OVERVIEW.md
│   ├── CORE-SERVICES.md
│   ├── PLUGIN-SYSTEM.md
│   ├── QUICK-REFERENCE.md
│   └── RESTRUCTURING-SUMMARY.md
├── guides/
│   ├── INSTALLATION.md
│   ├── CONFIGURATION.md
│   ├── DEPLOYMENT.md
│   └── PLUGIN-DEVELOPMENT.md
└── reference/
    ├── API.md
    ├── CLI.md
    └── ENVIRONMENT-VARIABLES.md
```

**Service-Level Docs** (Co-located):
```
services/
└── reasoning-agent/
    ├── README.md                     # Service overview
    ├── CHANGELOG.md                  # Version history
    └── docs/
        ├── API.md                    # API documentation
        ├── DEPLOYMENT.md             # Deploy guide
        └── ARCHITECTURE.md           # Service architecture
```

### 8.2 Documentation File Naming

| File | Purpose | Required | Location |
|------|---------|----------|----------|
| `README.md` | Overview, quick start | ✅ YES | Every directory |
| `CHANGELOG.md` | Version history | For services | Service root |
| `CONTRIBUTING.md` | Contribution guide | Framework | Root |
| `LICENSE` | License file | Framework | Root |
| `API.md` | API reference | If applicable | service/docs/ |
| `DEPLOYMENT.md` | Deployment guide | For services | service/docs/ |
| `CONFIGURATION.md` | Config reference | For complex config | config/[service]/ |
| `ARCHITECTURE.md` | Design decisions | Framework/service | docs/ or service/docs/ |

**Naming Rules:**
- Important docs: `UPPERCASE.md` (README, CHANGELOG, CONTRIBUTING, LICENSE)
- Technical docs: `UPPERCASE.md` (API, DEPLOYMENT, CONFIGURATION)
- Guides: `lowercase-with-dashes.md` or `UPPERCASE.md` (your choice)
- Current pattern: `UPPERCASE.md` for all important docs ✅

---

## 9. TESTING ORGANIZATION

### 9.1 Decision: Hybrid (Framework + Service Tests)

**Framework-Level Tests** (Integration & E2E):
```
tests/
├── README.md
├── integration/                      # Framework integration tests
│   ├── core/
│   │   ├── test-gateway.sh
│   │   └── test-messaging.sh
│   └── plugins/
│       └── test-observability.sh
├── e2e/                              # End-to-end tests
│   ├── test-agent-workflow.sh
│   └── test-platform-health.sh
├── performance/
│   ├── load-tests/
│   └── benchmarks/
└── fixtures/
    └── test-data/
```

**Service-Level Tests** (Unit & Component):
```
services/
└── reasoning-agent/
    ├── src/
    └── tests/
        ├── unit/                     # Unit tests
        ├── integration/              # Service integration tests
        └── fixtures/                 # Test fixtures
```

### 9.2 Test File Naming

**Pattern**: `test-[what].ext` or `[what].test.ext` (language-specific)

**Examples:**
```
Go:          user_service_test.go
Python:      test_reasoning_agent.py
TypeScript:  agent.test.ts
Shell:       test-deployment.sh
```

**Test Directories:**
- `unit/` - Unit tests (fast, isolated)
- `integration/` - Integration tests (slower, external deps)
- `e2e/` - End-to-end tests (slowest, full system)
- `fixtures/` - Test data and mocks
- `performance/` - Load/stress tests

---

## 10. EXAMPLES & TEMPLATES

### 10.1 Complete Service Example

**Reasoning Agent** (Python-based AI service):
```
services/agents/reasoning-agent/
├── README.md                         # Service documentation
├── CHANGELOG.md                      # Version history
├── Dockerfile                        # Container definition
├── docker-compose.reasoning-agent.yml
├── .env.example                      # Environment template
├── .dockerignore
├── .gitignore
├── requirements.txt                  # Python dependencies
├── pyproject.toml                    # Python project config
├── config/
│   ├── agent-config.yml              # Agent configuration
│   └── llm-providers.yml             # LLM provider settings
├── src/
│   └── reasoning_agent/              # Python package (snake_case)
│       ├── __init__.py
│       ├── main.py
│       ├── agent.py
│       └── tools/
├── tests/
│   ├── unit/
│   │   └── test_agent.py
│   └── integration/
│       └── test_llm_integration.py
└── docs/
    ├── API.md
    ├── DEPLOYMENT.md
    └── ARCHITECTURE.md
```

### 10.2 Core Component Example

**Traefik Gateway**:
```
core/gateway/traefik/
├── README.md                         # Setup and usage
├── Dockerfile                        # Custom image (if needed)
├── docker-compose.traefik.yml        # Standalone compose
├── .env.example                      # Environment variables
├── config/
│   ├── traefik.yml                   # Static configuration
│   ├── dynamic-config.yml            # Dynamic configuration
│   ├── traefik.dev.yml               # Dev overrides
│   └── traefik.prod.yml              # Prod overrides
└── certs/                            # SSL certificates (gitignored)
```

### 10.3 Plugin Example

**Loki Logging Plugin**:
```
plugins/observability/logging/loki/
├── README.md                         # Plugin documentation
├── Dockerfile                        # Custom build (if needed)
├── docker-compose.loki.yml           # Plugin compose file
├── .env.example
├── config/
│   └── loki-config.yml               # Loki configuration
└── storage/                          # Data directory (gitignored)
```

---

## ✅ VALIDATION RULES

### Directory Names
```bash
# ✅ Valid
core/
plugins/
messaging/
otel-collector/
user-service/
reasoning-agent/

# ❌ Invalid
Core/                   # No PascalCase
core_components/        # No snake_case
user_service/           # No snake_case
UserService/            # No PascalCase
```

### File Names
```bash
# ✅ Valid
README.md
Dockerfile
docker-compose.yml
docker-compose.dev.yml
app-config.yml
deploy.sh
.env.example

# ❌ Invalid
readme.md               # Important docs must be UPPERCASE
Docker-Compose.yml      # Use lowercase for compose
app_config.yml          # Prefer kebab-case
deploy-script.sh        # Don't add redundant suffixes
.env                    # Never commit actual .env
```

### Service Names
```bash
# ✅ Valid
user-service
auth-api
reasoning-agent
email-worker
cleanup-job

# ❌ Invalid
UserService             # No PascalCase
user_service            # No snake_case
usersvc                 # No abbreviations
user-micro-service      # Too verbose
```

---

## 🔄 MIGRATION GUIDE

### From Current to Standard

**If you have:**
```
config/
└── platform/
    └── kratos/
        ├── README.md
        └── README-CONFIG.md        # ❌ Non-standard
```

**Migrate to:**
```
config/
└── platform/
    └── kratos/
        ├── README.md               # Overview
        └── CONFIGURATION.md        # ✅ Standard
```

**If you have:**
```
services/
└── swiss_army/                     # ❌ snake_case
```

**Migrate to:**
```
services/
└── toolbox/                        # ✅ kebab-case
```

---

## 📊 DECISION SUMMARY

Based on your architecture analysis, here are the final decisions:

| Question | Decision | Rationale |
|----------|----------|-----------|
| **Q1: Service Naming** | Domain-driven hybrid by function | AI agent focus requires functional grouping |
| **Q2: Config Files** | Directory-based | Cleaner, current pattern works well |
| **Q3: Environments** | Suffix for overlays | Matches Docker Compose pattern |
| **Q4: Multi-Language** | Hybrid by function | Purpose > language, your current pattern |
| **Q5: Documentation** | Hybrid (both) | Framework + service docs |
| **Q6: Tests** | Hybrid | Framework integration + service unit tests |

---

## 🎯 QUICK REFERENCE CHECKLIST

When creating new components:

**Directories:**
- [ ] Use `kebab-case` for all component directories
- [ ] Use `lowercase` for top-level and category directories
- [ ] Follow pattern: `category/[subcategory]/implementation/`

**Files:**
- [ ] `README.md` in every directory (UPPERCASE)
- [ ] `Dockerfile` (exact name) for containers
- [ ] `docker-compose.[name].yml` for compose files
- [ ] `.env.example` for environment templates (never `.env`)
- [ ] `kebab-case` for configs and scripts

**Services:**
- [ ] Name format: `[domain]-[type]`
- [ ] Location: `services/[category]/[service-name]/`
- [ ] Include: README, Dockerfile, config/, tests/, docs/

**Documentation:**
- [ ] `README.md` for overview (required)
- [ ] `UPPERCASE.md` for important docs
- [ ] Co-locate service docs in `service/docs/`

---

## 📚 REFERENCES

### Industry Standards Followed
- ✅ **12-Factor App** - Configuration and environment management
- ✅ **CNCF Cloud Native** - Container and Kubernetes conventions
- ✅ **Docker Official** - Dockerfile and Compose naming
- ✅ **GitHub Conventions** - README and documentation standards
- ✅ **Kubernetes Patterns** - Resource naming
- ✅ **Semantic Versioning** - Version tagging

### Internal References
- [Architecture Overview](./RESTRUCTURING-SUMMARY.md)
- [Quick Reference](./QUICK-REFERENCE.md)
- [Core Services Documentation](../../../core/)
- [Plugin System Guide](../../../plugins/)

---

**Version**: 1.0  
**Status**: ✅ Official Standard  
**Last Updated**: November 9, 2025  
**Approved**: Based on architecture analysis

---

**This is the official naming and folder convention guide for the A.R.C. Framework.**  
**All new components must follow these standards.**
