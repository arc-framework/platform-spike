# A.R.C. Platform Directory Structure

**Last Updated:** January 2026
**Version:** 1.0
**Spec Reference:** `specs/002-stabilize-framework`

---

## Overview

The A.R.C. Framework follows a **three-tier architecture** that separates concerns by criticality and replaceability:

| Tier | Directory | Purpose | Startup Required |
|------|-----------|---------|------------------|
| **Core** | `core/` | Essential infrastructure (platform fails without these) | Yes |
| **Plugins** | `plugins/` | Optional/swappable infrastructure (monitoring, auth, storage) | No |
| **Services** | `services/` | Application logic (AI agents, workers, utilities) | No |

---

## Complete Directory Layout

```
platform-spike/
│
├── core/                           # ESSENTIAL infrastructure
│   ├── README.md                   # Core services overview
│   ├── gateway/                    # API Gateway
│   │   └── traefik/               # Heimdall - traffic routing
│   │       ├── Dockerfile
│   │       ├── traefik.yml        # Static configuration
│   │       └── dynamic/           # Dynamic routing rules
│   │
│   ├── persistence/                # Data storage
│   │   └── postgres/              # Oracle - primary database
│   │       ├── Dockerfile
│   │       ├── init.sql           # Schema initialization
│   │       └── migrations/        # Database migrations
│   │
│   ├── caching/                    # Working memory
│   │   └── redis/                 # Sonic - cache layer
│   │       ├── Dockerfile
│   │       └── redis.conf         # Configuration
│   │
│   ├── messaging/                  # Communication layer
│   │   ├── ephemeral/             # Real-time messaging
│   │   │   └── nats/             # Flash - pub/sub
│   │   │       ├── Dockerfile
│   │   │       └── nats.conf
│   │   └── durable/               # Event streaming
│   │       └── pulsar/           # Strange - event sourcing
│   │           ├── Dockerfile
│   │           └── standalone.conf
│   │
│   ├── telemetry/                  # Observability pipeline
│   │   └── otel/                  # Widow - collector
│   │       ├── Dockerfile
│   │       └── otel-config.yaml
│   │
│   └── secrets/                    # Secrets management
│       └── infisical/             # Fury - vault
│           └── Dockerfile
│
├── plugins/                        # OPTIONAL infrastructure
│   ├── README.md                   # Plugin services overview
│   │
│   ├── observability/              # Monitoring stack
│   │   ├── logging/               # Log aggregation
│   │   │   └── loki/             # Watson - log storage
│   │   │       └── Dockerfile
│   │   ├── metrics/               # Metrics collection
│   │   │   └── prometheus/       # House - time-series
│   │   │       └── Dockerfile
│   │   ├── tracing/               # Distributed tracing
│   │   │   └── jaeger/           # Columbo - traces
│   │   │       └── Dockerfile
│   │   └── visualization/         # Dashboards
│   │       └── grafana/          # Friday - UI
│   │           └── Dockerfile
│   │
│   ├── security/                   # Authentication/authorization
│   │   └── kratos/                # Jarvis - identity
│   │       └── Dockerfile
│   │
│   └── storage/                    # Object storage
│       └── minio/                 # Tardis - S3 compatible
│           └── Dockerfile
│
├── services/                       # APPLICATION logic
│   ├── README.md                   # Services overview
│   │
│   ├── arc-sherlock-brain/        # Sherlock - reasoning engine
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── README.md
│   │   └── src/
│   │       ├── __init__.py
│   │       └── main.py
│   │
│   ├── arc-scarlett-voice/        # Scarlett - voice agent
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── README.md
│   │   └── src/
│   │       └── agent.py
│   │
│   ├── arc-piper-tts/             # Piper - text-to-speech
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── README.md
│   │   └── src/
│   │       └── main.py
│   │
│   └── utilities/                  # Support services
│       └── raymond/               # Raymond - bootstrap
│           ├── Dockerfile
│           ├── go.mod
│           ├── README.md
│           └── cmd/
│               └── raymond/
│                   └── main.go
│
├── .docker/                        # Shared Docker assets
│   └── base/                      # Base images
│       ├── python-ai/             # Python AI services base
│       │   ├── Dockerfile
│       │   └── README.md
│       └── go-infra/              # Go services base
│           ├── Dockerfile
│           └── README.md
│
├── deployments/                    # Deployment configurations
│   ├── docker/                    # Docker Compose files
│   │   ├── docker-compose.core.yml
│   │   ├── docker-compose.plugins.yml
│   │   ├── docker-compose.services.yml
│   │   └── docker-compose.dev.yml
│   ├── kubernetes/                # K8s manifests (future)
│   └── terraform/                 # IaC (future)
│
├── scripts/                        # Operational scripts
│   ├── validate/                  # Validation tools
│   │   ├── README.md
│   │   ├── docker-lint.sh
│   │   ├── docker-build-test.sh
│   │   └── all-services.sh
│   ├── generate-pr-description.sh
│   └── generate-task-commit.sh
│
├── docs/                           # Documentation
│   ├── architecture/              # Architecture docs
│   │   ├── README.md              # Main architecture doc
│   │   ├── directory-structure.md # This file
│   │   ├── nats-subjects.md       # NATS subject conventions
│   │   └── pulsar-topics.md       # Pulsar topic design
│   ├── guides/                    # How-to guides
│   └── reference/                 # Reference docs
│
├── specs/                          # Feature specifications
│   ├── 001-realtime-media/        # Completed spec
│   └── 002-stabilize-framework/   # Current spec
│       ├── spec.md                # Specification
│       ├── plan.md                # Implementation plan
│       ├── tasks.md               # Task tracking
│       └── commits.md             # Commit history
│
├── libs/                           # Shared libraries (future)
│   ├── arc-sdk-go/
│   ├── arc-sdk-python/
│   └── arc-sdk-typescript/
│
├── config/                         # Global configurations
├── tests/                          # Test suites
│
├── Makefile                        # Build/deployment commands
├── SERVICE.MD                      # Service registry & codenames
└── README.md                       # Project overview
```

---

## Tier Decision Tree

Use this flowchart to determine where a new component belongs:

```
Is this service required for the platform to start?
├── YES → Is it infrastructure (not business logic)?
│         ├── YES → core/
│         └── NO  → Reconsider - core is for infrastructure only
└── NO  → Is it infrastructure (monitoring, auth, storage)?
          ├── YES → plugins/
          └── NO  → Is it a library (no runtime)?
                    ├── YES → libs/
                    └── NO  → services/
```

---

## Quick Reference

| If your component is... | Put it in... | Example |
|-------------------------|--------------|---------|
| Required to boot the platform | `core/` | Postgres, Redis, NATS |
| Optional infrastructure | `plugins/` | Grafana, Jaeger, Kratos |
| AI agent or reasoning engine | `services/` | arc-sherlock-brain |
| Business logic worker | `services/` | arc-ramsay-critic |
| Shared library (not a service) | `libs/` | Common utilities |
| Docker base image | `.docker/base/` | python-ai, go-infra |
| Deployment config | `deployments/` | Compose, K8s, Terraform |
| Validation script | `scripts/validate/` | docker-lint.sh |

---

## Naming Conventions

### Service Directories

Application services follow the pattern: `arc-{codename}-{function}`

| Component | Description | Example |
|-----------|-------------|---------|
| `arc-` | Framework prefix | `arc-` |
| `codename` | Marvel/Hollywood inspired | `sherlock`, `scarlett` |
| `function` | What it does | `brain`, `voice`, `tts` |

**Examples:**
- `arc-sherlock-brain` - Reasoning engine
- `arc-scarlett-voice` - Voice agent
- `arc-piper-tts` - Text-to-speech

### Infrastructure Directories

Infrastructure follows functional naming:
- `gateway/traefik/` - API gateway using Traefik
- `persistence/postgres/` - Data persistence using PostgreSQL
- `messaging/ephemeral/nats/` - Ephemeral messaging using NATS

---

## Related Documentation

- **[SERVICE.MD](../../SERVICE.MD)** - Service registry with codenames
- **[Architecture README](./README.md)** - Architecture overview
- **[Docker Standards](../standards/docker-standards.md)** - Dockerfile requirements
- **[services/README.md](../../services/README.md)** - Application services guide
- **[core/README.md](../../core/README.md)** - Core infrastructure guide
- **[plugins/README.md](../../plugins/README.md)** - Plugin components guide
