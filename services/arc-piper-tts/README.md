# A.R.C. Piper TTS Service

**Service Codename:** `arc-piper-tts`  
**Role:** "The Voice Synthesizer"  
**Technology:** Piper Neural TTS (ONNX)  
**Port:** 8002 (external) → 8000 (internal)

## Overview

The Piper TTS service provides neural text-to-speech synthesis for the A.R.C. voice agent platform. It converts text to natural-sounding speech using the Piper neural TTS engine with ONNX runtime.

## Architecture

### Model

- **Voice:** `en_US-lessac-medium` (Lessac voice model)
- **Format:** ONNX (optimized for CPU inference)
- **Sample Rate:** 22050 Hz
- **Channels:** Mono (1 channel)
- **Output Format:** WAV (16-bit PCM)

### Technology Stack

- **Framework:** FastAPI (async Python web framework)
- **TTS Engine:** Piper (neural TTS with ONNX runtime)
- **Observability:** OpenTelemetry (traces, metrics)
- **SDK:** `arc_common` Python SDK

## API Endpoints

### `POST /tts`

Convert text to speech.

**Request:**

```json
{
  "text": "Hello! How can I help you today?"
}
```

**Response:**

- Content-Type: `audio/wav`
- Headers:
  - `X-Audio-Duration`: Audio duration in seconds
  - `X-Sample-Rate`: Sample rate (Hz)

**Status Codes:**

- `200 OK`: Success (returns WAV audio)
- `422 Unprocessable Entity`: Invalid request (empty text, too long, etc.)
- `503 Service Unavailable`: Model not loaded

### `GET /health`

Health check endpoint.

**Response:**

```json
{
  "status": "healthy",
  "service": "arc-piper-tts",
  "model_loaded": true,
  "model_name": "en_US-lessac-medium"
}
```

### `GET /`

Service information.

**Response:**

```json
{
  "service": "arc-piper-tts",
  "version": "0.1.0",
  "model": "en_US-lessac-medium (Piper)",
  "endpoints": {
    "health": "/health",
    "tts": "/tts (POST)"
  }
}
```

## Development

### Local Setup

1. **Install dependencies:**

   ```bash
   cd services/arc-piper-tts
   pip install -r requirements.txt
   pip install -e ../../libs/python-sdk
   ```

2. **Download Piper model:**

   ```bash
   mkdir -p models
   cd models
   # Download from HuggingFace (see Dockerfile for URL)
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
   cd ..
   ```

3. **Run locally:**

   ```bash
   cd src
   python main.py
   # Service runs on http://localhost:8000
   ```

4. **Test with curl:**

   ```bash
   # Health check
   curl http://localhost:8000/health

   # TTS synthesis
   curl -X POST http://localhost:8000/tts \
     -H "Content-Type: application/json" \
     -d '{"text": "Hello world!"}' \
     --output speech.wav

   # Play audio (macOS)
   afplay speech.wav
   ```

### Docker Usage

**Build:**

```bash
docker build -t arc/piper-tts:latest .
```

**Run:**

```bash
docker run -p 8000:8000 \
  -e OTEL_ENDPOINT=http://localhost:4317 \
  arc/piper-tts:latest
```

**Docker Compose:**

```bash
# From repo root
docker compose -f deployments/docker/docker-compose.core.yml \
  -f deployments/docker/docker-compose.observability.yml \
  -f deployments/docker/docker-compose.services.yml \
  up arc-piper
```

Service available at: `http://localhost:8002`  
Traefik route: `http://piper.localhost/tts`

## Testing

### Unit Tests

```bash
pytest tests/ -v
```

### Integration Tests

1. Start the service (Docker or local)
2. Run integration tests:
   ```bash
   pytest tests/test_integration.py -v
   ```

### Example Test Cases

- ✅ Health check returns 200
- ✅ TTS synthesis returns WAV audio
- ✅ Empty text validation fails (422)
- ✅ Long text synthesis works
- ✅ WAV header validation

## Observability

### OpenTelemetry Instrumentation

The service automatically instruments:

- **Traces:**
  - `tts_synthesis` - Full synthesis operation
  - `piper_synthesize` - Model inference span
- **Metrics:**

  - `tts.audio.duration` (histogram) - Audio duration in ms
  - `tts.requests.success` (counter) - Successful requests
  - `tts.requests.failed` (counter) - Failed requests with error type

- **Attributes:**
  - `text_length` - Input text character count
  - `audio_duration_seconds` - Output audio length
  - `audio_samples` - Number of audio samples
  - `sample_rate` - Audio sample rate

### Viewing Traces

- **Jaeger:** `http://localhost:16686`
- **Grafana:** `http://localhost:3000` (Tempo data source)

### Example Query

```promql
# Average TTS latency
histogram_quantile(0.95,
  rate(tts_audio_duration_bucket[5m])
)
```

## Configuration

### Environment Variables

| Variable        | Default                 | Description                      |
| --------------- | ----------------------- | -------------------------------- |
| `OTEL_ENDPOINT` | `http://localhost:4317` | OpenTelemetry collector endpoint |
| `ENVIRONMENT`   | `development`           | Environment name (dev/prod)      |
| `LOG_LEVEL`     | `info`                  | Logging level                    |

### Resource Limits

- **CPU:** 1.0 cores (limit), 0.25 cores (reservation)
- **Memory:** 1GB (limit), 256MB (reservation)

## Performance

### Benchmarks

- **Latency:** ~100-300ms for typical sentences (20-50 words)
- **Throughput:** ~5-10 requests/second on single core
- **Model Load Time:** ~2-5 seconds on startup

### Optimization Tips

1. **CPU:** Piper is CPU-optimized (ONNX runtime)
2. **Memory:** Model stays in memory (~50MB)
3. **Streaming:** Audio is generated incrementally
4. **Caching:** Consider caching common phrases (future enhancement)

## Integration

### With arc-sherlock-brain

The brain service sends text responses to Piper for TTS:

```python
import httpx

async def get_voice_response(text: str) -> bytes:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "http://arc-piper:8000/tts",
            json={"text": text},
            timeout=10.0
        )
        return response.content  # WAV audio bytes
```

### With arc-scarlett-voice

The voice agent plays Piper audio to LiveKit participants:

```python
from livekit import rtc

async def speak_to_user(audio_wav: bytes):
    # Convert WAV to PCM frames
    # Push to LiveKit audio track
    # User hears synthesized speech
```

## Model Information

### en_US-lessac-medium

- **Voice Characteristics:** Clear, neutral American English
- **Quality:** Medium (balanced quality/speed)
- **Speaker:** Based on Nancy Lessac dataset
- **Training:** Piper neural TTS (transformer-based)
- **License:** MIT (from Piper project)

### Alternative Models

To use a different Piper voice:

1. Update Dockerfile to download different model
2. Update `main.py` model path
3. Rebuild Docker image

Available voices: https://huggingface.co/rhasspy/piper-voices

## Troubleshooting

### Model Not Found

**Symptom:** 503 errors, health check shows `model_loaded: false`

**Solution:**

- Check Dockerfile model download step
- Verify model file exists at `/app/models/en_US-lessac-medium.onnx`
- Rebuild Docker image

### Audio Quality Issues

**Symptom:** Distorted or garbled audio

**Solution:**

- Check text contains only supported characters (English letters, numbers, punctuation)
- Avoid very long sentences (split at punctuation)
- Verify WAV file is not corrupted

### High Latency

**Symptom:** TTS takes >1 second for short text

**Solution:**

- Check CPU usage (Piper needs CPU for inference)
- Increase container CPU limits
- Consider GPU-accelerated TTS (future enhancement)

## Future Enhancements

- [ ] Multiple voice models (different languages, speakers)
- [ ] SSML support for prosody control
- [ ] Streaming audio output (chunked)
- [ ] GPU acceleration (ONNX CUDA provider)
- [ ] Audio effects (pitch shift, speed)
- [ ] Response caching for common phrases
- [ ] WebSocket endpoint for real-time streaming

## References

- **Piper TTS:** https://github.com/rhasspy/piper
- **Models:** https://huggingface.co/rhasspy/piper-voices
- **ONNX Runtime:** https://onnxruntime.ai/
- **FastAPI:** https://fastapi.tiangolo.com/
