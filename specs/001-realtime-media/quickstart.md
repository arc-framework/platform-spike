# Phase 3D Quickstart: Hybrid Voice Agent

**Goal**: Get the arc-sherlock-brain (LangGraph reasoning) + arc-scarlett-voice (LiveKit agent) stack running locally for voice-based AI conversations.

**Target Latency**: <1000ms P95 (Phase 3D baseline)

---

## Prerequisites

- Docker & Docker Compose installed
- Ollama installed locally (for LLM inference)
- At least 8GB RAM available
- Git clone of `platform-spike` repository

---

## Setup Steps

### 1. Start Ollama and Pull Model

Ollama runs on your host machine (not in Docker) to avoid GPU passthrough complexity.

```bash
# Install Ollama (if not already installed)
# macOS:
brew install ollama

# Linux:
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama server
ollama serve

# Pull Mistral 7B model (in a new terminal)
ollama pull mistral:7b
```

**Verify Ollama is running:**

```bash
curl http://localhost:11434/api/tags
# Should return JSON with "mistral:7b" in models list
```

---

### 2. Configure Environment

```bash
cd /path/to/platform-spike

# Copy environment template
cp .env.example .env

# Edit .env and set these values:
# LIVEKIT_API_KEY=devkey
# LIVEKIT_API_SECRET=your_secret_here  # Generate with: openssl rand -base64 32
# POSTGRES_PASSWORD=your_db_password   # Generate with: openssl rand -base64 32
# LLM_BASE_URL=http://host.docker.internal:11434  # Already set
# LLM_MODEL=mistral:7b  # Already set
```

---

### 3. Start Core Infrastructure

Start PostgreSQL, NATS, and OpenTelemetry collector:

```bash
docker compose -f deployments/docker/docker-compose.core.yml up -d
docker compose -f deployments/docker/docker-compose.observability.yml up -d
```

**Verify core services:**

```bash
# PostgreSQL
docker exec arc-oracle-sql pg_isready
# Should output: /var/run/postgresql:5432 - accepting connections

# NATS
docker exec arc-flash-pulse nats-server -v
# Should output version info

# OTEL Collector
curl http://localhost:13133/health/live
# Should return: {"status":"Server available"}
```

---

### 4. Initialize Database Schema

Run the SQL migration to create the `agents.conversations` table:

```bash
docker exec -i arc-oracle-sql psql -U arc -d arc <<EOF
CREATE SCHEMA IF NOT EXISTS agents;

CREATE TABLE IF NOT EXISTS agents.conversations (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    text TEXT NOT NULL,
    embedding VECTOR(384) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON agents.conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_embedding ON agents.conversations USING ivfflat (embedding vector_l2_ops);
EOF
```

**Verify schema:**

```bash
docker exec arc-oracle-sql psql -U arc -d arc -c "\dt agents.*"
# Should list "agents.conversations" table
```

---

### 5. Start LiveKit Media Server

```bash
docker compose -f deployments/docker/docker-compose.services.yml up -d arc-daredevil-voice
```

**Verify LiveKit:**

```bash
curl http://localhost:7880/health
# Should return 200 OK
```

---

### 6. Start arc-sherlock-brain (Reasoning Engine)

```bash
docker compose -f deployments/docker/docker-compose.services.yml up -d arc-sherlock-brain
```

**Check logs:**

```bash
docker logs arc-sherlock-brain --tail=50
# Look for:
# - "database.initialized"
# - "graph.initialized"
# - "nats.connected"
# - "brain.startup_complete"
```

**Test FastAPI endpoint:**

```bash
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test_user","text":"Hello, who are you?"}'

# Expected response:
# {
#   "user_id": "test_user",
#   "text": "I am Sherlock, an AI reasoning assistant...",
#   "latency_ms": 650
# }
```

---

### 7. Start arc-scarlett-voice (Voice Agent)

```bash
docker compose -f deployments/docker/docker-compose.services.yml up -d arc-scarlett-voice
```

**Check logs:**

```bash
docker logs arc-scarlett-voice --tail=50
# Look for:
# - "piper_tts.model_loaded"
# - "sherlock_llm.nats_connected"
# - "agent.plugins_initialized"
# - "agent.worker_start"
```

---

### 8. Test End-to-End Voice Flow

#### Option A: Use LiveKit CLI (Recommended)

```bash
# Install LiveKit CLI
brew install livekit-cli  # macOS
# OR
go install github.com/livekit/livekit-cli@latest

# Join a test room
livekit-cli join-room \
  --url ws://localhost:7880 \
  --api-key devkey \
  --api-secret YOUR_SECRET_HERE \
  --room test-room \
  --identity test-user

# Speak into your microphone
# Expected flow:
# 1. Your voice → Whisper STT → text appears in logs
# 2. Text → NATS → arc-sherlock-brain → response generated
# 3. Response → Piper TTS → audio plays back
```

#### Option B: Use Python Test Script

```bash
# Install test dependencies
pip install livekit-api livekit

# Run test script (TODO: create test script in tests/integration/)
python tests/integration/test_voice_agent_full.py
```

---

## Verify Data Flow

### 1. Check Database Persistence

```bash
docker exec arc-oracle-sql psql -U arc -d arc -c \
  "SELECT user_id, text, created_at FROM agents.conversations ORDER BY created_at DESC LIMIT 5;"

# Should show your conversation history
```

### 2. Inspect NATS Messages

```bash
# Subscribe to brain requests
docker exec arc-flash-pulse nats sub "brain.request"

# In another terminal, send test request via FastAPI
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"user_id":"nats_test","text":"Test NATS integration"}'

# Should see JSON payload in NATS subscriber
```

### 3. View Traces in Jaeger

```bash
# Open Jaeger UI
open http://localhost:16686

# Search for traces:
# - Service: arc-sherlock-brain
# - Operation: POST /chat
# - Look for spans: retrieve_context → generate_response
```

---

## Troubleshooting

### Sherlock Brain Not Connecting to Ollama

**Symptom**: `LLM connection error` in logs

**Solution**:

```bash
# Verify Ollama is accessible from Docker
docker run --rm curlimages/curl:latest curl http://host.docker.internal:11434/api/tags

# If fails on Linux, add to docker-compose.services.yml:
# extra_hosts:
#   - "host.docker.internal:host-gateway"
```

### NATS Connection Timeout

**Symptom**: `nats.connect_error` in logs

**Solution**:

```bash
# Check NATS is running
docker ps | grep arc-flash-pulse

# Restart NATS if needed
docker restart arc-flash-pulse

# Verify network
docker network inspect arc_net | grep -A 10 "arc-flash-pulse"
```

### Piper Model Not Found

**Symptom**: `FileNotFoundError: Piper model not found`

**Solution**:

```bash
# Download model manually
docker exec arc-scarlett-voice sh -c '
wget -q -O /app/models/en_US-lessac-medium.onnx \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx

wget -q -O /app/models/en_US-lessac-medium.onnx.json \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
'

# Restart agent
docker restart arc-scarlett-voice
```

### High Latency (>1500ms)

**Check component latencies:**

```bash
# View metrics in Grafana
open http://localhost:3000
# Login: admin / (from .env)
# Dashboard: A.R.C. Voice Agent Performance

# Expected component latencies (P95):
# - Whisper STT: 200-400ms
# - NATS overhead: 1-5ms
# - Sherlock brain: 400-1200ms
# - Piper TTS: 100-300ms
# - Total: <1000ms
```

**If Sherlock latency is high (>1500ms):**

- Check Ollama CPU usage: `ollama ps`
- Consider switching to smaller model: `ollama pull mistral:7b-instruct`
- Reduce context retrieval: Edit `graph.py` to use `top_k=3` instead of 5

---

## Next Steps (Phase 4)

Once Phase 3D is working:

1. **Optimize latency**: Implement streaming LLM responses (target <500ms P95)
2. **Add interruption handling**: Enhanced VAD with backchanneling
3. **Scale testing**: Load test with 10+ concurrent conversations
4. **Production hardening**: Add retry logic, circuit breakers, health monitoring

See `specs/001-realtime-media/plan.md` for full Phase 4 roadmap.

---

## Quick Reference

| Service        | Port  | URL                    | Purpose                    |
| -------------- | ----- | ---------------------- | -------------------------- |
| LiveKit SFU    | 7880  | ws://localhost:7880    | WebRTC media server        |
| Sherlock Brain | 8000  | http://localhost:8000  | FastAPI REST + NATS worker |
| PostgreSQL     | 5432  | localhost:5432         | Conversation persistence   |
| NATS           | 4222  | nats://localhost:4222  | Messaging bus              |
| Jaeger UI      | 16686 | http://localhost:16686 | Distributed tracing        |
| Grafana        | 3000  | http://localhost:3000  | Metrics visualization      |
| Ollama         | 11434 | http://localhost:11434 | LLM inference              |

---

**Status**: Phase 3D implementation complete ✓  
**Last Updated**: 2025-01-11
