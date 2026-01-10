---
description: 'Implementation tasks for Real-Time Voice Agent Interface'
---

# Tasks: Real-Time Voice Agent Interface (Daredevil Stack)

**Branch**: `001-realtime-media`  
**Date**: 2025-12-14  
**Input**: ADR-001 (Daredevil Real-Time Stack) + Data Flow Analysis

**Tests**: Not requested in specification - focusing on implementation and validation

**Organization**: Tasks are organized by ADR-001 implementation phases (Infrastructure → Agent Core → Observability)

## Format: `- [ ] [ID] [P?] [Phase] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Phase]**: Which implementation phase (INFRA, AGENT, OBS)
- Include exact file paths in descriptions

## Path Conventions

Based on current repository structure:

- **Services**: `services/[service-name]/` (Python or Go)
- **Core Infrastructure**: `core/[category]/[technology]/`
- **Deployments**: `deployments/docker/docker-compose.[profile].yml`
- **Documentation**: `docs/` and `specs/001-realtime-media/`

---

## Phase 1: Infrastructure Verification & Enhancement ✅ (Mostly Complete)

**Purpose**: Validate existing Go infrastructure and prepare for agent integration

**Status**: Infrastructure services are deployed. This phase focuses on validation and missing configuration.

**⚠️ CRITICAL**: Must verify all health checks pass before proceeding to Phase 2

### Validation Tasks

- [x] T001 Run `make health-all` and verify all core services are healthy
- [ ] T002 Test LiveKit WebRTC connection from browser to `ws://livekit.arc.local:7880`
- [x] T003 Verify Redis state sync by checking `arc-sonic-cache` contains LiveKit room data
- [ ] T004 Validate PostgreSQL pgvector extension with test query: `SELECT * FROM pg_extension WHERE extname='vector'`
- [ ] T005 Test NATS messaging with publish/subscribe to `agent.test.event` subject
- [ ] T006 Test Pulsar durable streaming with topic `persistent://arc/events/test`
- [ ] T007 Verify OTEL Collector is receiving metrics from `arc-daredevil-voice` at `/metrics` endpoint

### Configuration Enhancements

- [x] T008 [P] Create LiveKit JWT token generation utility in `scripts/livekit/generate-token.sh`
- [x] T009 [P] Add DNS validation check to ensure `livekit.arc.local` resolves to `127.0.0.1`
- [x] T010 [P] Document WebRTC port range (50000-50100) in `core/media/livekit/README.md`
- [x] T011 Create test HTML page for WebRTC connection validation in `core/media/livekit/test-client.html`

**Checkpoint**: Infrastructure verified - all services healthy and connectable

---

## Phase 2: Foundational Services (Agent Prerequisites) 🚧

**Purpose**: Core components that ALL agent services depend on

**⚠️ CRITICAL**: No agent implementation can begin until this phase is complete

### Database Schema

- [x] T012 Create `agents` schema in PostgreSQL via migration in `core/persistence/postgres/migrations/001_agents_schema.sql`
- [x] T013 Create `agents.conversations` table with pgvector embedding column in same migration
- [x] T014 Create indexes on `agents.conversations` (user_id, created_at, embedding vector)
- [x] T015 [P] Create `agents.sessions` table for LiveKit session tracking
- [x] T016 Run migration and verify schema with `make migrate-postgres`

### Agent Communication Infrastructure

- [x] T017 Define NATS subjects schema in `docs/architecture/nats-subjects.md`:
  - `agent.voice.track_published`
  - `agent.voice.track_unpublished`
  - `agent.brain.request`
  - `agent.brain.response`
- [x] T018 Define Pulsar topics schema in `docs/architecture/pulsar-topics.md`:
  - `persistent://arc/events/conversation`
  - `persistent://arc/events/agent-lifecycle`
  - `persistent://arc/analytics/session-metrics`
- [x] T019 Create test publisher/subscriber scripts in `scripts/messaging/test-nats.sh` and `scripts/messaging/test-pulsar.sh`

### Shared Libraries (Go)

- [ ] T020 [P] Create Go SDK for LiveKit token generation in `libs/go-sdk/livekit/auth.go`
- [ ] T021 [P] Create Go SDK for NATS agent events in `libs/go-sdk/messaging/nats_agent.go`
- [ ] T022 [P] Create Go SDK for Pulsar event publishing in `libs/go-sdk/messaging/pulsar_events.go`
- [ ] T023 Write unit tests for Go SDKs in `libs/go-sdk/*/[name]_test.go`

### Shared Libraries (Python)

- [x] T024 [P] Create Python database models in `libs/python-sdk/arc_common/models/conversation.py`
- [x] T025 [P] Create Python NATS client wrapper in `libs/python-sdk/arc_common/messaging/nats_client.py`
- [x] T026 [P] Create Python Pulsar client wrapper in `libs/python-sdk/arc_common/messaging/pulsar_client.py`
- [x] T027 [P] Create Python OTEL instrumentation helpers in `libs/python-sdk/arc_common/observability/otel.py`
- [x] T028 Write unit tests for Python SDK in `libs/python-sdk/tests/`

**Checkpoint**: Foundation ready - agent services can now be implemented

---

## Phase 3: User Story 1 - Basic Voice Agent (Priority: P1) 🎯 MVP

**Goal**: Implement end-to-end voice conversation: User speaks → Agent responds with voice

**Architecture**: **HYBRID** - LiveKit Agents SDK for voice pipeline + microservices for brain/TTS

**Independent Test**: User connects to LiveKit room, speaks "Hello", hears synthesized response "Hello! How can I help you?"

**Target Latency**: <1000ms (LiveKit Agents optimized pipeline)

### Phase 3A: Quick Win - Voice Agent with Built-In Plugins (Week 1)

**Purpose**: Prove the concept fast using LiveKit's built-in STT/TTS/LLM plugins

- [x] T029 [P] [US1-A] Create service directory structure in `services/arc-scarlett-voice/`
- [x] T030 [P] [US1-A] Create Dockerfile with LiveKit Agents SDK in `services/arc-scarlett-voice/Dockerfile`
- [x] T031 [US1-A] Create agent entry point in `services/arc-scarlett-voice/src/agent.py`:
  - Use `VoicePipelineAgent` from LiveKit Agents SDK
  - STT: Deepgram plugin (cloud, fast)
  - LLM: OpenAI plugin (direct API call, no brain service yet)
  - TTS: OpenAI TTS plugin (cloud, high quality)
  - VAD: Built-in Silero VAD
- [x] T032 [US1-A] Add environment variables for API keys in `.env.example`
- [x] T033 [US1-A] Create `requirements.txt` with `livekit-agents`, `livekit-plugins-deepgram`, `livekit-plugins-openai`
- [x] T034 [US1-A] Add OTEL instrumentation wrapper in `services/arc-scarlett-voice/src/observability.py`
- [x] T035 [US1-A] Add service to `deployments/docker/docker-compose.services.yml` as `arc-scarlett`
- [ ] T036 [US1-A] Create integration test script in `tests/integration/test_voice_quick_win.sh`

**Checkpoint 3A**: Voice agent working end-to-end in 2-3 days (cloud-based STT/TTS/LLM)

---

### Phase 3B: Add Custom Brain Service (Week 2)

**Purpose**: Replace OpenAI direct LLM with arc-sherlock-brain for advanced reasoning

- [x] T037 [P] [US1-B] Create service directory structure in `services/arc-sherlock-brain/`
- [x] T038 [P] [US1-B] Create Dockerfile for LangGraph service in `services/arc-sherlock-brain/Dockerfile`
- [x] T039 [US1-B] Create FastAPI server in `services/arc-sherlock-brain/src/main.py`
- [x] T040 [US1-B] Implement PostgreSQL connection using SQLAlchemy in `services/arc-sherlock-brain/src/database.py`
- [x] T041 [US1-B] Create simple LangGraph state machine in `services/arc-sherlock-brain/src/graph.py`:
  - State: `{user_input: str, context: list, response: str}`
  - Nodes: `retrieve_context`, `generate_response`
  - Edges: Linear flow
- [ ] T042 [US1-B] Implement `/chat` endpoint (HTTP) accepting `{"text": str, "user_id": str}`
- [x] T043 [US1-B] Implement NATS handler for `brain.request` subject (async messaging)
- [x] T044 [US1-B] Add conversation persistence to PostgreSQL `agents.conversations` table
- [x] T045 [US1-B] Add pgvector context retrieval (top 5 similar conversations)
- [x] T046 [US1-B] Create `requirements.txt` with `fastapi`, `langgraph`, `sqlalchemy`, `psycopg2`, `opentelemetry-*`
- [x] T047 [US1-B] Add OTEL instrumentation for traces and metrics
- [x] T048 [US1-B] Add service to `deployments/docker/docker-compose.services.yml` as `arc-sherlock`

**Custom LLM Plugin for LiveKit Agents**:

- [x] T049 [US1-B] Create custom LLM plugin in `services/arc-scarlett-voice/src/plugins/sherlock_llm.py`:
  - Extends `LLMPlugin` from LiveKit Agents SDK
  - Calls `arc-sherlock-brain` via NATS (async) or HTTP (sync)
  - Handles streaming responses (SSE from brain)
- [x] T050 [US1-B] Update agent to use `SherlockLLMPlugin` instead of OpenAI plugin
- [x] T051 [US1-B] Add NATS client wrapper in `services/arc-scarlett-voice/src/messaging.py`

**Checkpoint 3B**: Voice agent uses custom LangGraph reasoning, conversations persisted

---

### Phase 3C: Add Custom TTS Service (Week 3)

**Purpose**: Replace OpenAI TTS with arc-piper-tts for cost savings and local inference

- [ ] T052 [P] [US1-C] Create service directory structure in `services/arc-piper-tts/`
- [ ] T053 [P] [US1-C] Create Dockerfile for Piper TTS in `services/arc-piper-tts/Dockerfile`
- [ ] T054 [US1-C] Download Piper model `en_US-lessac-medium.onnx` (handled by Dockerfile)
- [ ] T055 [US1-C] Create NATS handler for TTS requests in `services/arc-piper-tts/src/nats_handler.py`:
  - Subscribe to `tts.request` subject
  - **Stream** raw PCM audio chunks (not buffered WAV)
  - Yield first audio chunk within 50-100ms
  - Use NATS publish for each audio chunk (enable true streaming)
- [ ] T056 [US1-C] Create FastAPI endpoint `/tts/stream` for HTTP streaming (fallback)
- [ ] T057 [US1-C] Sample rate handling (Piper 22kHz ↔ LiveKit 16kHz):
  - **Option A (Preferred)**: Configure LiveKit to accept 22kHz (zero overhead)
  - **Option B**: Use `scipy.signal.resample_poly` (5-10ms, not librosa which adds 20-50ms)
  - Make configurable via environment variable `TTS_SAMPLE_RATE_CONVERSION`
- [ ] T058 [US1-C] Create `requirements.txt` with `piper-tts`, `librosa`, `arc_common`
- [ ] T059 [US1-C] Add OTEL instrumentation for TTS latency metrics
- [ ] T060 [US1-C] Add service to `deployments/docker/docker-compose.services.yml` as `arc-piper`

**Custom TTS Plugin for LiveKit Agents**:

- [x] T061 [US1-C] Create custom TTS plugin in `services/arc-scarlett-voice/src/plugins/piper_tts.py`:
  - Extends `TTSPlugin` from LiveKit Agents SDK
  - Calls `arc-piper-tts` via NATS for low latency
  - Streams PCM frames directly to LiveKit audio track
  - Handles sample rate conversion if needed
- [x] T062 [US1-C] Update agent to use `PiperTTSPlugin` instead of OpenAI TTS
- [ ] T063 [US1-C] Add A/B testing config to switch between Piper/OpenAI via env var

**Checkpoint 3C**: Voice agent fully local (except STT), using Piper TTS + LangGraph brain

---

### Phase 3D: Integration & Testing (Week 4)

- [ ] T064 [US1-D] Update `docker-compose.services.yml` with proper dependencies:
  - `arc-scarlett` depends on `arc-daredevil`, `arc-sherlock`, `arc-piper`
  - `arc-sherlock` depends on `arc-oracle` (PostgreSQL), `arc-flash` (NATS)
  - `arc-piper` depends on `arc-flash` (NATS)
- [ ] T065 [US1-D] Create integration test script in `tests/integration/test_voice_agent_full.sh`:
  - Start all services
  - Generate LiveKit token
  - Connect test client
  - Send audio "Hello"
  - Verify brain response received
  - Verify TTS audio played back
  - Check conversation persisted in PostgreSQL
  - Validate latency < 1000ms
- [ ] T066 [US1-D] Create quickstart guide in `specs/001-realtime-media/quickstart.md`:
  - Phase 3A: Quick win with cloud plugins
  - Phase 3B: Add brain service
  - Phase 3C: Add TTS service
  - Switching between configurations
- [ ] T067 [US1-D] Add structured logging to all services (JSON format with trace IDs)
- [ ] T068 [US1-D] Run end-to-end test and document latency breakdown in Jaeger

**Checkpoint 3D**: Full hybrid architecture working - LiveKit Agents + microservices

### Integration & Testing

- [ ] T064 [US1-D] Update `docker-compose.services.yml` with proper dependencies:
  - `arc-scarlett` depends on `arc-daredevil`, `arc-sherlock`, `arc-piper`
  - `arc-sherlock` depends on `arc-oracle` (PostgreSQL), `arc-flash` (NATS)
  - `arc-piper` depends on `arc-flash` (NATS)
- [ ] T065 [US1-D] Create integration test script in `tests/integration/test_voice_agent_full.sh`:
  - Start all services
  - Generate LiveKit token
  - Connect test client
  - Send audio "Hello"
  - Verify brain response received
  - Verify TTS audio played back
  - Check conversation persisted in PostgreSQL
  - Validate latency < 1000ms
- [x] T066 [US1-D] Create quickstart guide in `specs/001-realtime-media/quickstart.md`:
  - Phase 3A: Quick win with cloud plugins
  - Phase 3B: Add brain service
  - Phase 3C: Add TTS service
  - Switching between configurations
- [x] T067 [US1-D] Add structured logging to all services (JSON format with trace IDs)
- [ ] T068 [US1-D] Run end-to-end test and document latency breakdown in Jaeger

**Checkpoint 3D**: Full hybrid architecture working - LiveKit Agents + microservices

---

## Phase 4: User Story 2 - Latency Optimization (Priority: P2)

**Goal**: Reduce end-to-end latency from <1000ms to <500ms through streaming and optimization

**Independent Test**: User speaks "What's the weather?" and hears response start within 500ms

**Note**: LiveKit Agents SDK already handles much of the streaming pipeline optimization

### Streaming LLM Implementation

- [ ] T069 [P] [US2] Add LLM streaming support to LangGraph in `services/arc-sherlock-brain/src/graph_streaming.py`
- [ ] T070 [P] [US2] Modify NATS handler to support streaming responses (chunked messages)
- [ ] T071 [US2] Update `/chat` endpoint to support Server-Sent Events (SSE) for HTTP streaming
- [ ] T072 [US2] Update `SherlockLLMPlugin` to consume streaming NATS responses

### Sentence-Level TTS Streaming

- [ ] T073 [P] [US2] Implement smart sentence chunking in Piper NATS handler:
  - Split on sentence boundaries (., !, ?)
  - **Further split** long sentences (>15 words) at commas for faster TTFT
  - Synthesize and stream each chunk immediately
  - Target: First audio chunk in <100ms
- [ ] T074 [US2] Update `PiperTTSPlugin` to handle chunked audio frames
- [ ] T075 [US2] Add sentence boundary detection in `arc-sherlock-brain` response with smart chunking

### Performance Optimization

- [ ] T076 [P] [US2] Pre-warm Piper models on service startup:
  - Load ONNX model during lifespan startup
  - Run dummy synthesis to warm up ONNX runtime
  - Eliminates 2-5s cold start penalty on first request
- [ ] T076b [P] [US2] Implement parallel LLM→TTS pipeline in `arc-scarlett-voice`:
  - Generate next sentence while current sentence is synthesizing
  - Use `asyncio.Queue` for sentence buffering
  - Overlap LLM inference with TTS synthesis
  - Target: 50% latency reduction for multi-sentence responses
- [ ] T077 [P] [US2] Add connection pooling for PostgreSQL in `arc-sherlock-brain`
- [ ] T078 [P] [US2] Optimize pgvector query with proper HNSW index parameters
- [ ] T079 [P] [US2] Add Redis caching for frequent LLM responses in `services/arc-sherlock-brain/src/cache.py`
- [ ] T080 [P] [US2] Optimize NATS message serialization (use MessagePack instead of JSON for 30% size reduction)
- [ ] T081 [US2] Profile pipeline and identify bottlenecks using Jaeger traces:
  - Measure TTFT (Time To First Token)
  - Identify slowest components in voice pipeline
  - Target breakdown: STT<200ms, LLM<300ms, TTS<100ms
- [ ] T082 [US2] Update integration test to validate <500ms P95 latency and <200ms TTFT

**Checkpoint**: Latency optimized - streaming pipeline achieves <500ms response time

---

## Phase 5: User Story 3 - Advanced Features (Priority: P3)

**Goal**: Add session recording, multi-participant support, and advanced conversation features

**Independent Test**: Multiple users can join same room, agent responds to each, sessions are recorded

**Note**: LiveKit Agents SDK provides multi-participant support out-of-the-box

### Session Recording (arc-scribe-egress)

- [ ] T083 [P] [US3] Create service directory structure in `services/arc-scribe-egress/`
- [ ] T084 [P] [US3] Create Dockerfile for LiveKit Egress sidecar in `services/arc-scribe-egress/Dockerfile`
- [ ] T085 [US3] Configure egress to record room audio to WebM format
- [ ] T086 [US3] Implement recording upload to PostgreSQL BYTEA in `services/arc-scribe-egress/src/uploader.py`
- [ ] T087 [US3] Create `agents.recordings` table for session storage
- [ ] T088 [US3] Add service to `deployments/docker/docker-compose.services.yml` as `arc-scribe`

### External Ingress (arc-sentry-ingress)

- [ ] T089 [P] [US3] Create service directory structure in `services/arc-sentry-ingress/`
- [ ] T090 [P] [US3] Create Dockerfile for LiveKit Ingress sidecar in `services/arc-sentry-ingress/Dockerfile`
- [ ] T091 [US3] Configure RTMP ingress for external video/audio sources
- [ ] T092 [US3] Configure SIP ingress for phone call integration
- [ ] T093 [US3] Add service to `deployments/docker/docker-compose.services.yml` as `arc-sentry`

### Multi-Participant Support

- [ ] T094 [P] [US3] Update agent to handle multiple participants (LiveKit SDK handles this):
  - Subscribe to all participant tracks
  - Maintain separate conversation context per user
  - Direct responses to correct participant
- [ ] T095 [P] [US3] Add participant tracking in Redis state
- [ ] T096 [US3] Update LangGraph to support multi-user context in `services/arc-sherlock-brain/src/graph.py`:
  - Accept `user_id` in requests
  - Retrieve user-specific conversation history
  - Maintain separate context windows per user

### Advanced Conversation Features

- [ ] T097 [P] [US3] Implement conversation summarization in `services/arc-sherlock-brain/src/summarizer.py`
- [ ] T098 [P] [US3] Add sentiment analysis to conversation tracking
- [ ] T099 [P] [US3] Implement conversation export (JSON, transcript) in `services/arc-sherlock-brain/src/export.py`
- [ ] T100 [US3] Create API endpoints for session playback and management

**Checkpoint**: Advanced features complete - recording, multi-participant, and conversation management work

---

## Phase 6: Observability & Monitoring (Cross-Cutting)

**Purpose**: Production-ready monitoring, alerting, and debugging capabilities

### Grafana Dashboards

- [ ] T101 [P] Create LiveKit metrics dashboard in `plugins/observability/visualization/grafana/dashboards/livekit.json`:
  - Panel: Room participants (gauge)
  - Panel: Packet loss percentage (gauge)
  - Panel: Track publish duration (histogram)
  - Panel: Jitter (gauge)
- [ ] T102 [P] Create Agent performance dashboard in `plugins/observability/visualization/grafana/dashboards/agent.json`:
  - Panel: End-to-end latency (P50, P95, P99)
  - Panel: STT latency (histogram)
  - Panel: LLM inference time (histogram)
  - Panel: TTS generation time (histogram)
  - Panel: Conversation turns per minute (rate)
- [ ] T103 [P] Create System health dashboard in `plugins/observability/visualization/grafana/dashboards/system.json`:
  - Panel: Service uptime (up metric)
  - Panel: Error rates by service
  - Panel: Resource usage (CPU, memory)

### Alerting Rules

- [ ] T104 [P] Create Prometheus alerting rules in `plugins/observability/metrics/prometheus/alerts/agent.yml`:
  - Alert: `HighLatency` when P95 > 500ms for 5 minutes
  - Alert: `PacketLoss` when loss > 1% for 2 minutes
  - Alert: `ServiceDown` when service unhealthy for 1 minute
  - Alert: `LowThroughput` when turns/min < 1 for 10 minutes
- [ ] T105 [P] Configure alert routing to NATS in Prometheus config

### Distributed Tracing

- [ ] T106 [P] Create Jaeger service map for voice pipeline
- [ ] T107 [P] Add trace sampling configuration (sample 10% in production)
- [ ] T108 [P] Document trace context propagation in `docs/observability/tracing.md`

### Logging

- [ ] T109 [P] Configure structured logging for all Python services (JSON format)
- [ ] T110 [P] Add log correlation IDs (trace_id from OTEL)
- [ ] T111 [P] Create Loki query templates in `docs/observability/loki-queries.md`:
  - Query: All errors in last hour
  - Query: Agent lifecycle events
  - Query: Slow queries (>100ms)

**Checkpoint**: Full observability stack operational - metrics, traces, logs, alerts

---

## Phase 7: Chaos Engineering & Resilience (Testing)

**Purpose**: Validate system resilience under failure conditions

### Chaos Mesh Tests (Future - Kubernetes Only)

- [ ] T112 Create pod-kill chaos experiment for Redis failover in `tests/chaos/redis-failover.yaml`
- [ ] T113 Create network-delay chaos experiment (100ms, 500ms) in `tests/chaos/network-latency.yaml`
- [ ] T114 Create packet-loss chaos experiment (1%, 5%, 10%) in `tests/chaos/packet-loss.yaml`

### Docker-Based Resilience Tests

- [ ] T115 Create script to kill random service and verify recovery in `tests/resilience/service-recovery.sh`
- [ ] T116 Create script to simulate PostgreSQL downtime in `tests/resilience/postgres-down.sh`
- [ ] T117 Create script to simulate Redis downtime in `tests/resilience/redis-down.sh`
- [ ] T118 Verify agent continues with graceful degradation (stateless mode)

### Load Testing

- [ ] T119 Create k6 load test script for concurrent rooms in `tests/load/concurrent-rooms.js`
- [ ] T120 Create k6 load test script for message throughput in `tests/load/message-throughput.js`
- [ ] T121 Run load tests and document results in `specs/001-realtime-media/load-test-results.md`

**Checkpoint**: System resilience validated under failure and load conditions

---

## Phase 8: Documentation & Polish

**Purpose**: Production-ready documentation and cleanup

### API Documentation

- [ ] T122 [P] Generate OpenAPI spec for `arc-sherlock-brain` API
- [ ] T123 [P] Generate OpenAPI spec for `arc-piper-tts` API (NATS + HTTP endpoints)
- [ ] T124 [P] Create API documentation site using Swagger UI in `docs/api/`
- [ ] T125 [P] Document custom LiveKit Agents plugins in `docs/plugins/`

### Deployment Documentation

- [ ] T126 [P] Document production deployment steps in `docs/deployment/production.md`:
  - DNS configuration for public domain
  - TURN server setup (Coturn)
  - SSL/TLS certificate installation
  - Port security (remove development port mappings)
  - Secrets management (rotate keys)
  - Environment variables for cloud STT/TTS API keys
- [ ] T127 [P] Create Kubernetes manifests in `deployments/kubernetes/`:
  - StatefulSet for PostgreSQL
  - Deployment for all services
  - Service and Ingress for external access
  - ConfigMaps and Secrets

### Architecture Documentation

- [ ] T128 [P] Update architecture diagrams in `docs/architecture/README.md`:
  - Add hybrid architecture diagram (LiveKit Agents + microservices)
  - Show NATS communication flows
  - Document plugin architecture
- [ ] T129 [P] Document service interaction protocols in `docs/architecture/protocols.md`
- [ ] T130 [P] Create troubleshooting guide in `docs/troubleshooting/voice-agent.md`
- [ ] T131 [P] Document phase-based implementation strategy in `docs/implementation-phases.md`

### Code Quality

- [ ] T132 [P] Run `black` and `isort` on all Python code
- [ ] T133 [P] Run `gofumpt` on all Go code
- [ ] T134 [P] Run `golangci-lint` and fix issues
- [ ] T135 [P] Run `mypy` strict mode on Python services and fix type issues
- [ ] T136 [P] Run `ruff` linter on Python services
- [ ] T137 [P] Add pre-commit hooks for linting in `.pre-commit-config.yaml`

### Security Hardening

- [ ] T138 [P] Rotate all default API keys and secrets
- [ ] T139 [P] Remove development port mappings using `docker-compose.production.yml`
- [ ] T140 [P] Configure Traefik rate limiting for LiveKit endpoints
- [ ] T141 [P] Add authentication middleware for admin APIs
- [ ] T142 [P] Run security scan with `trivy` on all Docker images
- [ ] T143 [P] Document security best practices in `docs/security/voice-agent.md`
- [ ] T144 [P] Add secrets scanning for API keys in `.gitignore`

**Checkpoint**: Production-ready - documentation complete, code quality high, security hardened

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Infrastructure Verification) ──┐
                                        │
                                        ▼
Phase 2 (Foundational Services) ────────┐
                                        │
                                        ▼
                 ┌──────────────────────┴────────────────────┐
                 │                                           │
Phase 3A (Quick Win - Cloud Plugins) ───┐                   │
                 │                       │                   │
                 ▼                       │                   │
Phase 3B (Add Brain Service) ───────────┤                   │
                 │                       │                   │
                 ▼                       │                   │
Phase 3C (Add TTS Service) ─────────────┤                   │
                 │                       │                   │
                 ▼                       │                   │
Phase 3D (Integration & Testing) ───────┘                   │
                 │                                           │
                 ├──► Phase 6 (Observability) ──┐            │
                 │                               │            │
Phase 4 (Latency Optimization) ──────────────────┤            │
                 │                               │            │
Phase 5 (Advanced Features) ─────────────────────┘            │
                                                              │
                                                              ▼
                         Phase 7 (Chaos Testing) ────────────┐
                                                              │
                                                              ▼
                         Phase 8 (Documentation & Polish)
```

### Critical Path (Hybrid Architecture)

1. **Phase 1 → Phase 2**: MUST validate infrastructure before building foundation
2. **Phase 2 completion**: BLOCKS all user story phases (3A-3D)
3. **Phase 3A → 3B → 3C → 3D**: Sequential phases (week by week incremental value)
   - 3A: Quick win (2-3 days) - voice agent with cloud plugins
   - 3B: Add custom brain (5-7 days) - LangGraph reasoning
   - 3C: Add custom TTS (3-5 days) - local Piper inference
   - 3D: Integration tests (2-3 days) - validate full pipeline
4. **Phase 3D completion**: Required before latency optimization (Phase 4)
5. **Phase 3D + 4**: Recommended before advanced features (Phase 5)
6. **Phase 6**: Can start in parallel with Phase 3B/3C/3D (independent)
7. **Phase 7**: Requires Phase 3D minimum (full pipeline working)
8. **Phase 8**: Final phase after all features complete

### Parallel Opportunities Within Phases

**Phase 2 (Foundational)**:

- T020-T023 (Go SDKs) can run in parallel
- T024-T028 (Python SDKs) can run in parallel
- Database tasks (T012-T016) independent from SDK tasks

**Phase 3A (Quick Win)**:

- All tasks are sequential (building one service)

**Phase 3B (Add Brain)**:

- T037-T038 (Brain structure/Dockerfile) parallel with agent plugin work
- T039-T048 (Brain implementation) sequential
- T049-T051 (Plugin integration) sequential after brain complete

**Phase 3C (Add TTS)**:

- T052-T053 (TTS structure/Dockerfile) parallel with agent plugin work
- T054-T060 (TTS implementation) sequential
- T061-T063 (Plugin integration) sequential after TTS complete

**Phase 4 (Latency)**:

- T069-T072 (Streaming LLM) parallel with T073-T075 (Streaming TTS)
- T076-T080 (Optimizations) can all run in parallel

**Phase 6 (Observability)**:

- All dashboard tasks (T101-T103) parallel
- All alerting/logging tasks parallel

**Phase 8 (Polish)**:

- All documentation tasks parallel
- All code quality tasks parallel
- All security tasks parallel

---

## Implementation Strategy

### MVP-First Approach (Hybrid Architecture - RECOMMENDED)

**Milestone 1: Foundation** (Weeks 1-2)

- Complete Phase 1 (validate infrastructure)
- Complete Phase 2 (foundational services)
- **Deliverable**: Database schema, messaging, SDKs ready

**Milestone 2: Quick Win MVP** (Week 3)

- Complete Phase 3A (voice agent with cloud plugins)
- **Deliverable**: Working voice agent using Deepgram STT + OpenAI LLM/TTS (cloud-based)
- **Value**: Fastest path to demo/validation (2-3 days)

**Milestone 3: Custom Brain** (Week 4)

- Complete Phase 3B (add LangGraph brain service)
- Partial Phase 6 (basic metrics dashboard)
- **Deliverable**: Voice agent with custom reasoning (LangGraph + pgvector)
- **Value**: Proves brain architecture, conversations persisted

**Milestone 4: Local TTS** (Week 5)

- Complete Phase 3C (add Piper TTS service)
- Complete Phase 3D (integration testing)
- **Deliverable**: Fully local TTS (except STT), cost savings
- **Value**: Reduced cloud costs, swappable TTS

**Milestone 5: Production** (Weeks 6-7)

- Complete Phase 4 (latency optimization)
- Complete Phase 6 (full observability)
- **Deliverable**: Production-ready agent (<500ms latency)

**Milestone 6: Advanced** (Weeks 8-10)

- Complete Phase 5 (advanced features)
- Complete Phase 7 (chaos testing)
- Complete Phase 8 (documentation)
- **Deliverable**: Full-featured platform with recordings, multi-user, resilience

### Phased Value Delivery

**Week 1-2**: Infrastructure validated, foundation ready  
**Week 3**: ✅ **DEMO-ABLE** - Voice agent working with cloud plugins  
**Week 4**: ✅ **VALUABLE** - Custom brain reasoning with memory  
**Week 5**: ✅ **COMPLETE** - Full hybrid architecture (local + cloud)  
**Week 6-7**: ✅ **PRODUCTION** - Optimized latency, full monitoring  
**Week 8-10**: ✅ **ADVANCED** - Multi-user, recording, resilience

### Team Parallelization Strategy

**2 Developers**:

- Dev A: Infrastructure + Foundation (Go SDKs) + arc-piper-tts
- Dev B: Python SDKs + arc-sherlock-brain + arc-scarlett-voice plugins

**3 Developers**:

- Dev A: Infrastructure + Foundational (Go + Python SDKs)
- Dev B: arc-scarlett-voice (Phase 3A → 3B → 3C integration)
- Dev C: arc-sherlock-brain + arc-piper-tts + Observability

**4+ Developers**:

- Dev A: Go SDKs + Infrastructure validation
- Dev B: Python SDKs + arc-sherlock-brain
- Dev C: arc-scarlett-voice + custom plugins
- Dev D: arc-piper-tts + Observability + Documentation

### Alternative: Cloud-Only Fast Path (1 Week MVP)

If you need a demo **immediately**, skip Phase 3B/3C and stay on Phase 3A:

- Use Deepgram STT (cloud, $0.0125/min)
- Use OpenAI GPT-4 (cloud, ~$0.02/request)
- Use OpenAI TTS (cloud, ~$0.015/1000 chars)
- Skip brain/TTS services entirely
- **Total cost**: ~$0.05/minute conversation
- **Time to demo**: 2-3 days
- **Upgrade path**: Add Phase 3B/3C later when ready

---

## Validation Checklist

### Phase 1 Complete

- [ ] All services show green in `make health-all`
- [ ] Browser can connect to `wss://livekit.arc.local`
- [ ] WebRTC media flows through UDP ports 50000-50100

### Phase 2 Complete

- [ ] Database schema created and migrated
- [ ] NATS subjects documented and tested
- [ ] Pulsar topics documented and tested
- [ ] Go and Python SDKs have passing unit tests

### Phase 3A Complete (Quick Win MVP)

- [ ] User can speak and hear agent response
- [ ] End-to-end latency < 1500ms (cloud plugins)
- [ ] OpenAI LLM responds correctly
- [ ] Deepgram STT transcribes accurately

### Phase 3B Complete (Custom Brain)

- [ ] LangGraph brain service responds via HTTP and NATS
- [ ] Conversation persisted to PostgreSQL
- [ ] Context retrieval working (pgvector)
- [ ] Custom LLM plugin integrated with LiveKit agent

### Phase 3C Complete (Custom TTS)

- [ ] Piper TTS service synthesizes audio via NATS
- [ ] Sample rate conversion working (22kHz → 16kHz)
- [ ] Custom TTS plugin integrated with LiveKit agent
- [ ] Can switch between Piper/OpenAI TTS via config

### Phase 3D Complete (Full Integration)

- [ ] All services running in Docker Compose
- [ ] Integration tests pass
- [ ] End-to-end latency < 1000ms
- [ ] Analytics events published to Pulsar

### Phase 4 Complete

- [ ] End-to-end latency < 500ms (P95)
- [ ] Streaming pipeline operational
- [ ] Jaeger traces show optimization impact

### Phase 5 Complete

- [ ] Session recording works
- [ ] Multiple users can join same room
- [ ] Agent handles each user separately

### Phase 6 Complete

- [ ] Grafana dashboards show real-time metrics
- [ ] Alerts fire when SLOs violated
- [ ] Distributed traces visible in Jaeger

### Phase 7 Complete

- [ ] System survives service restarts
- [ ] Load tests pass (10 concurrent rooms)
- [ ] Graceful degradation verified

### Phase 8 Complete

- [ ] All APIs documented
- [ ] Deployment guides complete
- [ ] Code passes linting and type checks
- [ ] Security scan shows no critical issues

---

## Notes

- **HYBRID ARCHITECTURE**: LiveKit Agents SDK + microservices (brain/TTS)
- **[P]** tasks can run in parallel if you have multiple developers
- **[Phase]** label helps track which ADR-001 implementation phase task belongs to
- **File paths** are absolute from repository root
- **Latency targets**: Phase 3A=1500ms (cloud), Phase 3D=1000ms (hybrid), Phase 4=500ms P95 latency + <200ms TTFT (Time To First Token)
- **TTFT (Time To First Token)**: Critical metric for voice responsiveness - time from user stops speaking to first audio playback
- **Testing**: Integration tests in Phase 3D, load tests in Phase 7
- **Observability**: Built incrementally, complete by Phase 6
- **Docker Compose**: Update `docker-compose.services.yml` as services are added
- **Kubernetes**: Optional, only if deploying beyond local development
- **Plugin Pattern**: Custom LiveKit Agents plugins for brain/TTS integration

---

**Total Tasks**: 145 (updated from 144 - added T076b for parallel pipeline)  
**Estimated Duration**: 8-10 weeks (2 developers, hybrid MVP-first approach)  
**Critical Path**: Phase 1 → 2 → 3A → 3B → 3C → 3D → 4 (Weeks 1-7 for production-ready)  
**Quick Win**: Week 3 (Phase 3A - cloud-based voice agent working)  
**TTFT Optimization**: Phase 4 reduces Time To First Token from 500-800ms → 100-200ms (5-8x improvement)

**END OF TASKS DOCUMENT**
