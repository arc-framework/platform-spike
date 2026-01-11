# CLAUDE.md - A.R.C. Platform-Spike Context

> **Primary context file for Claude Code interactions**

## Project Overview

**A.R.C. (Agentic Reasoning Core)** is a production-ready, "Platform-in-a-Box" distributed AI agent system. It demonstrates how to build observable, polyglot microservices with AI reasoning capabilities.

### Quick Facts

| Attribute | Value |
|-----------|-------|
| **Architecture** | Core + Plugins pattern |
| **Languages** | Go (infrastructure), Python (AI/ML), Shell (operations) |
| **Deployment** | Docker Compose with layered configuration |
| **Observability** | OpenTelemetry → Prometheus/Loki/Jaeger → Grafana |

---

## Essential Documentation

All detailed specifications live in `.specify/` (SpecKit):

| Document | Purpose | Location |
|----------|---------|----------|
| **Constitution** | Non-negotiable principles | `.specify/memory/constitution.md` |
| **Architecture** | Core patterns & ADRs | `.specify/meta/architecture-meta.md` |
| **Tech Stack** | Complete service inventory | `.specify/meta/tech-stack-registry.md` |
| **Codenames** | Service naming system | `.specify/meta/service-codename-map.md` |
| **Standards** | Go/Python/Shell coding rules | `.specify/meta/polyglot-standards.md` |
| **Integration** | Service communication patterns | `.specify/meta/integration-patterns.md` |
| **Deployment** | Profile configurations | `.specify/meta/deployment-profiles.md` |

---

## Service Codename Quick Reference

Services use superhero/sci-fi codenames for memorable identification:

| Need | Codename | Container | Port |
|------|----------|-----------|------|
| Route traffic | **Heimdall** | `arc_traefik` | 80/443 |
| Store data | **Oracle** | `arc_postgres` | 5432 |
| Cache data | **Sonic** | `arc_redis` | 6379 |
| Send messages | **The Flash** | `arc_nats` | 4222 |
| Stream events | **Dr. Strange** | `arc_pulsar` | 6650 |
| Manage secrets | **Nick Fury** | `arc_infisical` | 3001 |
| Toggle features | **Mystique** | `arc_unleash` | 4242 |
| Authenticate | **JARVIS** | `arc_kratos` | 4433 |
| View dashboards | **Friday** | `arc_grafana` | 3000 |
| Reason (AI) | **Sherlock** | `arc-sherlock-brain` | - |
| Voice (AI) | **Scarlett** | `arc-scarlett-voice` | - |

**Rule**: Use codenames in docs/communication, technical names in code.

---

## Directory Structure

```
platform-spike/
├── .specify/           # SpecKit - specifications & standards
│   ├── memory/         #   Constitution
│   ├── meta/           #   Architecture, standards, patterns
│   ├── specs/          #   Service specifications
│   ├── templates/      #   Spec/plan/task templates
│   └── scripts/        #   SpecKit automation
├── core/               # Core services (required)
│   ├── gateway/        #   Traefik (Heimdall)
│   ├── persistence/    #   PostgreSQL (Oracle), Redis (Sonic)
│   ├── messaging/      #   NATS (Flash), Pulsar (Strange)
│   ├── telemetry/      #   OTEL Collector (Black Widow)
│   └── ...
├── plugins/            # Plugin services (optional)
│   ├── observability/  #   Loki, Prometheus, Jaeger, Grafana
│   └── security/       #   Kratos, Keto
├── services/           # Application services (your code)
├── deployments/        # Docker Compose files
│   └── docker/         #   Layered compose files
├── scripts/            # Automation scripts
├── docs/               # User-facing documentation
└── specs/              # Feature specifications (active work)
```

---

## Constitutional Principles (NON-NEGOTIABLE)

These rules from `.specify/memory/constitution.md` supersede all other practices:

1. **Platform-in-a-Box**: `docker-compose up` must bootstrap a complete working platform
2. **Core + Plugins**: Core services required, plugins optional
3. **Polyglot Standards**: Go for infra, Python for AI, consistent patterns across both
4. **Test Coverage**: Critical packages 75%+, core logic 60%+, infrastructure 40%+
5. **Observability by Default**: OTEL tracing, metrics, and structured logging required
6. **Resilience Patterns**: Health checks, circuit breakers, retry with backoff, timeouts
7. **Security by Default**: Non-root containers, no secrets in logs/git, TLS in production
8. **Documentation Required**: README per service, API docs, architecture docs

---

## Common Commands

```bash
# Start platform
make up                    # Core + plugins + services
make up-minimal            # Core only

# Development
make build-all             # Build all services
make test                  # Run all tests
make lint                  # Run linters

# Health & Status
make health-all            # Check all service health
make logs SERVICE=x        # View service logs
make ps                    # Show running containers

# Docker Compose (manual)
docker compose -f deployments/docker/docker-compose.base.yml \
               -f deployments/docker/docker-compose.core.yml up
```

---

## Development Workflow

### Adding a New Feature

1. Create spec folder: `specs/NNN-feature-name/`
2. Write `spec.md` using template from `.specify/templates/spec-template.md`
3. Create `plan.md` for implementation approach
4. Break down into `tasks.md`
5. Implement following polyglot standards

### Service Development

**Go Services** (infrastructure):
- Framework: Gin for HTTP
- Testing: Standard library + table-driven tests
- Linting: golangci-lint
- OTEL: `go.opentelemetry.io/otel`

**Python Services** (AI/ML):
- Framework: FastAPI or LangGraph
- Testing: pytest with async support
- Linting: ruff, black, mypy
- Shared SDK: `libs/python-sdk/arc_common/`

---

## Health Endpoints (Required for all services)

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Shallow check - process alive |
| `GET /health/deep` | Deep check - all dependencies |
| `GET /ready` | Readiness - fully bootstrapped |

---

## Environment Variables

- Use `.env` file (gitignored) for local development
- Format: `SERVICE_SETTING_NAME` (e.g., `POSTGRES_PASSWORD`)
- Generate secrets: `make generate-secrets`
- Never commit secrets to git

---

## Current Work Context

Check these locations for active work:
- `specs/` - Active feature specifications
- `PROGRESS.md` - Implementation progress
- `CHANGELOG.md` - Recent changes
- `.github/` - CI/CD workflows

---

## SpecKit Slash Commands

Use these commands for the specification-driven workflow:

| Command | Purpose |
|---------|---------|
| `/speckit.new <description>` | Create new feature branch and spec folder |
| `/speckit.specify [details]` | Write/refine the specification |
| `/speckit.plan [focus]` | Create implementation plan |
| `/speckit.tasks [focus]` | Generate task breakdown |
| `/speckit.implement [task]` | Begin/continue implementation |
| `/speckit.analyze` | Analyze specs for gaps |
| `/speckit.status [all]` | Show feature status |
| `/speckit.context` | Load all feature context |
| `/speckit.help` | Show SpecKit help |

### Typical Workflow

```
/speckit.new "add user authentication"  # Create branch + spec folder
/speckit.specify                         # Fill out spec.md
/speckit.plan                            # Create plan.md
/speckit.tasks                           # Generate tasks.md
/speckit.implement                       # Execute tasks with TDD
```

---

## Getting Help

- **SpecKit README**: `.specify/README.md`
- **SpecKit Commands**: `/speckit.help`
- **Operations Guide**: `docs/OPERATIONS.md`
- **Main README**: `README.md`
- **Service Docs**: `services/*/README.md`

---

*Last Updated: 2026-01-11*
*SpecKit Version: 1.0.0*
