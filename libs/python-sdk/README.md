# A.R.C. Common Python SDK

Shared libraries for A.R.C. agent services (Python).

## Features

- **Database Models**: SQLAlchemy ORM models with pgvector support for conversation and session management
- **Messaging Clients**: NATS and Pulsar client wrappers for event streaming
- **Observability**: OpenTelemetry instrumentation helpers for tracing, metrics, and logging

## Installation

```bash
pip install -r requirements.txt
```

## Usage

### Database Models

```python
from arc_common.models import Conversation, Session, find_similar_conversations
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Create engine
engine = create_engine("postgresql://user:pass@localhost:5432/arc")
SessionLocal = sessionmaker(bind=engine)

# Create conversation
with SessionLocal() as db:
    conv = Conversation(
        user_id="user-123",
        agent_id="arc-sherlock-brain",
        turn_index=1,
        user_input="Hello!",
        agent_response="Hi there!",
        embedding=[0.1] * 1536  # OpenAI embedding
    )
    db.add(conv)
    db.commit()

# Find similar conversations
similar = find_similar_conversations(db, query_embedding=[0.1] * 1536, limit=5)
```

### NATS Client

```python
from arc_common.messaging import NATSAgentClient

client = NATSAgentClient("nats://localhost:4222", service_name="arc-scarlett-voice")
await client.connect()

# Publish event
await client.publish_session_started(
    user_id="user-123",
    session_id="session-456",
    room_name="room-789",
    room_sid="RM_abc",
    participant_sid="PA_xyz"
)

# Subscribe to events
async def handle_brain_response(msg_data):
    print(f"Brain response: {msg_data.get('agent_response')}")

await client.subscribe("agent.brain.response", handle_brain_response)
```

### Pulsar Client

```python
from arc_common.messaging import PulsarAgentClient

client = PulsarAgentClient("pulsar://localhost:6650", service_name="arc-sherlock-brain")
client.connect()

# Produce conversation event
msg_id = client.produce_conversation_event(
    conversation_id="conv-123",
    event_type="turn_completed",
    data={
        "user_input": "What's the weather?",
        "agent_response": "It's sunny today!"
    }
)

# Consume events
def handle_conversation(msg_data, msg):
    conv_id = msg_data.get("conversation_id")
    print(f"Processing: {conv_id}")
    return True  # Acknowledge

client.consume_conversation_events("brain-consumer", handle_conversation)
```

### OpenTelemetry Instrumentation

```python
from arc_common.observability import init_otel, get_otel

# Initialize (in service main.py)
otel = init_otel("arc-scarlett-voice", otel_endpoint="http://localhost:4317")

# Use in any module
from arc_common.observability import get_otel

otel = get_otel()

# Trace operations
with otel.trace_span("process_audio", {"room_name": "room-123"}) as span:
    # ... processing logic ...
    span.set_attribute("duration_ms", 125.5)

# Record metrics
otel.increment_counter("voice.sessions.started")
otel.record_histogram("voice.latency", 125.5, {"operation": "stt"})
otel.record_error("timeout", "STT exceeded 3s limit")
```

## Testing

```bash
# Run tests
pytest

# With coverage
pytest --cov=arc_common --cov-report=html

# Format code
black arc_common/
isort arc_common/

# Lint
ruff arc_common/
mypy arc_common/
```

## Architecture

```
arc_common/
├── models/           # Database models (SQLAlchemy + pgvector)
│   ├── conversation.py
│   └── __init__.py
├── messaging/        # Messaging clients
│   ├── nats_client.py
│   ├── pulsar_client.py
│   └── __init__.py
├── observability/    # OTEL instrumentation
│   ├── otel.py
│   └── __init__.py
└── __init__.py
```

## Dependencies

- **SQLAlchemy**: ORM for database models
- **pgvector**: PostgreSQL vector similarity search
- **nats-py**: NATS client for ephemeral messaging
- **pulsar-client**: Pulsar client for durable event streaming
- **opentelemetry**: Distributed tracing and metrics

## Service Integration

This SDK is used by:

- `arc-scarlett-voice`: Voice agent service (LiveKit + STT/TTS)
- `arc-sherlock-brain`: Reasoning engine (LangGraph)
- `arc-piper-tts`: Text-to-speech service (Piper)

See `docs/architecture/` for subject schemas and topic definitions.
