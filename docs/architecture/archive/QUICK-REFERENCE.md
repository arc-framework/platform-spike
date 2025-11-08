# A.R.C. Framework - Quick Reference

**Date**: November 9, 2025  
**Version**: 2.1

---

## ✅ Core Services (Required)

| # | Service | Why Core | Location |
|---|---------|----------|----------|
| 1 | **OpenTelemetry Collector** | Central telemetry hub | `core/telemetry/` |
| 2 | **Traefik** | API Gateway | `core/gateway/` |
| 3 | **NATS** | Agent-to-agent messaging | `core/messaging/ephemeral/` |
| 4 | **Pulsar** | Event Conveyor Belt | `core/messaging/durable/` |
| 5 | **Postgres + pgvector** | Agent state + RAG | `core/persistence/` |
| 6 | **Redis** | Cache, sessions, locks | `core/caching/` |
| 7 | **Infisical** | Secrets (LLM API keys) | `core/secrets/` |
| 8 | **Unleash** (optional) | Feature flags | `core/feature-management/` |

---

## 🔌 Pluggable Services (Optional/Swappable)

| Service | Purpose | Location |
|---------|---------|----------|
| **Kratos** | IAM (you have other plans) | `plugins/security/identity/` |
| **Loki** | Log storage backend | `plugins/observability/logging/` |
| **Prometheus** | Metrics storage backend | `plugins/observability/metrics/` |
| **Jaeger** | Trace storage backend | `plugins/observability/tracing/` |
| **Grafana** | Visualization | `plugins/observability/visualization/` |
| **MinIO/S3** | Object storage | `plugins/storage/` |
| **Elasticsearch** | Search engine | `plugins/search/` |

---

## 📋 Deployment Commands

```bash
# Minimal (development - core only)
make up profile=minimal

# With observability (staging)
make up profile=observability

# Full stack (production)
make up profile=full-stack

# Custom selection
make up plugins="postgres,redis,nats,prometheus,grafana"
```

---

## 🏗️ Directory Structure Summary

```
arc-framework/
├── core/                    # Required services (7-8)
├── plugins/                 # Optional services
├── services/agents/         # AI agent services
├── libs/                    # SDKs (Go, Python, TypeScript)
├── deployments/             # Docker, K8s, Terraform
├── config/                  # Global configs
├── scripts/                 # Automation
├── tests/                   # Testing
├── docs/                    # Documentation
└── tools/                   # Dev tools (analysis, journal, CLI)
```

---

## 🎯 Key Decisions

1. ✅ **NATS, Pulsar, Postgres = CORE** (agent needs)
2. ✅ **Kratos = PLUGIN** (you have other plans)
3. ✅ **Dynamic core** (move services as needed)
4. ✅ **Interface-based** (swappable implementations)
5. ✅ **Tools separate** (journal, analysis → tools/)

---

## 🚀 Next Actions

1. **Phase 1**: Create directory structure
2. **Phase 2**: Move existing services
3. **Phase 3**: Build first agent
4. **Phase 4**: Validate and iterate

---

**Full docs**: See `RESTRUCTURING-SUMMARY.md` and `MODULAR-DIRECTORY-STRUCTURE-V2.md`

