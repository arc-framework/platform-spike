# GitHub Copilot Instructions

Custom instructions for GitHub Copilot to better understand the A.R.C. Framework platform architecture and conventions.

---

## Project Context

This is the **A.R.C. (Agentic Reasoning Core) Framework Platform Spike** - a production-ready platform demonstrating:

1. **End-to-end observability** using OpenTelemetry, Prometheus, Loki, Jaeger, and Grafana
2. **Production infrastructure** including Postgres, Redis, NATS, Pulsar, Traefik, Kratos, Unleash, and Infisical
3. **Enterprise service orchestration** using Make, Docker Compose, and modular configuration

---

## Architecture Principles

### Three-Layer Architecture

1. **Core Services** (`core/`) - Essential infrastructure (persistence, messaging, caching, gateway, telemetry)
2. **Plugins** (`plugins/`) - Swappable components (observability, security, search, storage)
3. **Services** (`services/`) - Application services (platform services, utilities, agents)

### Swappable Components

All infrastructure components follow a **swappable design**:
- Each component has alternatives documented
- Configuration is isolated and portable
- Services communicate through standard protocols

---

## Code Conventions

### Directory Structure

```
component-category/
├── README.md           # Overview and alternatives
└── implementation/
    ├── README.md       # Implementation-specific docs
    ├── .env.example    # Configuration template
    └── config files
```

### Naming Conventions

See [`docs/guides/NAMING-CONVENTIONS.md`](../docs/guides/NAMING-CONVENTIONS.md) for details:

- **Directories**: `lowercase-with-hyphens`
- **Files**: `lowercase-with-hyphens.ext` or `UPPERCASE-FOR-DOCS.md`
- **Docker services**: `lowercase-with-hyphens`
- **Make targets**: `lowercase-with-hyphens`

### Documentation Standards

- Every directory has a `README.md`
- READMEs include: Overview, Usage, Configuration, Troubleshooting
- Use status indicators: ✅ Active, 🚧 WIP, 📋 Planned, ⚠️ Deprecated
- Link to related documentation

---

## Technology Stack

### Languages
- **Go** - Primary language for services and utilities
- **Shell** - Automation scripts

### Infrastructure
- **Docker** & **Docker Compose** - Container orchestration
- **Make** - Service lifecycle management
- **OpenTelemetry** - Telemetry collection and export

### Core Services
- **Postgres** (with pgvector) - Primary data store
- **Redis** - Caching and session management
- **NATS** - Ephemeral messaging
- **Pulsar** - Durable event streaming
- **Traefik** - API gateway

### Observability Stack
- **Loki** - Log aggregation
- **Prometheus** - Metrics collection
- **Jaeger** - Distributed tracing
- **Grafana** - Unified visualization

### Security & Operations
- **Kratos** - Identity and authentication
- **Unleash** - Feature flags
- **Infisical** - Secrets management

---

## Development Guidelines

### When Adding New Components

1. Create appropriate directory structure
2. Add comprehensive README.md with status indicator
3. Include `.env.example` for configuration
4. Add Make targets for lifecycle management
5. Document in parent README.md
6. Add health checks where applicable

### When Writing Code

- Use OpenTelemetry SDK for instrumentation
- Follow 12-factor app principles
- Externalize configuration via environment variables
- Include health check endpoints
- Add structured logging
- Emit metrics and traces

### When Creating Documentation

- Start with clear overview and status
- Document prerequisites and configuration
- Include usage examples
- Add troubleshooting section
- Link to related documentation
- Keep formatting consistent

---

## Common Tasks

### Service Management
```bash
make up              # Start all services
make down            # Stop all services
make health-all      # Check health status
make logs            # View service logs
```

### Configuration
```bash
make .env            # Initialize all .env files
```

### Diagnostics
```bash
make ps              # List running containers
make info            # Show service URLs and credentials
```

---

## Helpful Context

- **Main entry point**: Root `Makefile`
- **Operations guide**: `docs/OPERATIONS.md`
- **Architecture docs**: `docs/architecture/README.md`
- **Service management**: `scripts/` directory
- **Analysis reports**: `reports/` directory

---

## When Assisting With This Project

1. **Maintain consistency** with existing patterns and conventions
2. **Use swappable design** - avoid hard dependencies
3. **Document thoroughly** - READMEs, comments, examples
4. **Follow the architecture** - respect the three-layer model
5. **Test integration** - ensure services work together
6. **Consider observability** - add telemetry to new services
7. **Think production-ready** - include health checks, error handling, logging

---

## Questions to Ask

Before implementing features, consider:
- Is this a core service, plugin, or application service?
- Can this be swapped with alternatives?
- How will this integrate with the observability stack?
- What configuration does this need?
- How will users manage this service?
- What documentation is needed?

---

## Status: November 9, 2025

This is an active development platform spike demonstrating enterprise-grade infrastructure for AI agent systems.

