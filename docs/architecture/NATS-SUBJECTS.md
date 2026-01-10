# A.R.C. NATS Subject Schema

**Task**: T017  
**Service**: arc-flash-pulse (NATS JetStream)  
**Purpose**: Real-time ephemeral messaging for agent coordination and events

---

## Overview

NATS serves as the **nervous system** of the A.R.C. real-time voice agent stack. It handles:

- **WebRTC Event Coordination**: LiveKit track published/unpublished events
- **Agent Request/Response**: STT → LLM → TTS pipeline coordination
- **Service Health**: Heartbeats and status updates
- **Low-Latency Communication**: <10ms message delivery within cluster

**Design Principles**:

1. **Ephemeral by Default**: Messages are not persisted (use Pulsar for analytics/audit)
2. **Subject Hierarchy**: Dot-notation for filtering and wildcard subscriptions
3. **Payload Format**: JSON with timestamp and trace context for OpenTelemetry
4. **Error Handling**: Dead-letter subjects for failed message processing

---

## Subject Taxonomy

### Naming Convention

```
<domain>.<service>.<entity>.<action>
```

- **domain**: `agent` (all agent-related events), `system` (infrastructure)
- **service**: `voice`, `brain`, `tts`, `stt`
- **entity**: `track`, `session`, `request`, `response`
- **action**: `published`, `unpublished`, `started`, `ended`, `failed`

---

## Agent Voice Service (`arc-scarlett-voice`)

### WebRTC Track Events

#### `agent.voice.track.published`

**Trigger**: User joins LiveKit room and starts speaking (audio track published)

**Publisher**: `arc-scarlett-voice` (LiveKit webhook handler)

**Subscribers**: `arc-scarlett-voice` (STT worker), `arc-widow-otel` (metrics)

**Payload**:

```json
{
  "event": "track_published",
  "timestamp": "2025-12-14T13:30:00.000Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "room_name": "room-user-123-session-456",
  "room_sid": "RM_AbCdEfGhIjKl",
  "participant_sid": "PA_MnOpQrStUvWx",
  "participant_identity": "user-123",
  "track_sid": "TR_YzAbCdEfGhIj",
  "track_kind": "audio",
  "track_source": "microphone",
  "metadata": {
    "user_id": "user-123",
    "session_id": "session-456"
  }
}
```

**Workflow**:

1. User's microphone track is published to LiveKit room
2. `arc-scarlett-voice` publishes NATS event
3. STT worker subscribes and begins audio stream processing
4. OTEL collector logs event for tracing

---

#### `agent.voice.track.unpublished`

**Trigger**: User stops speaking or disconnects

**Publisher**: `arc-scarlett-voice`

**Subscribers**: `arc-scarlett-voice` (cleanup), `arc-widow-otel`

**Payload**:

```json
{
  "event": "track_unpublished",
  "timestamp": "2025-12-14T13:35:00.000Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "room_name": "room-user-123-session-456",
  "participant_sid": "PA_MnOpQrStUvWx",
  "track_sid": "TR_YzAbCdEfGhIj",
  "reason": "user_disconnected",
  "duration_seconds": 300
}
```

---

#### `agent.voice.session.started`

**Trigger**: User successfully joins LiveKit room

**Payload**:

```json
{
  "event": "session_started",
  "timestamp": "2025-12-14T13:30:00.000Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user-123",
  "session_id": "session-456",
  "room_name": "room-user-123-session-456",
  "room_sid": "RM_AbCdEfGhIjKl",
  "participant_sid": "PA_MnOpQrStUvWx",
  "agent_id": "arc-scarlett-voice"
}
```

---

#### `agent.voice.session.ended`

**Trigger**: User leaves room or session times out

**Payload**:

```json
{
  "event": "session_ended",
  "timestamp": "2025-12-14T13:35:00.000Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user-123",
  "session_id": "session-456",
  "room_name": "room-user-123-session-456",
  "duration_seconds": 300,
  "total_turns": 12,
  "reason": "user_left",
  "final_status": "completed"
}
```

---

## Agent Brain Service (`arc-sherlock-brain`)

### Reasoning Request/Response

#### `agent.brain.request`

**Trigger**: STT completes transcription of user speech

**Publisher**: `arc-scarlett-voice` (STT worker)

**Subscribers**: `arc-sherlock-brain` (LangGraph reasoning engine)

**Payload**:

```json
{
  "request_id": "req-550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-12-14T13:30:05.000Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user-123",
  "session_id": "session-456",
  "conversation_id": "conv-789",
  "turn_index": 3,
  "user_input": "What's the weather like today?",
  "context": {
    "previous_turns": [
      { "user": "Hello", "agent": "Hi! How can I help?" },
      {
        "user": "I'm planning a trip",
        "agent": "Where are you thinking of going?"
      }
    ],
    "user_profile": {
      "location": "San Francisco, CA",
      "preferences": ["outdoor_activities"]
    }
  },
  "constraints": {
    "max_tokens": 150,
    "temperature": 0.7,
    "timeout_ms": 2000
  }
}
```

---

#### `agent.brain.response`

**Trigger**: LangGraph completes reasoning and generates response

**Publisher**: `arc-sherlock-brain`

**Subscribers**: `arc-scarlett-voice` (TTS worker), `arc-widow-otel`

**Payload**:

```json
{
  "request_id": "req-550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-12-14T13:30:06.500Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user-123",
  "session_id": "session-456",
  "conversation_id": "conv-789",
  "turn_index": 3,
  "agent_response": "It's currently 68°F and sunny in San Francisco. Perfect weather for outdoor activities!",
  "metadata": {
    "llm_model": "gpt-4-turbo",
    "tokens_used": 45,
    "reasoning_steps": 3,
    "tools_called": ["weather_api"],
    "confidence_score": 0.95
  },
  "performance": {
    "llm_latency_ms": 450,
    "total_processing_ms": 500
  }
}
```

---

#### `agent.brain.error`

**Trigger**: LLM call fails or times out

**Payload**:

```json
{
  "request_id": "req-550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-12-14T13:30:06.500Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "error_type": "timeout",
  "error_message": "LLM request exceeded 2000ms timeout",
  "retry_count": 2,
  "fallback_response": "I'm having trouble processing that. Could you rephrase?"
}
```

---

## Text-to-Speech Service (`arc-piper-tts`)

#### `agent.tts.request`

**Trigger**: Brain service returns text response

**Publisher**: `arc-scarlett-voice` (TTS coordinator)

**Subscribers**: `arc-piper-tts` (Piper synthesis worker)

**Payload**:

```json
{
  "request_id": "tts-req-123",
  "timestamp": "2025-12-14T13:30:07.000Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "text": "It's currently 68°F and sunny in San Francisco.",
  "voice_id": "en_US-lessac-medium",
  "session_id": "session-456",
  "target_room": "room-user-123-session-456",
  "constraints": {
    "max_latency_ms": 500,
    "format": "opus",
    "sample_rate": 24000
  }
}
```

---

#### `agent.tts.completed`

**Trigger**: Audio synthesis complete, ready for streaming

**Payload**:

```json
{
  "request_id": "tts-req-123",
  "timestamp": "2025-12-14T13:30:07.300Z",
  "trace_id": "550e8400-e29b-41d4-a716-446655440000",
  "audio_track_sid": "TR_AudioGenerated123",
  "duration_ms": 2500,
  "synthesis_latency_ms": 300,
  "audio_format": "opus",
  "ready_for_playback": true
}
```

---

## System Health & Monitoring

#### `system.health.heartbeat`

**Trigger**: Every 30 seconds from each service

**Payload**:

```json
{
  "service": "arc-scarlett-voice",
  "timestamp": "2025-12-14T13:30:00.000Z",
  "status": "healthy",
  "metrics": {
    "active_sessions": 42,
    "cpu_percent": 23.5,
    "memory_mb": 512,
    "goroutines": 156
  }
}
```

---

#### `system.service.error`

**Trigger**: Critical service error

**Payload**:

```json
{
  "service": "arc-sherlock-brain",
  "timestamp": "2025-12-14T13:30:00.000Z",
  "error_type": "connection_lost",
  "error_message": "Lost connection to NATS cluster",
  "severity": "critical",
  "action_required": "automatic_restart"
}
```

---

## Wildcard Subscriptions

### Monitor All Agent Events

```
agent.>
```

### Monitor Specific Service

```
agent.voice.>
```

### Monitor All Track Events

```
agent.*.track.>
```

### Monitor All Errors

```
*.*.error
system.*.error
```

---

## Message Retention & TTL

- **Default TTL**: 60 seconds (ephemeral messaging)
- **Max Message Size**: 1MB (NATS default)
- **No Persistence**: Messages are not stored (use Pulsar for audit trail)
- **Delivery Guarantee**: At-most-once (fire-and-forget for low latency)

For analytics and long-term storage, duplicate events to **Pulsar** topics.

---

## Testing

### Publish Test Event

```bash
# Using NATS CLI
nats pub agent.voice.track.published '{
  "event": "track_published",
  "timestamp": "2025-12-14T13:30:00.000Z",
  "room_name": "test-room",
  "participant_identity": "test-user"
}'
```

### Subscribe to Events

```bash
# Monitor all agent events
nats sub "agent.>"

# Monitor only brain responses
nats sub "agent.brain.response"
```

---

## Performance Targets

| Metric                 | Target         | Notes                 |
| ---------------------- | -------------- | --------------------- |
| Message Latency        | <10ms          | Within same cluster   |
| Throughput             | 10,000 msg/sec | Per NATS node         |
| Concurrent Subscribers | 1,000+         | Horizontally scalable |
| Subject Depth          | Max 8 levels   | Keep hierarchy flat   |

---

## Next Steps

1. **T018**: Define Pulsar topics for persistent event storage
2. **T019**: Create test scripts (`scripts/messaging/test-nats.sh`)
3. **T020**: Implement NATS client in Go SDK (`libs/go-sdk/nats/client.go`)
4. **T024**: Implement NATS client in Python SDK (`libs/python-sdk/arc/messaging/nats.py`)
