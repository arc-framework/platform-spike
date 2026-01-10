# Data Flow Analysis: A.R.C. Real-Time Media Stack

**Feature**: Real-Time Voice Agent Interface  
**Branch**: `001-realtime-media`  
**Date**: 2025-12-14  
**Status**: Analysis Document (No Code Implementation)

---

## Executive Summary

This document provides a comprehensive analysis of how data flows through the A.R.C. platform when a user interacts with a voice agent. The analysis is based on the **Daredevil Real-Time Stack** (ADR-001) and the current repository infrastructure.

**Key Finding**: The platform implements a **Polyglot Two-Brain Architecture** where:

- **Go services** (Infrastructure/Body) handle high-performance transport, routing, and state management
- **Python services** (Intelligence/Mind) handle AI reasoning, speech processing, and agent logic

---

## Architecture Overview

### Current Infrastructure Status

Based on repository analysis, the following services are **configured and ready**:

| Service Codename       | Technology              | Status      | Role in Voice Flow                     |
| ---------------------- | ----------------------- | ----------- | -------------------------------------- |
| `arc-heimdall-gateway` | Traefik                 | ✅ Deployed | Routes WebSocket signaling to LiveKit  |
| `arc-daredevil-voice`  | LiveKit Server (Go)     | ✅ Deployed | WebRTC SFU for media routing           |
| `arc-sonic-cache`      | Redis                   | ✅ Deployed | LiveKit distributed state storage      |
| `arc-oracle-sql`       | PostgreSQL + pgvector   | ✅ Deployed | Agent state, conversation history      |
| `arc-flash-pulse`      | NATS                    | ✅ Deployed | Ephemeral messaging for agent commands |
| `arc-strange-stream`   | Pulsar                  | ✅ Deployed | Durable event streaming for analytics  |
| `arc-widow-otel`       | OpenTelemetry Collector | ✅ Deployed | Telemetry collection for all services  |

**Not Yet Implemented** (per ADR-001 Phase 2):

- `arc-scarlett-voice` (Python LiveKit Agent Worker)
- `arc-sherlock-brain` (LangGraph reasoning engine)
- `arc-piper-tts` (Text-to-Speech engine)
- `arc-scribe-egress` (Session recording sidecar)
- `arc-sentry-ingress` (External RTMP/SIP ingress)

---

## Complete Data Flow: User → Agent → User

### Phase 1: Connection Establishment (The Handshake)

**Actors**: User Browser, Traefik, LiveKit Server, Redis

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. User initiates voice session from browser                            │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ wss://livekit.arc.local
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. arc-heimdall-gateway (Traefik)                                       │
│    - Receives WebSocket connection on port 80                           │
│    - Routes based on Host header: livekit.arc.local                     │
│    - Forwards to arc-daredevil-voice:7880                               │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ ws://arc-daredevil:7880
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. arc-daredevil-voice (LiveKit Server - Go)                            │
│    - Validates JWT token (api_key/secret)                               │
│    - Negotiates WebRTC connection (ICE/DTLS)                            │
│    - Establishes UDP media channels (ports 50000-50100)                 │
│    - Creates room if auto_create=true                                   │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ Room state sync
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. arc-sonic-cache (Redis)                                              │
│    - Stores room state: participants, tracks, metadata                  │
│    - Enables distributed LiveKit operation (multi-node ready)           │
│    - Pub/Sub for real-time state updates                                │
└─────────────────────────────────────────────────────────────────────────┘
```

**Data Structures** (Redis):

```json
{
  "room:test-room": {
    "sid": "RM_abc123",
    "created_at": "2025-12-14T10:00:00Z",
    "participants": ["user-123", "agent-scarlett"],
    "empty_timeout": 300
  },
  "participant:user-123": {
    "sid": "PA_xyz789",
    "identity": "user-123",
    "tracks": ["TR_audio_001"],
    "state": "active"
  }
}
```

**Protocols**:

- **Transport**: WebSocket (signaling) + UDP/SRTP (media)
- **Authentication**: JWT with VideoGrants
- **Network**: ICE candidate gathering via STUN (stun.l.google.com:19302)

**Performance**:

- **Target**: <500ms from browser connect to WebRTC established
- **Bottlenecks**: NAT traversal (ICE), DTLS handshake
- **Fallback**: TCP port 7881 if UDP blocked

---

### Phase 2: Voice Transmission (User Speaks)

**Actors**: Browser, LiveKit SFU, Python Agent Worker

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 5. User speaks into microphone                                          │
│    - Browser captures audio via WebRTC MediaStream API                  │
│    - Encodes as Opus codec (default for LiveKit)                        │
│    - Sends RTP packets over UDP to arc-daredevil:50000-50100            │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ UDP/RTP (Opus @ 48kHz)
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 6. arc-daredevil-voice (Selective Forwarding Unit - SFU)                │
│    - Receives RTP stream from user's audio track                        │
│    - Does NOT decode/transcode (SFU = routing only)                     │
│    - Forwards to all subscribed participants (agent worker)             │
│    - Applies congestion control (bandwidth estimation)                  │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ Publish event to NATS
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 7. arc-flash-pulse (NATS)                                               │
│    - Receives track published event: "agent.*.event"                    │
│    - Notifies arc-scarlett-voice that user audio is available           │
│    - Subject: "agent.voice.track_published"                             │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ Subscribe to NATS event
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 8. arc-scarlett-voice (LiveKit Agent Worker - Python)                   │
│    - Receives NATS notification about new audio track                   │
│    - Subscribes to user's audio track via LiveKit SDK                   │
│    - Receives RTP stream forwarded by Daredevil                         │
│    - Decodes Opus to PCM audio samples                                  │
└─────────────────────────────────────────────────────────────────────────┘
```

**Data Format** (RTP):

```
┌─────────────────────────────────────────────────────────────────┐
│ RTP Header (12 bytes)                                            │
├─────────────────────────────────────────────────────────────────┤
│ Opus Payload (20ms frames, ~60 bytes @ 48kHz mono)              │
└─────────────────────────────────────────────────────────────────┘
```

**Performance**:

- **Target**: <30ms jitter, <1% packet loss
- **Bandwidth**: ~24-32 kbps per audio stream (Opus)
- **Latency**: SFU forwarding adds ~5-10ms

---

### Phase 3: Speech Recognition (STT Pipeline)

**Actors**: Python Agent Worker, STT Engine, LangGraph Brain

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 9. arc-scarlett-voice (STT Processing)                                  │
│    - Accumulates PCM audio samples (VAD - Voice Activity Detection)     │
│    - Detects speech boundaries (silence detection)                      │
│    - Sends audio chunks to STT engine (e.g., Whisper, Deepgram)         │
│    - Receives transcription: "Hello, what's the weather today?"         │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ Transcription + metadata
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 10. arc-sherlock-brain (LangGraph Reasoning Engine - Python)            │
│     - Receives: {"text": "Hello, what's...", "user_id": "user-123"}     │
│     - Loads conversation context from PostgreSQL                        │
│     - Executes LangGraph state machine:                                 │
│       1. Intent classification                                          │
│       2. Entity extraction (weather, today)                             │
│       3. Tool selection (weather API)                                   │
│       4. Response generation                                            │
│     - Generates response: "The weather today is sunny and 72°F."        │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ SQL query for context
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 11. arc-oracle-sql (PostgreSQL + pgvector)                              │
│     - Stores conversation history in agents.conversations table         │
│     - Vector search for semantic context (pgvector extension)           │
│     - Returns previous 5 turns of conversation                          │
│     - Persists new turn: {user_input, agent_response, timestamp}        │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ INSERT event for analytics
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 12. arc-strange-stream (Pulsar)                                         │
│     - Receives event on topic: "persistent://arc/events/conversation"   │
│     - Stores durable event for:                                         │
│       - Analytics (user engagement, topic trends)                       │
│       - Training data collection                                        │
│       - Audit trail                                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

**Data Structures** (PostgreSQL):

```sql
-- agents.conversations table
CREATE TABLE agents.conversations (
    id UUID PRIMARY KEY,
    user_id VARCHAR(255),
    agent_id VARCHAR(255),
    turn_index INT,
    user_input TEXT,
    agent_response TEXT,
    embedding VECTOR(1536),  -- pgvector for semantic search
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Performance**:

- **STT Latency**: 100-300ms (depends on model: Whisper Tiny vs Large)
- **LangGraph Execution**: 200-500ms (LLM inference time)
- **Database Query**: <50ms (indexed queries)

---

### Phase 4: Speech Synthesis (TTS Pipeline)

**Actors**: TTS Engine, Python Agent Worker, LiveKit SFU

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 13. arc-piper-tts (Text-to-Speech Engine)                               │
│     - Receives text: "The weather today is sunny and 72°F."             │
│     - Model: en_US-lessac-medium.onnx (FOSS, low-latency)               │
│     - Generates PCM audio samples (22kHz mono)                          │
│     - Returns raw audio buffer (~1.5 seconds of speech)                 │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ PCM audio buffer
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 14. arc-scarlett-voice (Audio Publishing)                               │
│     - Encodes PCM to Opus codec                                         │
│     - Creates RTP stream                                                │
│     - Publishes audio track to LiveKit room via SDK:                    │
│       room.local_participant.publish_track(audio_track)                 │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ RTP over UDP
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 15. arc-daredevil-voice (SFU Forwarding)                                │
│     - Receives RTP stream from agent audio track                        │
│     - Forwards to user's browser (subscribed participant)               │
│     - No transcoding, just routing                                      │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ UDP/RTP (Opus)
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 16. User Browser                                                        │
│     - Receives RTP stream via WebRTC                                    │
│     - Decodes Opus to PCM                                               │
│     - Plays audio through speakers                                      │
│     - User hears: "The weather today is sunny and 72°F."                │
└─────────────────────────────────────────────────────────────────────────┘
```

**Performance**:

- **TTS Generation**: 200-400ms (Piper is optimized for speed)
- **Audio Encoding**: <10ms (Opus is fast)
- **Network Transmission**: 20-50ms (UDP, local network)

---

### Phase 5: Observability & Monitoring

**Actors**: All services, OpenTelemetry Collector, Prometheus, Loki, Jaeger

```
┌─────────────────────────────────────────────────────────────────────────┐
│ All Services (Instrumented with OTEL SDK)                               │
│ - arc-daredevil-voice (Go): Metrics, Traces                             │
│ - arc-scarlett-voice (Python): Metrics, Traces, Logs                    │
│ - arc-sherlock-brain (Python): Metrics, Traces, Logs                    │
└─────────────────────────────────────────────────────────────────────────┘
                            │
                            │ OTLP over gRPC (port 4317)
                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 17. arc-widow-otel (OpenTelemetry Collector)                            │
│     - Receives telemetry from all services                              │
│     - Processes: Batching, filtering, enrichment                        │
│     - Routes to backends:                                               │
│       - Metrics → arc-house-metrics (Prometheus)                        │
│       - Logs → arc-watson-logs (Loki)                                   │
│       - Traces → arc-columbo-traces (Jaeger)                            │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key Metrics Tracked**:

```yaml
# LiveKit SFU (arc-daredevil-voice)
- livekit_room_participants (gauge)
- livekit_track_publish_duration_seconds (histogram)
- livekit_packet_loss_percent (gauge)

# Agent Worker (arc-scarlett-voice)
- agent_stt_latency_seconds (histogram)
- agent_tts_latency_seconds (histogram)
- agent_conversation_turns_total (counter)

# LangGraph Brain (arc-sherlock-brain)
- langgraph_execution_duration_seconds (histogram)
- langgraph_llm_tokens_total (counter)
- langgraph_tool_calls_total (counter)
```

**Distributed Tracing** (Jaeger):

```
Trace: user-request-abc123
├─ Span: livekit.receive_audio (10ms)
├─ Span: scarlett.stt (250ms)
├─ Span: sherlock.reasoning (450ms)
│  ├─ Span: postgres.query_context (45ms)
│  └─ Span: llm.inference (380ms)
├─ Span: piper.tts (300ms)
└─ Span: livekit.publish_audio (8ms)

Total: 1018ms
```

---

## End-to-End Latency Budget

**Target**: <200ms from user speech end to agent speech start (P95)

| Stage                 | Component           | Target Latency | Current Tech Choice                    |
| --------------------- | ------------------- | -------------- | -------------------------------------- |
| **Voice Capture**     | Browser             | ~0ms           | WebRTC MediaStream API                 |
| **Network Upload**    | UDP/RTP             | 10-20ms        | LiveKit SFU                            |
| **SFU Forwarding**    | arc-daredevil-voice | 5-10ms         | Go (zero-copy routing)                 |
| **STT**               | Whisper/Deepgram    | 100-300ms      | **CRITICAL PATH** - Needs optimization |
| **Context Retrieval** | PostgreSQL          | <50ms          | Indexed queries + connection pooling   |
| **LLM Inference**     | LangGraph + LLM     | 200-500ms      | **CRITICAL PATH** - Consider streaming |
| **TTS**               | Piper               | 200-400ms      | **CRITICAL PATH** - Pre-warm models    |
| **Audio Encoding**    | Opus                | <10ms          | Native libraries                       |
| **Network Download**  | UDP/RTP             | 10-20ms        | LiveKit SFU                            |
| **Total**             |                     | **535-1310ms** | ⚠️ **EXCEEDS TARGET**                  |

**Optimization Strategies**:

1. **Streaming STT**: Use Deepgram streaming API (reduces wait for full utterance)
2. **LLM Streaming**: Stream LLM tokens → TTS as they arrive (don't wait for full response)
3. **TTS Chunking**: Synthesize first sentence while LLM generates rest
4. **Model Quantization**: Use INT8/GGUF quantized models for faster inference
5. **GPU Acceleration**: Deploy STT/LLM/TTS on GPU nodes

---

## Data Persistence & Archival

### Real-Time State (Redis)

- **TTL**: 5 minutes after room empty
- **Purpose**: WebRTC signaling, participant state
- **Volume**: ~1KB per participant

### Conversation History (PostgreSQL)

```sql
-- Query pattern
SELECT * FROM agents.conversations
WHERE user_id = 'user-123'
ORDER BY created_at DESC
LIMIT 5;

-- Vector similarity search
SELECT * FROM agents.conversations
ORDER BY embedding <-> '[0.1, 0.2, ...]'::vector
LIMIT 5;
```

### Event Stream (Pulsar)

- **Topic**: `persistent://arc/events/conversation`
- **Retention**: 7 days (configurable)
- **Consumers**: Analytics service, ML training pipeline

### Session Recording (Future: arc-scribe-egress)

- **Format**: WebM audio file
- **Storage**: PostgreSQL BYTEA or S3
- **Triggered**: User consent or compliance requirement

---

## Network Architecture

### Docker Networking (Current)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ arc_net (bridge network, subnet: 172.20.0.0/16)                         │
├─────────────────────────────────────────────────────────────────────────┤
│ Service           │ Internal DNS          │ External Ports              │
├───────────────────┼──────────────────────┼─────────────────────────────┤
│ arc-heimdall      │ arc-heimdall:80      │ 80, 443                     │
│ arc-daredevil     │ arc-daredevil:7880   │ 7880, 7881, 50000-50100/udp │
│ arc-sonic         │ arc-sonic:6379       │ 6379                        │
│ arc-oracle        │ arc-oracle:5432      │ 5432                        │
│ arc-flash         │ arc-flash:4222       │ 4222, 8222                  │
│ arc-strange       │ arc-strange:6650     │ 6650, 8082                  │
│ arc-widow         │ arc-widow:4317       │ 4317, 4318                  │
└───────────────────┴──────────────────────┴─────────────────────────────┘
```

**DNS Resolution**:

- Services use internal DNS names: `arc-daredevil`, `arc-sonic`, etc.
- Multiple aliases supported: `arc-sonic` = `redis` = `arc_redis`
- External access: `/etc/hosts` entry for `livekit.arc.local` → `127.0.0.1`

**Security Considerations**:

- ⚠️ **Current**: All ports exposed for development
- ✅ **Production**: Only port 80/443 on Traefik should be public
- ✅ **Future**: Use `docker-compose.production.yml` to remove port mappings

---

## Error Handling & Resilience

### WebRTC Connection Failures

**Scenario**: User behind restrictive firewall, UDP blocked

```
User Browser
    │ 1. Try UDP (STUN)
    ├─X─> FAILED (firewall)
    │ 2. Try TCP (port 7881)
    ├───> SUCCESS
    └─> Fallback to TCP transport (higher latency)
```

**Config** (`livekit.yaml`):

```yaml
rtc:
  tcp_port: 7881 # TCP fallback
  stun_servers:
    - stun.l.google.com:19302
  # Future: Add TURN server for relay
  # turn:
  #   enabled: true
  #   domain: turn.arc.example.com
```

### Service Failures

| Failure                        | Impact                   | Mitigation                          |
| ------------------------------ | ------------------------ | ----------------------------------- |
| **arc-sonic (Redis) down**     | LiveKit can't sync state | ✅ Health check prevents startup    |
| **arc-oracle (Postgres) down** | No conversation history  | ⚠️ Agent continues (stateless mode) |
| **arc-sherlock (LLM) down**    | No intelligent responses | ⚠️ Fallback to canned responses     |
| **arc-piper (TTS) down**       | No voice output          | ⚠️ Return text to user              |

### Chaos Engineering (Future)

**arc-terminator-chaos** tests:

- Random pod kills (Kubernetes)
- Network latency injection (50ms, 100ms, 500ms)
- Packet loss simulation (1%, 5%, 10%)
- Redis failover scenarios

---

## Security & Authentication Flow

### JWT Token Generation (Backend Service)

```python
from livekit import api

def create_room_token(user_id: str, room_name: str) -> str:
    token = api.AccessToken(
        api_key=os.getenv("LIVEKIT_API_KEY"),
        api_secret=os.getenv("LIVEKIT_API_SECRET")
    )
    token.with_identity(user_id)
    token.with_name(user_id)
    token.with_grants(api.VideoGrants(
        room_join=True,
        room=room_name,
        can_publish=True,
        can_subscribe=True
    ))
    return token.to_jwt()
```

### Token Validation (LiveKit Server)

```
User Browser
    │ 1. Call backend API: POST /api/rooms/join
    ├───> Backend generates JWT token
    │ 2. Receives: {"token": "eyJhbG...", "url": "wss://livekit.arc.local"}
    │ 3. Connect to LiveKit with token
    └───> LiveKit validates signature with LIVEKIT_API_SECRET
```

**Security Properties**:

- **Expiration**: Tokens expire after 1 hour (configurable)
- **Room Isolation**: User can only join specified room
- **Permissions**: Granular (publish/subscribe/admin)
- **Replay Protection**: Token includes `jti` (JWT ID) and `nbf` (not before)

---

## Service Dependencies Graph

```
┌─────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: INFRASTRUCTURE (Go)                                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  arc-heimdall ──► arc-daredevil ──► arc-sonic                           │
│      │                 │                │                                │
│      │                 │                └──► (Redis state sync)          │
│      │                 │                                                 │
│      │                 └──► arc-widow ──► Prometheus/Loki/Jaeger         │
│      │                                                                   │
│      └──► arc-flash (NATS) ◄──┐                                         │
│      └──► arc-strange (Pulsar) ◄─┐                                      │
│                                   │                                      │
└───────────────────────────────────┼──────────────────────────────────────┘
                                    │
┌───────────────────────────────────┼──────────────────────────────────────┐
│ LAYER 2: INTELLIGENCE (Python)    │                                      │
├───────────────────────────────────┼──────────────────────────────────────┤
│                                   │                                      │
│  arc-scarlett ──► arc-sherlock ──┼──► arc-oracle (PostgreSQL)           │
│       │               │           │                                      │
│       │               │           └──► Event publishing                  │
│       │               │                                                  │
│       └──► arc-piper (TTS)                                               │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

**Startup Order** (Docker Compose `depends_on`):

1. `arc-oracle` (PostgreSQL) - No dependencies
2. `arc-sonic` (Redis) - No dependencies
3. `arc-widow` (OTEL) - No dependencies
4. `arc-heimdall` (Traefik) - No dependencies
5. `arc-flash`, `arc-strange` - Depend on `arc-widow`
6. `arc-daredevil` - Depends on `arc-sonic`, `arc-widow`
7. `arc-sherlock` - Depends on `arc-oracle`
8. `arc-scarlett` - Depends on `arc-daredevil`, `arc-sherlock`, `arc-piper`

---

## Configuration Management

### Environment Variables (`.env`)

```bash
# Core Infrastructure
POSTGRES_USER=arc
POSTGRES_PASSWORD=<generated-by-make-generate-secrets>
POSTGRES_DB=arc_db
REDIS_PASSWORD=<generated-by-make-generate-secrets>

# LiveKit
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=<generated-by-openssl>
LIVEKIT_NODE_IP=127.0.0.1

# Observability
OTEL_EXPORTER_OTLP_ENDPOINT=http://arc-widow:4317

# Agent Configuration (Future)
LANGGRAPH_API_URL=http://arc-sherlock:8000
PIPER_MODEL_PATH=/models/en_US-lessac-medium.onnx
```

### Service-Specific Configs

| Service         | Config File                                | Mount Path                     | Format |
| --------------- | ------------------------------------------ | ------------------------------ | ------ |
| `arc-daredevil` | `core/media/livekit/livekit.yaml`          | `/etc/livekit.yaml`            | YAML   |
| `arc-heimdall`  | `core/gateway/traefik/traefik.yml`         | `/etc/traefik/traefik.yml`     | YAML   |
| `arc-widow`     | `core/telemetry/otel-collector-config.yml` | `/etc/otelcol/config.yaml`     | YAML   |
| `arc-oracle`    | `core/persistence/postgres/init.sql`       | `/docker-entrypoint-initdb.d/` | SQL    |

---

## Data Volume Estimates

### Per Conversation Turn

| Data Type          | Size                       | Storage               |
| ------------------ | -------------------------- | --------------------- |
| User audio (5 sec) | ~15 KB (Opus)              | Ephemeral (RTP)       |
| Transcription      | ~100 bytes                 | PostgreSQL            |
| LLM response       | ~200 bytes                 | PostgreSQL            |
| Embedding vector   | 6 KB (1536 dims × 4 bytes) | PostgreSQL (pgvector) |
| Event metadata     | ~500 bytes                 | Pulsar                |
| **Total per turn** | **~6.8 KB**                |                       |

### Daily Volume (1000 active users, 20 turns/day)

```
1000 users × 20 turns/day × 6.8 KB = 136 MB/day
Annual: 136 MB × 365 = ~50 GB/year
```

**Storage Breakdown**:

- **PostgreSQL**: 50 GB/year (conversations + vectors)
- **Pulsar**: 7-day retention = ~950 MB
- **Redis**: <100 MB (transient state)
- **Session Recordings**: (Optional) ~500 MB/day if all recorded

---

## Performance Monitoring Dashboard (Proposed)

### Key Metrics (Grafana)

**Panel 1: End-to-End Latency**

```promql
histogram_quantile(0.95,
  sum(rate(agent_e2e_latency_seconds_bucket[5m])) by (le)
)
```

Target: <200ms (P95)

**Panel 2: Service Health**

```promql
up{job=~"arc-.*"}
```

Target: 1 (all services up)

**Panel 3: WebRTC Quality**

```promql
livekit_packet_loss_percent
livekit_jitter_seconds
```

Target: <1% loss, <30ms jitter

**Panel 4: Agent Performance**

```promql
rate(agent_conversation_turns_total[5m])
```

Shows throughput (turns/second)

---

## Migration Path: Current → Full Implementation

### ✅ Phase 1: Infrastructure (COMPLETE)

**Status**: All Go-based core services deployed and healthy

- [x] `arc-heimdall-gateway` routing to `livekit.arc.local`
- [x] `arc-daredevil-voice` accepting WebRTC connections
- [x] `arc-sonic-cache` syncing LiveKit room state
- [x] `arc-oracle-sql` with pgvector extension enabled
- [x] `arc-flash-pulse` (NATS) and `arc-strange-stream` (Pulsar) ready
- [x] `arc-widow-otel` collecting metrics from all services

**Validation**:

```bash
make health-all
curl http://localhost:7880/metrics  # LiveKit metrics endpoint
```

### 🚧 Phase 2: Agent Core (IN PROGRESS - ADR-001)

**Goal**: Implement Python services for voice intelligence

**Tasks**:

1. Create `services/arc-scarlett-voice/` (Python + LiveKit Agents SDK)

   - Subscribe to LiveKit audio tracks
   - Implement STT pipeline (Whisper or Deepgram)
   - Publish TTS audio back to room

2. Create `services/arc-sherlock-brain/` (Python + LangGraph)

   - FastAPI server for agent logic
   - LangGraph state machine for conversation flow
   - Integration with LLM (OpenAI/Anthropic/local)

3. Create `services/arc-piper-tts/` (Piper deployment)

   - ONNX model serving
   - HTTP API for text → audio conversion

4. Add to `docker-compose.services.yml`:
   ```yaml
   arc-scarlett:
     build: ./services/arc-scarlett-voice
     environment:
       LIVEKIT_URL: ws://arc-daredevil:7880
       LANGGRAPH_API_URL: http://arc-sherlock:8000
     depends_on:
       - arc-daredevil
       - arc-sherlock
   ```

### 🔮 Phase 3: Observability & Sidecars (FUTURE)

**Goals**:

- Session recording and playback
- External ingress (RTMP/SIP)
- Advanced analytics and monitoring

**Services**:

- `arc-scribe-egress` (LiveKit Egress for recording)
- `arc-sentry-ingress` (LiveKit Ingress for external sources)
- Custom Grafana dashboards for voice metrics

---

## Appendix: Reference Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          USER INTERFACE LAYER                            │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Browser (WebRTC Client)                                         │   │
│  │  - Microphone capture                                            │   │
│  │  - Speaker output                                                │   │
│  │  - WebSocket signaling                                           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                            │ ▲
                            │ │ wss://livekit.arc.local
                            │ │ UDP/SRTP (ports 50000-50100)
                            ▼ │
┌─────────────────────────────────────────────────────────────────────────┐
│                        GATEWAY LAYER (Go)                                │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  arc-heimdall-gateway (Traefik)                                  │   │
│  │  - Host-based routing                                            │   │
│  │  - TLS termination                                               │   │
│  │  - Rate limiting                                                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                            │ ▲
                            ▼ │
┌─────────────────────────────────────────────────────────────────────────┐
│                        MEDIA LAYER (Go)                                  │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  arc-daredevil-voice (LiveKit SFU)                               │   │
│  │  - WebRTC signaling                                              │   │
│  │  - Selective forwarding (SFU)                                    │   │
│  │  - No transcoding                                                │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                            │ ▲                                           │
│                            ▼ │                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  arc-sonic-cache (Redis)                                         │   │
│  │  - Room state sync                                               │   │
│  │  - Participant metadata                                          │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                            │ ▲
                            │ │ RTP audio streams
                            ▼ │
┌─────────────────────────────────────────────────────────────────────────┐
│                      AGENT LAYER (Python)                                │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  arc-scarlett-voice (LiveKit Agent Worker)                       │   │
│  │  ┌────────────┐   ┌────────────┐   ┌────────────┐                │   │
│  │  │    STT     │──►│ LangGraph  │──►│    TTS     │                │   │
│  │  │  (Whisper) │   │  Pipeline  │   │  (Piper)   │                │   │
│  │  └────────────┘   └────────────┘   └────────────┘                │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                            │ ▲                                           │
│                            ▼ │                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  arc-sherlock-brain (LangGraph Reasoning Engine)                 │   │
│  │  - Intent classification                                         │   │
│  │  - Tool orchestration                                            │   │
│  │  - Response generation                                           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                            │ ▲
                            ▼ │
┌─────────────────────────────────────────────────────────────────────────┐
│                      PERSISTENCE LAYER                                   │
│  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐    │
│  │  arc-oracle-sql  │   │  arc-flash-pulse │   │ arc-strange-     │    │
│  │   (PostgreSQL)   │   │      (NATS)      │   │  stream (Pulsar) │    │
│  │                  │   │                  │   │                  │    │
│  │ - Conversations  │   │ - Agent events   │   │ - Event archive  │    │
│  │ - Vector search  │   │ - Commands       │   │ - Analytics      │    │
│  └──────────────────┘   └──────────────────┘   └──────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                            │ ▲
                            ▼ │
┌─────────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY LAYER                                   │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  arc-widow-otel (OpenTelemetry Collector)                        │   │
│  │     │            │             │                                  │   │
│  │     ▼            ▼             ▼                                  │   │
│  │  Prometheus    Loki         Jaeger                               │   │
│  │  (Metrics)    (Logs)       (Traces)                              │   │
│  │     │            │             │                                  │   │
│  │     └────────────┴─────────────┘                                 │   │
│  │                  │                                                │   │
│  │                  ▼                                                │   │
│  │          Grafana Dashboards                                      │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Summary: Key Architectural Decisions

| Decision            | Rationale                                | Trade-off                                        |
| ------------------- | ---------------------------------------- | ------------------------------------------------ |
| **LiveKit SFU**     | Industry-standard WebRTC, Go performance | Learning curve for WebRTC debugging              |
| **Redis for state** | LiveKit requirement, enables multi-node  | Single point of failure (mitigate with Sentinel) |
| **Polyglot stack**  | Go for transport, Python for AI          | Operational complexity (2 runtimes)              |
| **Piper TTS**       | FOSS, low-latency, CPU-friendly          | Voice quality lower than cloud TTS               |
| **pgvector**        | Semantic search in same DB as data       | Limited to PostgreSQL, not specialized vector DB |
| **NATS + Pulsar**   | NATS for ephemeral, Pulsar for durable   | Two messaging systems to maintain                |
| **OpenTelemetry**   | Vendor-neutral, future-proof             | More complex than single-vendor APM              |

---

## Next Steps

### For Implementation Team

1. **Read ADR-001** thoroughly to understand the full Daredevil stack design
2. **Verify infrastructure** with `make health-all` and test LiveKit connectivity
3. **Implement Phase 2** services following the polyglot standards:

   - `arc-scarlett-voice` in Python with LiveKit Agents SDK
   - `arc-sherlock-brain` in Python with LangGraph
   - `arc-piper-tts` deployment

4. **Test end-to-end flow**:

   - User connects to LiveKit room
   - Speaks into microphone
   - Agent processes via STT → LLM → TTS
   - User hears response within 500ms (initial target)

5. **Optimize latency** using strategies in "End-to-End Latency Budget" section

### For DevOps Team

1. **Configure DNS** for production domains (replace `livekit.arc.local`)
2. **Set up TURN server** for NAT traversal in restrictive networks
3. **Implement port security** using `docker-compose.production.yml`
4. **Deploy Grafana dashboards** for real-time monitoring
5. **Set up alerting** for SLO violations (latency > 500ms, packet loss > 1%)

---

**END OF ANALYSIS DOCUMENT**

_This document provides a comprehensive overview of the data flow without any code implementation, as requested._
