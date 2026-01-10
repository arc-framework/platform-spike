# arc-sherlock-brain

**The Reasoning Engine** - LangGraph-powered conversational brain with pgvector memory

## Overview

`arc-sherlock-brain` is the intelligent reasoning core of the A.R.C. voice agent platform. It provides:

- **LangGraph State Machine**: Structured reasoning with context retrieval → response generation
- **pgvector Memory**: Semantic search across conversation history
- **NATS Integration**: Low-latency request-reply pattern (1-5ms overhead)
- **Local LLM**: Uses Ollama/vLLM for self-hosted inference (Mistral, Llama, etc.)
- **OpenTelemetry**: Full distributed tracing and metrics

## Architecture

```
arc-scarlett-voice (Agent)
    ↓ NATS brain.request
arc-sherlock-brain (LangGraph)
    ├─► PostgreSQL (pgvector context retrieval)
    ├─► Local LLM (Ollama/vLLM)
    └─► NATS brain.response
```

## Service Endpoints

### NATS Subjects

- **Subscribe**: `brain.request` - Incoming requests from voice agent
- **Publish**: `brain.response` - Generated responses

### HTTP API (Optional)

- **POST /chat** - Direct HTTP endpoint for testing
  ```json
  {
    "text": "What's the weather?",
    "user_id": "user_123"
  }
  ```

## Environment Variables

```bash
# PostgreSQL with pgvector
POSTGRES_URL=postgresql://arc-oracle-sql:5432/arc
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# NATS Messaging
NATS_URL=nats://arc-flash-pulse:4222

# Local LLM Configuration
LLM_MODEL=mistral:7b-instruct
LLM_ENDPOINT=http://localhost:11434  # Ollama default
LLM_TEMPERATURE=0.7
LLM_MAX_TOKENS=500

# Embedding Model
EMBEDDING_MODEL=all-MiniLM-L6-v2  # sentence-transformers

# OpenTelemetry
OTEL_EXPORTER_OTLP_ENDPOINT=http://arc-widow-otel:4317
OTEL_SERVICE_NAME=arc-sherlock-brain
```

## Development

### Run Locally

```bash
cd services/arc-sherlock-brain
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python src/main.py
```

### Run with Docker Compose

```bash
docker-compose -f deployments/docker/docker-compose.services.yml up arc-sherlock
```

### Test NATS Handler

```bash
# Publish test request to brain.request
nats pub brain.request '{"text": "Hello", "user_id": "test_user"}'

# Subscribe to responses
nats sub brain.response
```

## LangGraph State Machine

```python
State: {
    "user_input": str,
    "user_id": str,
    "context": list[dict],
    "response": str
}

Nodes:
  1. retrieve_context - pgvector similarity search
  2. generate_response - Local LLM inference

Flow: START → retrieve_context → generate_response → END
```

## Performance Metrics

- **Context Retrieval**: 20-50ms (pgvector HNSW index)
- **LLM Inference**: 400-1200ms (depends on model size/GPU)
- **Total Latency**: 500-800ms (Phase 3D baseline)
- **NATS Overhead**: 1-5ms (request-reply)

## Testing

```bash
# Unit tests
pytest tests/

# Integration test with NATS
pytest tests/integration/test_nats_handler.py
```

## Monitoring

- **Traces**: Jaeger UI at http://localhost:16686
- **Metrics**: Prometheus at http://localhost:9090
- **Logs**: Loki at http://localhost:3100

## Dependencies

See `requirements.txt` for full list. Key dependencies:

- `fastapi` - HTTP API framework
- `langgraph` - State machine for reasoning
- `sqlalchemy` - PostgreSQL ORM
- `psycopg2-binary` - PostgreSQL driver
- `nats-py` - NATS client
- `sentence-transformers` - Embedding models
- `opentelemetry-*` - Observability

## License

See root LICENSE file

---

**Service Codename**: `arc-sherlock-brain` (The Detective - _Elementary, my dear Watson_)
