# ADR-001: The A.R.C. Daredevil Real-Time Stack

**The Central Nervous System for Agentic Intelligence**

**Status:** ✅ APPROVED / FINAL  
**Date:** 2025-12-13  
**Author:** A.R.C. Architect  
**Layer:** Core Infrastructure + Agent Services

---

## 1. Executive Summary: Stop Being Slow, Dude

A.R.C. is a **voice-first platform**. A slow platform is a failed platform. The old world of text-based, HTTP request/response is dead. Our agents must process and reply in **sub-200ms** to achieve human-like conversation (the "Her" interface).

The **Daredevil Stack** is the dedicated, high-performance media layer built on **LiveKit**. This is a **Go-based core** that handles the non-negotiable WebRTC plumbing so the Python/LangGraph core can focus on the thinking.

> **WARNING:** If you try to run any of this logic over a REST endpoint, I will personally throttle your container and blame your slow response time.

---

## 2. Context & Problem Statement

### The Problem

Traditional HTTP-based voice interfaces are dead on arrival:

- **Latency:** Round-trip time for HTTP request/response adds 100-300ms minimum
- **Scalability:** Opening a new HTTP connection per audio chunk is insane
- **Reliability:** TCP/HTTP is terrible for real-time media (packet loss = stalls)
- **User Experience:** Humans expect <200ms response time for natural conversation

### The Requirement

We need:

1. **WebRTC transport** for low-latency, UDP-based media streaming
2. **Selective Forwarding Unit (SFU)** architecture for efficient multi-party routing
3. **Go-based control plane** for high-performance signaling and state management
4. **Python-based agent workers** that can focus on AI logic, not transport

---

## 3. Decision

We adopt **LiveKit** as the core real-time media server and build the **Daredevil Stack** with the following components:

| Component            | A.R.C. Codename        | Technology                              | Role                                               |
| -------------------- | ---------------------- | --------------------------------------- | -------------------------------------------------- |
| **Media Server**     | `arc-daredevil-voice`  | Go (LiveKit Server)                     | SFU for WebRTC media routing, uses Redis for state |
| **Agent Worker**     | `arc-scarlett-voice`   | Python (LiveKit Agents SDK + LangGraph) | AI agent that joins rooms, listens, thinks, speaks |
| **Archival Service** | `arc-scribe-egress`    | LiveKit Egress Sidecar                  | Records sessions to PostgreSQL/pgvector            |
| **Ingress Service**  | `arc-sentry-ingress`   | LiveKit Ingress Sidecar                 | Converts RTMP/SIP to LiveKit rooms                 |
| **Cache**            | `arc-sonic-cache`      | Redis                                   | Required for Daredevil's room/participant state    |
| **TTS Engine**       | `arc-piper-tts`        | Piper (FOSS)                            | Low-latency voice synthesis                        |
| **Gateway**          | `arc-heimdall-gateway` | Traefik                                 | Routes WebSocket signaling to Daredevil            |

---

## 4. Architecture Flow (The Polyglot Dance)

This enforces our **Polyglot Two-Brain Architecture**: Go for transport/control, Python for intelligence.

```mermaid
graph LR
    subgraph Core Infra (Go/Traefik)
        A[User UI (Browser)]
        B[arc-heimdall-gateway (Traefik)]
        C[arc-daredevil-voice (LiveKit/Go SFU)]
        D[arc-sonic-cache (Redis)]
    end

    subgraph Agent Core (Python/LangGraph)
        E[arc-scarlett-voice (LiveKit Agent SDK)]
        F[arc-sherlock-brain (LangGraph/Python)]
        G[arc-piper-tts (TTS Engine)]
    end

    subgraph Sidecar Services (Go/Egress/Ingress)
        H[arc-scribe-egress (LiveKit Egress)]
        I[arc-sentry-ingress (LiveKit Ingress)]
    end

    J[arc-oracle-sql (PostgreSQL/pgvector)]

    A -- wss:// Signalling --> B
    B -- Host(livekit.arc.local) Route --> C
    A -- UDP/SRTP Media Transport --> C
    C -- Pub/Sub State Management --> D
    E -- Subscribe to Audio Track --> C
    E -- STT/Transcription --> F
    F -- Generate Text Response --> E
    E -- TTS via Piper --> G
    G -- Publish Audio Track --> C
    C -- Archival Request --> H
    H -- Archive Output --> J
    I -- RTMP/SIP Ingress --> C
```

### Flow Breakdown

1. **User Connects:** Browser establishes WebSocket connection to `wss://livekit.arc.local`
2. **Traefik Routes:** `arc-heimdall-gateway` routes to `arc-daredevil-voice` based on Host header
3. **WebRTC Setup:** Daredevil negotiates ICE/DTLS and establishes UDP media channels
4. **State Sync:** Daredevil uses `arc-sonic-cache` (Redis) for distributed room state
5. **Agent Joins:** `arc-scarlett-voice` subscribes to user's audio track
6. **Intelligence Loop:** Scarlett → STT → `arc-sherlock-brain` (LangGraph) → TTS (Piper)
7. **Response:** Scarlett publishes audio track back to room, Daredevil forwards to user
8. **Archival:** `arc-scribe-egress` records session to PostgreSQL when requested

---

## 5. Technical Specifications

### 5.1 Port Mappings (Critical for WebRTC)

| Service               | Protocol | Host Port   | Container Port | Purpose                        |
| --------------------- | -------- | ----------- | -------------- | ------------------------------ |
| `arc-daredevil-voice` | TCP      | 7880        | 7880           | HTTP API & WebSocket signaling |
| `arc-daredevil-voice` | UDP      | 50000-60000 | 50000-60000    | WebRTC media (RTP/RTCP)        |
| `arc-sonic-cache`     | TCP      | 6379        | 6379           | Redis state sync               |

### 5.2 Environment Variables

```bash
# Daredevil (LiveKit Server)
LIVEKIT_KEYS="api_key:secret_key"
REDIS_URL="redis://arc-sonic-cache:6379"
LIVEKIT_CONFIG="/etc/livekit.yaml"

# Scarlett (Agent Worker)
LIVEKIT_URL="ws://arc-daredevil-voice:7880"
LIVEKIT_API_KEY="api_key"
LIVEKIT_API_SECRET="secret_key"
LANGGRAPH_API_URL="http://arc-sherlock-brain:8000"
PIPER_MODEL_PATH="/models/en_US-lessac-medium.onnx"
```

### 5.3 LiveKit Server Configuration (`livekit.yaml`)

```yaml
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true # Critical for local dev
  tcp_port: 7881

redis:
  address: arc-sonic-cache:6379

keys:
  api_key: ${LIVEKIT_API_KEY}
  secret_key: ${LIVEKIT_API_SECRET}

logging:
  level: info

room:
  auto_create: true
  empty_timeout: 300 # 5 minutes
  max_participants: 10
```

---

## 6. Performance Requirements

| Metric                  | Target | Measurement                        |
| ----------------------- | ------ | ---------------------------------- |
| **End-to-End Latency**  | <200ms | User speech → Agent response (P95) |
| **WebRTC Jitter**       | <30ms  | UDP packet variance                |
| **Packet Loss**         | <1%    | RTP stream quality                 |
| **Room Join Time**      | <500ms | WebSocket connect → ICE complete   |
| **Agent Response Time** | <500ms | STT → LLM → TTS pipeline           |

---

## 7. Consequences

### Positive

✅ **Sub-200ms latency** achievable with WebRTC + UDP transport  
✅ **Scalable architecture** - SFU scales to hundreds of concurrent rooms  
✅ **Polyglot separation** - Go handles transport, Python handles intelligence  
✅ **Standards-based** - WebRTC is universally supported in browsers  
✅ **FOSS stack** - LiveKit, Piper, Redis all open-source

### Negative

⚠️ **Complexity** - WebRTC is notoriously difficult to debug (ICE, STUN, TURN)  
⚠️ **Network requirements** - UDP ports must be open (50000-60000)  
⚠️ **Local dev challenges** - Requires proper DNS/host configuration for `livekit.arc.local`  
⚠️ **Python dependency** - Agent workers must use LiveKit Agents SDK (no alternatives)

### Risks & Mitigations

| Risk                              | Mitigation                                      |
| --------------------------------- | ----------------------------------------------- |
| **NAT traversal fails**           | Deploy TURN server (Coturn) for relay fallback  |
| **Redis single point of failure** | Use Redis Sentinel for HA in production         |
| **Agent worker crashes**          | Implement supervisor pattern with health checks |
| **TTS latency spikes**            | Pre-warm Piper models, use GPU acceleration     |

---

## 8. Implementation Phases

### Phase 1: Go Infrastructure (The Body) ✅

**Goal:** Deploy Daredevil and get WebRTC working

- [ ] Deploy `arc-daredevil-voice` container with LiveKit Server
- [ ] Configure `arc-sonic-cache` (Redis) connection
- [ ] Set up UDP port mappings (50000-60000) for WebRTC
- [ ] Update `arc-heimdall-gateway` (Traefik) to route `livekit.arc.local`
- [ ] Verify OTEL logs collection and Prometheus metrics scraping

**Validation:** Browser can establish WebRTC connection and see room state

### Phase 2: Python Agent Core (The Mind) 🔄

**Goal:** Make Scarlett capable of real-time conversation

- [ ] Create `arc-scarlett-voice` service with LiveKit Agents SDK
- [ ] Implement: LiveKit Stream → STT → LangGraph → TTS → LiveKit Publish
- [ ] Build Go Management SDK for room creation and token minting
- [ ] Deploy `arc-piper-tts` for voice synthesis
- [ ] Write end-to-end test: User → Scarlett → Response (<500ms)

**Validation:** Agent successfully replies to user voice input within latency budget

### Phase 3: Observability & Sidecars 🚧

**Goal:** Production-ready logging, archival, and ingress

- [ ] Deploy `arc-scribe-egress` for session recording to PostgreSQL
- [ ] Deploy `arc-sentry-ingress` for RTMP/SIP external sources
- [ ] Configure Grafana dashboards for LiveKit metrics
- [ ] Set up distributed tracing for agent pipeline
- [ ] Implement chaos testing with `arc-terminator-chaos`

**Validation:** Can replay recorded sessions and monitor system health

---

## 9. References

- [LiveKit Documentation](https://docs.livekit.io/)
- [LiveKit Agents SDK (Python)](https://github.com/livekit/agents)
- [WebRTC Standards (IETF)](https://www.w3.org/TR/webrtc/)
- [Piper TTS](https://github.com/rhasspy/piper)
- [A.R.C. Polyglot Standards](../../.github/instructions/copilot.instructions.md)

---

## 10. Appendix: Service Interaction Protocol

### Token Generation (Go SDK)

```go
// libs/go-sdk/livekit/token.go
func CreateRoomToken(roomName, participantName string) (string, error) {
    at := auth.NewAccessToken(apiKey, apiSecret)
    grant := &auth.VideoGrant{
        RoomJoin: true,
        Room:     roomName,
    }
    at.AddGrant(grant).SetIdentity(participantName)
    return at.ToJWT()
}
```

### Agent Worker Entry (Python)

```python
# services/arc-scarlett-voice/agent.py
from livekit import agents, rtc
from livekit.agents import JobContext

@agents.job_handler()
async def entrypoint(ctx: JobContext):
    await ctx.connect()
    participant = await ctx.wait_for_participant()

    # Subscribe to user audio
    audio_track = participant.audio_tracks[0]

    # Pipeline: STT → LangGraph → TTS
    async for transcription in stt_pipeline(audio_track):
        response = await langgraph_call(transcription)
        audio = await piper_tts(response)
        await ctx.room.local_participant.publish_track(audio)
```

---

**END OF ADR-001**
