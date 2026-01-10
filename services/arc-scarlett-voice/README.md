# arc-scarlett-voice

**LiveKit Voice Agent with Hybrid Architecture**

arc-scarlett-voice is the real-time voice interface for the A.R.C. Framework, powered by LiveKit Agents SDK. It orchestrates speech-to-text (Whisper), reasoning (via arc-sherlock-brain over NATS), and text-to-speech (embedded Piper) in a low-latency pipeline.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    arc-scarlett-voice                           │
│                  (LiveKit VoicePipelineAgent)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │
│  │  Whisper    │   │  Sherlock   │   │   Piper     │          │
│  │  STT Plugin │──▶│ LLM Plugin  │──▶│ TTS Plugin  │          │
│  │ (Embedded)  │   │ (NATS Call) │   │ (Embedded)  │          │
│  └─────────────┘   └─────────────┘   └─────────────┘          │
│                         │                                       │
│                         ▼                                       │
│                  ┌─────────────┐                                │
│                  │ NATS Client │                                │
│                  └─────────────┘                                │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                    arc-sherlock-brain
                  (LangGraph + pgvector)
```

## Features

- **100% Open-Source Stack**: No cloud APIs (Whisper, local LLM via Sherlock, Piper TTS)
- **Low-Latency VAD**: Silero voice activity detection for interruption handling
- **Hybrid Reasoning**: Offloads complex LLM calls to arc-sherlock-brain via NATS
- **Embedded TTS**: Piper ONNX models run in-process (no network overhead)
- **OpenTelemetry**: Full observability with traces, metrics, and structured logging

## Data Flow

1. **User speaks** → LiveKit SFU → arc-scarlett-voice
2. **Whisper STT** → transcribed text (200-400ms)
3. **NATS Request** → `brain.request` subject → arc-sherlock-brain (400-1200ms)
4. **LangGraph Response** → NATS reply → arc-scarlett-voice
5. **Piper TTS** → synthesized audio (100-300ms)
6. **Audio sent** → LiveKit SFU → User hears response

**Target Latency**: <1000ms P95 (Phase 3D), <500ms P95 (Phase 4 optimized)

## Environment Variables

| Variable                      | Description                              | Default                            |
| ----------------------------- | ---------------------------------------- | ---------------------------------- |
| `LIVEKIT_URL`                 | LiveKit server WebSocket URL             | `ws://arc-daredevil-voice:7880`    |
| `LIVEKIT_API_KEY`             | LiveKit API key                          | (required)                         |
| `LIVEKIT_API_SECRET`          | LiveKit API secret                       | (required)                         |
| `NATS_URL`                    | NATS server URL for brain calls          | `nats://arc-flash-pulse:4222`      |
| `WHISPER_MODEL`               | Whisper model size (base, small, medium) | `base`                             |
| `PIPER_MODEL_PATH`            | Path to Piper ONNX model                 | `/models/en_US-lessac-medium.onnx` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint                  | `http://arc-widow-otel:4317`       |

## Installation

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Download Piper Model

```bash
# Download en_US-lessac-medium model (22kHz, high quality)
curl -L -o models/en_US-lessac-medium.onnx \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx

curl -L -o models/en_US-lessac-medium.onnx.json \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env with your LiveKit credentials
```

## Usage

### Run Agent (Standalone)

```bash
python -m src.agent
```

### Run with Docker Compose

```bash
docker compose -f deployments/docker/docker-compose.services.yml up arc-scarlett-voice
```

## Plugin Architecture

### 1. **Whisper STT Plugin** (LiveKit Built-in)

- Uses `livekit-plugins-whisper` (faster-whisper backend)
- Model: `base` (74MB, 200-400ms latency)
- Language: Auto-detect (defaults to English)

### 2. **Sherlock LLM Plugin** (Custom)

Located: `src/plugins/sherlock_llm.py`

- Extends `LLMPlugin` from LiveKit Agents SDK
- Calls arc-sherlock-brain via NATS request-reply
- Timeout: 5 seconds (fallback to error message)

### 3. **Piper TTS Plugin** (Custom)

Located: `src/plugins/piper_tts.py`

- Extends `TTSPlugin` from LiveKit Agents SDK
- Loads Piper ONNX model at startup
- Streams audio directly to LiveKit (no disk I/O)

## Performance Metrics

| Component       | Latency     | Notes                      |
| --------------- | ----------- | -------------------------- |
| Whisper STT     | 200-400ms   | Base model, CPU inference  |
| NATS Overhead   | 1-5ms       | Request-reply round-trip   |
| Sherlock Brain  | 400-1200ms  | LangGraph + pgvector + LLM |
| Piper TTS       | 100-300ms   | ONNX runtime, streaming    |
| **Total (P95)** | **<1000ms** | Phase 3D target            |

## Development

### Run Tests

```bash
pytest tests/
```

### Enable Debug Logging

```bash
export LOG_LEVEL=DEBUG
python -m src.agent
```

## Troubleshooting

### Agent Not Connecting to LiveKit

1. Verify LiveKit server is running:

   ```bash
   curl http://arc-daredevil-voice:7880/health
   ```

2. Check API credentials:
   ```bash
   echo $LIVEKIT_API_KEY
   ```

### NATS Connection Failed

1. Verify NATS server:

   ```bash
   docker exec arc-flash-pulse nats-server -v
   ```

2. Test NATS connectivity:
   ```bash
   nats --server $NATS_URL pub brain.request '{"user_id":"test","text":"hello"}'
   ```

### Piper Model Not Found

Download the model manually:

```bash
mkdir -p models
cd models
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
```

## License

See root LICENSE file.
