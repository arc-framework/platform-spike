# Service Roadmap

**Last Updated:** January 2026

This document provides a comprehensive, honest assessment of the A.R.C. platform services and the roadmap for development.

---

## Executive Summary

The A.R.C. platform has **solid infrastructure scaffolding** but most application services listed in SERVICE.MD **do not exist yet** or are **lightweight stubs**. This roadmap provides a realistic path from current state to production.

---

## Current State: Complete Inventory

### Legend
| Status | Meaning |
|--------|---------|
| ✅ Deployed | Running in Docker Compose, working |
| 🟢 Built | Code exists, needs testing |
| 🟡 Stub | Skeleton code only, not functional |
| ⚪ Planned | Listed in SERVICE.MD, no code |
| 🔵 External | Third-party service, just configuration |

---

## Core Infrastructure Services

These are **third-party services** configured in Docker Compose. They work out of the box.

| Service | Codename | Image | Status | Notes |
|---------|----------|-------|--------|-------|
| **Traefik** | Heimdall | `traefik:v3.0` | 🔵 External | API Gateway - configured |
| **PostgreSQL** | Oracle | `postgres:16-alpine` | 🔵 External | Database - configured |
| **Redis** | Sonic | `redis:alpine` | 🔵 External | Cache - configured |
| **NATS** | Flash | `nats:alpine` | 🔵 External | Messaging - configured |
| **Pulsar** | Strange | `apachepulsar/pulsar` | 🔵 External | Event streaming - configured |
| **OTEL Collector** | Widow | `otel/opentelemetry-collector` | 🔵 External | Telemetry - configured |
| **Infisical** | Fury | `infisical/infisical` | 🔵 External | Secrets - configured |
| **Unleash** | Mystique | `unleashorg/unleash-server` | 🔵 External | Feature flags - configured |
| **LiveKit** | Daredevil | `livekit/livekit-server` | 🔵 External | WebRTC - configured |

**Status**: ✅ All core infrastructure is ready. Just needs `make up` and `.env` configuration.

---

## Plugin Services (Observability & Security)

| Service | Codename | Image | Status | Notes |
|---------|----------|-------|--------|-------|
| **Grafana** | Friday | `grafana/grafana` | 🔵 External | Dashboards - configured |
| **Prometheus** | House | `prom/prometheus` | 🔵 External | Metrics - configured |
| **Loki** | Watson | `grafana/loki` | 🔵 External | Logs - configured |
| **Jaeger** | Columbo | `grafana/tempo` | 🔵 External | Traces - configured |
| **Kratos** | Jarvis | `oryd/kratos` | 🔵 External | Identity - configured |
| **Promtail** | Hermes | `grafana/promtail` | 🔵 External | Log shipper - configured |

**Status**: ✅ All plugins are ready. Optional but recommended.

---

## Application Services (A.R.C. Custom Code)

### Actually Built

| Service | Codename | Language | LOC | Status | Maturity |
|---------|----------|----------|-----|--------|----------|
| **raymond** | Raymond | Go | ~1,700 | 🟢 Built | Beta |
| **arc-sherlock-brain** | Sherlock | Python | ~500 | 🟡 Stub | Prototype |
| **arc-scarlett-voice** | Scarlett | Python | ~300 | 🟡 Stub | Prototype |
| **arc-piper-tts** | Piper | Python | ~220 | 🟡 Stub | Prototype |

### Listed in SERVICE.MD but NOT Built

| Service | Codename | Type | Directory | Status |
|---------|----------|------|-----------|--------|
| **arc-janitor** | The Wolf | CORE | `./core/ops` | ⚪ Planned |
| **arc-billing** | Alfred | CORE | `./plugins/billing` | ⚪ Planned |
| **arc-guard** | RoboCop | CORE | `./core/guardrails` | ⚪ Planned |
| **arc-ramsay-critic** | Gordon Ramsay | WORKER | `./workers/critic` | ⚪ Planned |
| **arc-drago-gym** | Ivan Drago | WORKER | `./workers/gym` | ⚪ Planned |
| **arc-uhura-semantic** | Uhura | WORKER | `./workers/semantic` | ⚪ Planned |
| **arc-statham-mechanic** | Statham | WORKER | `./workers/healer` | ⚪ Planned |
| **arc-pathfinder-migrate** | Pathfinder | SIDECAR | `script` | ⚪ Planned |
| **arc-sentry-ingress** | Sentry | SIDECAR | `livekit/ingress` | 🔵 External (config needed) |
| **arc-scribe-egress** | Scribe | SIDECAR | `livekit/egress` | 🔵 External (config needed) |
| **arc-hedwig-mailer** | Hedwig | SIDECAR | `mailhog` | 🔵 External (config needed) |

### Extended Roster (Also Planned, Not Built)

| Service | Codename | Purpose | Status |
|---------|----------|---------|--------|
| **arc-terminator-chaos** | T-800 | Chaos testing | ⚪ Planned |
| **arc-kang-flow** | Kang | Workflow orchestration (Temporal) | ⚪ Planned |
| **arc-doc-time** | Doc Brown | Distributed scheduler (Dkron) | ⚪ Planned |
| **arc-architect-portal** | The Architect | Developer portal (Backstage) | ⚪ Planned |

---

## Honest Assessment: What Actually Works

### Working End-to-End
1. **Infrastructure stack** - `make up` brings up all core services
2. **Health checks** - All services have health endpoints
3. **Observability** - Logs, metrics, traces configured
4. **raymond** - Go bootstrap service with client libraries

### Partially Working (Stubs)
1. **arc-sherlock-brain** - Has structure but no real LLM integration
2. **arc-scarlett-voice** - Has LiveKit framework but no working pipeline
3. **arc-piper-tts** - Has endpoint but needs model download

### Not Started
- All WORKER services
- All SIDECAR services (except external configs)
- Guardrails, billing, janitor
- Chaos testing, workflows, scheduler

---

## Development Roadmap

### Phase 0: Current (Spec 002 - Stabilization)
**Status**: ✅ Complete

| Deliverable | Status |
|-------------|--------|
| Directory structure | ✅ |
| Docker standards | ✅ |
| Validation tooling | ✅ |
| CI/CD pipelines | ✅ |
| Documentation | ✅ |

---

### Phase 1: Make Sherlock Work
**Goal**: First working AI agent

#### 1.1 arc-sherlock-brain - Real Implementation

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| LLM Integration | P0 | ⚪ | Connect to OpenAI/Anthropic/Ollama |
| LangGraph Graph | P0 | ⚪ | Implement actual reasoning graph |
| pgvector Memory | P0 | ⚪ | Embedding storage and retrieval |
| Conversation History | P0 | ⚪ | Multi-turn context |
| NATS Integration | P0 | 🟡 | Handler exists, needs testing |
| Tool Framework | P1 | ⚪ | Tool calling interface |
| 3 Basic Tools | P1 | ⚪ | Search, calculator, time |
| Streaming | P1 | ⚪ | SSE response streaming |
| Error Handling | P1 | ⚪ | Graceful degradation |
| Tests | P1 | ⚪ | 60%+ coverage |

**Success Criteria**:
- [ ] `/chat` endpoint returns real LLM responses
- [ ] Conversations persist across requests
- [ ] NATS messages processed async
- [ ] Response latency <3s

---

### Phase 2: Voice Pipeline
**Goal**: End-to-end voice conversation

#### 2.1 arc-piper-tts - Production Ready

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Model Download | P0 | ⚪ | Auto-download voice models |
| Model Management | P1 | ⚪ | Multiple voices |
| Streaming Audio | P1 | ⚪ | Real-time streaming |
| Caching | P2 | ⚪ | Cache common phrases |

#### 2.2 arc-scarlett-voice - Full Implementation

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Whisper Integration | P0 | ⚪ | Real STT |
| Sherlock NATS Client | P0 | 🟡 | Connect to Sherlock |
| Piper TTS Client | P0 | 🟡 | Connect to Piper |
| LiveKit Testing | P0 | ⚪ | E2E voice test |
| VAD Tuning | P1 | ⚪ | Voice activity detection |

**Success Criteria**:
- [ ] Speak → Text → LLM → Text → Speech works
- [ ] <2s total latency
- [ ] 5+ minute conversations supported

---

### Phase 3: Safety & Quality
**Goal**: Production-ready agents

#### 3.1 arc-guard (RoboCop) - Guardrails

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Input Validation | P0 | ⚪ | Content filtering |
| Output Validation | P0 | ⚪ | Response filtering |
| PII Detection | P1 | ⚪ | Personal data protection |
| Jailbreak Prevention | P1 | ⚪ | Prompt injection defense |
| Rate Limiting | P1 | ⚪ | Per-user limits |

#### 3.2 arc-ramsay-critic (Gordon Ramsay) - Quality Assurance

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Response Evaluation | P0 | ⚪ | Score LLM outputs |
| Hallucination Detection | P0 | ⚪ | Fact checking |
| Quality Metrics | P1 | ⚪ | Track response quality |
| Feedback Loop | P1 | ⚪ | Improve over time |

---

### Phase 4: Specialized Workers
**Goal**: Expand agent capabilities

#### 4.1 arc-uhura-semantic (Uhura) - NL to Commands

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| SQL Generation | P0 | ⚪ | Natural language to SQL |
| API Generation | P0 | ⚪ | Natural language to API calls |
| Intent Classification | P1 | ⚪ | Understand user intent |

#### 4.2 arc-drago-gym (Ivan Drago) - Adversarial Training

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Prompt Attacks | P0 | ⚪ | Test prompt injection |
| Logic Attacks | P0 | ⚪ | Test reasoning flaws |
| Stress Testing | P1 | ⚪ | Load and edge cases |

#### 4.3 arc-statham-mechanic (Statham) - Self-Healing

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Error Recovery | P0 | ⚪ | Auto-retry failed requests |
| Circuit Breaking | P1 | ⚪ | Prevent cascade failures |
| Health Monitoring | P1 | ⚪ | Detect degradation |

---

### Phase 5: Operations
**Goal**: Production operations

#### 5.1 arc-janitor (The Wolf) - Cleanup Service

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Log Rotation | P0 | ⚪ | Manage log files |
| Data Cleanup | P0 | ⚪ | Remove old data |
| Resource Monitoring | P1 | ⚪ | Track disk/memory |

#### 5.2 arc-billing (Alfred) - Usage Tracking

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| API Metering | P0 | ⚪ | Track API usage |
| Cost Calculation | P1 | ⚪ | Calculate costs |
| Usage Reports | P1 | ⚪ | Generate reports |

---

### Phase 6: Advanced Features
**Goal**: Enterprise-ready platform

#### 6.1 arc-kang-flow (Kang) - Workflows

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Temporal Integration | P0 | ⚪ | Durable workflows |
| Workflow Templates | P1 | ⚪ | Common patterns |
| Error Recovery | P1 | ⚪ | Workflow retries |

#### 6.2 arc-terminator-chaos (T-800) - Chaos Testing

| Task | Priority | Status | Description |
|------|----------|--------|-------------|
| Pod Killing | P0 | ⚪ | Kill random services |
| Network Chaos | P1 | ⚪ | Latency injection |
| Resource Chaos | P1 | ⚪ | Memory/CPU limits |

---

## Priority Matrix

| Phase | Services | Priority | Effort |
|-------|----------|----------|--------|
| 1 | Sherlock | P0 - Critical | High |
| 2 | Piper, Scarlett | P0 - Critical | High |
| 3 | Guard, Ramsay | P1 - Important | Medium |
| 4 | Uhura, Drago, Statham | P2 - Useful | Medium |
| 5 | Janitor, Alfred | P2 - Useful | Low |
| 6 | Kang, T-800 | P3 - Nice to have | Medium |

---

## Service Count Summary

| Category | Total Listed | Built | Stub | Planned | External |
|----------|--------------|-------|------|---------|----------|
| Core Infrastructure | 9 | 0 | 0 | 0 | 9 |
| Plugins | 6 | 0 | 0 | 0 | 6 |
| Application Services | 4 | 1 | 3 | 0 | 0 |
| Workers | 4 | 0 | 0 | 4 | 0 |
| Sidecars | 4 | 0 | 0 | 1 | 3 |
| Core Custom | 3 | 0 | 0 | 3 | 0 |
| Extended | 4 | 0 | 0 | 4 | 0 |
| **TOTAL** | **34** | **1** | **3** | **12** | **18** |

**Reality Check**:
- 18 services are external (just Docker config)
- 1 service is built and working (raymond)
- 3 services are stubs (need major work)
- 12 services don't exist at all

---

## Recommended Execution Order

```
Week 1-2: Sherlock LLM Integration
    └── Real LLM responses
    └── pgvector memory
    └── Basic tools

Week 3-4: Voice Pipeline
    └── Piper model management
    └── Scarlett E2E testing
    └── <2s latency target

Week 5-6: Safety Layer
    └── Guard (input/output filtering)
    └── Ramsay (quality scoring)

Week 7-8: Workers
    └── Uhura (NL to SQL/API)
    └── Statham (self-healing)

Week 9-10: Operations
    └── Janitor (cleanup)
    └── Alfred (billing)

Future: Advanced
    └── Drago (adversarial)
    └── Kang (workflows)
    └── T-800 (chaos)
```

---

## Success Metrics by Phase

### Phase 1 (Sherlock)
- [ ] Real LLM responses via `/chat`
- [ ] Conversation memory works
- [ ] 60% test coverage
- [ ] <3s response latency

### Phase 2 (Voice)
- [ ] E2E voice works
- [ ] <2s total latency
- [ ] 90% STT accuracy

### Phase 3 (Safety)
- [ ] All inputs validated
- [ ] All outputs validated
- [ ] Jailbreak attempts blocked

### Phase 4 (Workers)
- [ ] Natural language to SQL works
- [ ] Auto-recovery from errors

### Phase 5 (Ops)
- [ ] Usage tracking active
- [ ] Auto-cleanup running

---

## Related Documentation

- [SERVICE.MD](../../SERVICE.MD) - Service registry (aspirational)
- [Service Categorization](./SERVICE-CATEGORIZATION.md) - Where services belong
- [Docker Standards](../standards/DOCKER-STANDARDS.md) - Container requirements
- [Validation Guide](../guides/VALIDATION-FAILURES.md) - Fixing issues
