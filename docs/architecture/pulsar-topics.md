# A.R.C. Pulsar Topics Schema

**Task**: T018  
**Service**: arc-strange-stream (Apache Pulsar)  
**Purpose**: Durable event streaming for analytics, audit trails, and long-term storage

---

## Overview

Pulsar serves as the **time stone** of the A.R.C. platform - capturing the complete history of agent interactions for:

- **Conversation Analytics**: Aggregate metrics across all user sessions
- **Compliance & Audit**: Immutable record of all agent interactions
- **ML Training Data**: Conversation history for model fine-tuning
- **Replay & Debugging**: Reconstruct exact state of any past session

**Design Principles**:

1. **Persistent by Default**: All messages stored with configurable retention (7-90 days)
2. **Multi-Tenant**: Namespace isolation (`arc` tenant, multiple namespaces)
3. **Schema Registry**: Enforce Avro/JSON schemas for data consistency
4. **Geo-Replication**: Cross-datacenter replication for disaster recovery

---

## Topic Taxonomy

### Naming Convention

```
persistent://<tenant>/<namespace>/<topic>
```

- **tenant**: `arc` (platform tenant)
- **namespace**: `events`, `analytics`, `audit`
- **topic**: Entity-based (e.g., `conversation`, `session-metrics`)

### Retention Policies

| Namespace   | Retention | Purpose                           |
| ----------- | --------- | --------------------------------- |
| `events`    | 30 days   | Recent operational events         |
| `analytics` | 90 days   | Aggregated metrics and KPIs       |
| `audit`     | 7 years   | Compliance and legal requirements |

---

## Events Namespace (`persistent://arc/events/`)

### `persistent://arc/events/conversation`

**Purpose**: Complete record of all agent conversations (user input + agent response)

**Producer**: `arc-sherlock-brain` (after each completed turn)

**Consumers**:

- `analytics-pipeline` (metrics aggregation)
- `ml-training-worker` (dataset creation)
- `search-indexer` (conversation search)

**Schema** (JSON):

```json
{
  "schema": "conversation-v1",
  "message_id": "msg-550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-12-14T13:30:06.500Z",
  "event_type": "conversation_turn_completed",

  "conversation": {
    "id": "conv-789",
    "session_id": "session-456",
    "user_id": "user-123",
    "agent_id": "arc-scarlett-voice",
    "turn_index": 3
  },

  "user_message": {
    "text": "What's the weather like today?",
    "audio_duration_ms": 1200,
    "stt_model": "whisper-large-v3",
    "stt_confidence": 0.98,
    "stt_latency_ms": 150
  },

  "agent_response": {
    "text": "It's currently 68°F and sunny in San Francisco. Perfect weather for outdoor activities!",
    "llm_model": "gpt-4-turbo",
    "llm_tokens_used": 45,
    "llm_latency_ms": 450,
    "tts_model": "piper-en_US-lessac-medium",
    "tts_audio_duration_ms": 2500,
    "tts_latency_ms": 200
  },

  "context": {
    "previous_turn_count": 2,
    "context_tokens_used": 120,
    "tools_invoked": ["weather_api"],
    "embedding_vector_id": "emb-abc123"
  },

  "performance": {
    "total_latency_ms": 800,
    "stt_latency_ms": 150,
    "llm_latency_ms": 450,
    "tts_latency_ms": 200,
    "network_overhead_ms": 50
  },

  "metadata": {
    "room_name": "room-user-123-session-456",
    "participant_sid": "PA_MnOpQrStUvWx",
    "trace_id": "550e8400-e29b-41d4-a716-446655440000",
    "environment": "production",
    "region": "us-west-2"
  }
}
```

**Partition Key**: `user_id` (ensures all user conversations in same partition for ordering)

**Retention**: 30 days

---

### `persistent://arc/events/agent-lifecycle`

**Purpose**: Agent service start, stop, crash events

**Producers**: All agent services (`arc-scarlett-voice`, `arc-sherlock-brain`, `arc-piper-tts`)

**Consumers**:

- `ops-dashboard` (uptime monitoring)
- `alerting-service` (incident detection)

**Schema** (JSON):

```json
{
  "schema": "agent-lifecycle-v1",
  "message_id": "msg-lifecycle-123",
  "timestamp": "2025-12-14T13:25:00.000Z",
  "event_type": "service_started",

  "service": {
    "name": "arc-scarlett-voice",
    "instance_id": "scarlett-voice-pod-7f8b9c",
    "version": "v1.2.3",
    "node": "k8s-node-05"
  },

  "event_details": {
    "type": "started",
    "reason": "scheduled_deployment",
    "previous_state": "stopped",
    "current_state": "running"
  },

  "health": {
    "cpu_limit": "2000m",
    "memory_limit": "4Gi",
    "initial_goroutines": 12,
    "dependencies_healthy": true
  }
}
```

**Event Types**:

- `service_started`
- `service_stopped`
- `service_crashed`
- `service_health_degraded`
- `service_recovered`

**Retention**: 90 days

---

### `persistent://arc/events/livekit-webhooks`

**Purpose**: Raw LiveKit webhook events (room created, participant joined, track published)

**Producer**: `arc-scarlett-voice` (webhook handler)

**Consumers**:

- `session-tracker` (real-time session state)
- `billing-service` (usage metering)

**Schema** (JSON - matches LiveKit webhook format):

```json
{
  "schema": "livekit-webhook-v1",
  "message_id": "msg-webhook-456",
  "timestamp": "2025-12-14T13:30:01.000Z",
  "event": "track_published",

  "webhook_payload": {
    "event": "track_published",
    "room": {
      "sid": "RM_AbCdEfGhIjKl",
      "name": "room-user-123-session-456",
      "createdAt": "1702563000"
    },
    "participant": {
      "sid": "PA_MnOpQrStUvWx",
      "identity": "user-123",
      "state": "ACTIVE"
    },
    "track": {
      "sid": "TR_YzAbCdEfGhIj",
      "type": "AUDIO",
      "source": "MICROPHONE",
      "mimeType": "audio/opus"
    }
  },

  "metadata": {
    "webhook_id": "wh-123",
    "received_at": "2025-12-14T13:30:01.050Z",
    "processing_latency_ms": 5
  }
}
```

**Retention**: 7 days (short retention, mainly for debugging)

---

## Analytics Namespace (`persistent://arc/analytics/`)

### `persistent://arc/analytics/session-metrics`

**Purpose**: Aggregated per-session performance metrics

**Producer**: `arc-scarlett-voice` (on session end)

**Consumers**:

- `grafana-dashboard` (real-time visualization)
- `ml-ops-pipeline` (model performance tracking)
- `capacity-planner` (infrastructure scaling)

**Schema** (JSON):

```json
{
  "schema": "session-metrics-v1",
  "message_id": "msg-metrics-789",
  "timestamp": "2025-12-14T13:35:00.000Z",
  "event_type": "session_ended",

  "session": {
    "id": "session-456",
    "user_id": "user-123",
    "agent_id": "arc-scarlett-voice",
    "room_name": "room-user-123-session-456",
    "room_sid": "RM_AbCdEfGhIjKl",
    "started_at": "2025-12-14T13:30:00.000Z",
    "ended_at": "2025-12-14T13:35:00.000Z",
    "duration_seconds": 300
  },

  "conversation_stats": {
    "total_turns": 12,
    "user_messages": 12,
    "agent_messages": 12,
    "avg_turn_length_words": 18,
    "total_tokens_used": 540
  },

  "performance_metrics": {
    "avg_latency_ms": 750,
    "p50_latency_ms": 700,
    "p95_latency_ms": 1200,
    "p99_latency_ms": 1500,
    "max_latency_ms": 1800,

    "avg_stt_latency_ms": 140,
    "avg_llm_latency_ms": 430,
    "avg_tts_latency_ms": 180,

    "sla_compliance_percent": 95.5,
    "target_latency_ms": 2000
  },

  "connection_quality": {
    "avg_packet_loss_percent": 0.2,
    "avg_jitter_ms": 5,
    "connection_type": "udp",
    "reconnect_count": 0,
    "quality_rating": "excellent"
  },

  "resource_usage": {
    "total_audio_bytes": 7200000,
    "total_llm_tokens": 540,
    "api_calls": {
      "stt": 12,
      "llm": 12,
      "tts": 12,
      "weather_api": 2
    }
  },

  "user_experience": {
    "interruptions": 1,
    "silence_gaps_ms": [500, 300, 400],
    "user_satisfaction_score": 4.5
  }
}
```

**Partition Key**: `date(timestamp)` (daily partitions for efficient analytics queries)

**Retention**: 90 days

---

### `persistent://arc/analytics/agent-performance`

**Purpose**: Per-agent performance aggregates (hourly rollups)

**Producer**: `analytics-aggregator` (hourly cron job)

**Schema**:

```json
{
  "schema": "agent-performance-v1",
  "message_id": "msg-perf-001",
  "timestamp": "2025-12-14T14:00:00.000Z",
  "aggregation_period": "hourly",
  "time_bucket": "2025-12-14T13:00:00.000Z",

  "agent_id": "arc-scarlett-voice",
  "instance_id": "scarlett-voice-pod-7f8b9c",

  "metrics": {
    "total_sessions": 156,
    "total_conversations": 1872,
    "avg_session_duration_seconds": 245,
    "avg_latency_ms": 780,
    "p95_latency_ms": 1250,
    "sla_violations": 8,
    "error_rate_percent": 0.5,
    "uptime_percent": 99.8
  },

  "resource_usage": {
    "avg_cpu_percent": 42,
    "avg_memory_mb": 1024,
    "peak_memory_mb": 1536,
    "avg_goroutines": 250
  }
}
```

**Retention**: 90 days

---

## Audit Namespace (`persistent://arc/audit/`)

### `persistent://arc/audit/compliance-events`

**Purpose**: Immutable audit trail for regulatory compliance (GDPR, HIPAA, SOC2)

**Producers**: All services

**Consumers**:

- `compliance-dashboard`
- `audit-export-service`
- `legal-data-request-handler`

**Schema**:

```json
{
  "schema": "compliance-audit-v1",
  "message_id": "msg-audit-001",
  "timestamp": "2025-12-14T13:30:00.000Z",
  "event_type": "user_data_accessed",

  "actor": {
    "type": "service",
    "service_name": "arc-sherlock-brain",
    "instance_id": "brain-pod-3a2b1c",
    "authenticated_as": "system-service-account"
  },

  "action": {
    "type": "data_access",
    "operation": "read",
    "resource": "user_conversation_history",
    "resource_id": "user-123",
    "reason": "context_retrieval_for_llm"
  },

  "data_accessed": {
    "tables": ["agents.conversations"],
    "row_count": 5,
    "columns": ["user_input", "agent_response", "embedding"],
    "pii_fields": ["user_input"]
  },

  "compliance": {
    "legal_basis": "legitimate_interest",
    "data_retention_policy": "30_days",
    "encryption": "AES-256",
    "anonymization": false
  },

  "context": {
    "trace_id": "550e8400-e29b-41d4-a716-446655440000",
    "user_consent_id": "consent-789",
    "session_id": "session-456"
  }
}
```

**Event Types**:

- `user_data_accessed`
- `user_data_modified`
- `user_data_deleted`
- `user_consent_granted`
- `user_consent_revoked`
- `data_export_requested`
- `data_anonymization_executed`

**Retention**: 7 years (configurable per compliance requirement)

---

## Schema Management

### Schema Registry

Pulsar supports **schema evolution** with Avro/JSON/Protobuf. For production:

1. **Register Schema**:

```bash
bin/pulsar-admin schemas upload \
  persistent://arc/events/conversation \
  --filename schemas/conversation-v1.avsc
```

2. **Schema Compatibility**:

   - **BACKWARD**: New consumers can read old data
   - **FORWARD**: Old consumers can read new data
   - **FULL**: Both backward and forward compatible

3. **Version Management**:
   - Use semantic versioning in schema field: `"schema": "conversation-v1"`
   - When breaking changes needed, create new topic: `conversation-v2`

---

## Partitioning Strategy

| Topic               | Partition Key     | Partitions | Rationale                             |
| ------------------- | ----------------- | ---------- | ------------------------------------- |
| `conversation`      | `user_id`         | 16         | User-based sharding, ordered per user |
| `session-metrics`   | `date(timestamp)` | 8          | Time-based partitioning for analytics |
| `agent-lifecycle`   | `service_name`    | 4          | Service-based isolation               |
| `compliance-events` | `user_id`         | 32         | High throughput, user isolation       |

---

## Subscription Models

### Exclusive (Session Metrics Dashboard)

```python
consumer = client.subscribe(
    topic='persistent://arc/analytics/session-metrics',
    subscription_name='grafana-dashboard',
    subscription_type=pulsar.ConsumerType.Exclusive
)
```

### Shared (ML Training Workers)

```python
consumer = client.subscribe(
    topic='persistent://arc/events/conversation',
    subscription_name='ml-training-workers',
    subscription_type=pulsar.ConsumerType.Shared
)
```

### Failover (Compliance Export - HA)

```python
consumer = client.subscribe(
    topic='persistent://arc/audit/compliance-events',
    subscription_name='compliance-export',
    subscription_type=pulsar.ConsumerType.Failover
)
```

---

## Message Deduplication

Enable **producer deduplication** to prevent duplicate events:

```python
producer = client.create_producer(
    topic='persistent://arc/events/conversation',
    producer_name='arc-sherlock-brain-instance-1',
    properties={'application': 'arc-sherlock-brain'},
    # Deduplication based on message key
    batching_enabled=False  # For critical events
)

# Send with unique message ID
producer.send(
    content=json.dumps(message).encode('utf-8'),
    properties={'message_id': 'msg-550e8400-e29b-41d4-a716-446655440000'}
)
```

---

## Dead Letter Queue (DLQ)

Configure DLQ for failed message processing:

```python
consumer = client.subscribe(
    topic='persistent://arc/events/conversation',
    subscription_name='analytics-pipeline',
    subscription_type=pulsar.ConsumerType.Shared,
    dead_letter_policy=pulsar.ConsumerDeadLetterPolicy(
        max_redeliver_count=3,
        dead_letter_topic='persistent://arc/events/conversation-dlq'
    )
)
```

---

## Performance Targets

| Metric           | Target          | Notes                  |
| ---------------- | --------------- | ---------------------- |
| Write Throughput | 100,000 msg/sec | Per broker             |
| Read Throughput  | 200,000 msg/sec | Multiple consumers     |
| Storage          | 100TB+          | Tiered storage (S3)    |
| Retention        | 90 days default | Configurable per topic |
| Replication Lag  | <100ms          | Geo-replication        |

---

## Tiered Storage Configuration

For long-term retention, configure **tiered storage** to offload old segments to S3:

```yaml
# conf/broker.conf
managedLedgerOffloadDriver=aws-s3
s3ManagedLedgerOffloadBucket=arc-pulsar-archive
s3ManagedLedgerOffloadRegion=us-west-2
managedLedgerOffloadThresholdInSeconds=86400 # 1 day
```

---

## Testing

### Publish Test Message

```bash
# Using Pulsar CLI
bin/pulsar-client produce \
  persistent://arc/events/conversation \
  --messages '{
    "schema": "conversation-v1",
    "conversation": {"id": "test-conv-001"},
    "user_message": {"text": "Hello test"}
  }'
```

### Consume Messages

```bash
bin/pulsar-client consume \
  persistent://arc/events/conversation \
  --subscription-name test-consumer \
  --num-messages 10
```

---

## Next Steps

1. **T019**: Create test scripts (`scripts/messaging/test-pulsar.sh`)
2. **T023**: Implement Pulsar client in Go SDK
3. **T027**: Implement Pulsar client in Python SDK
4. **Phase 3**: Begin agent implementation with full event streaming
