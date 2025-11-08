# Messaging

Message broker services for agent communication and event distribution.

---

## Overview

The A.R.C. Framework uses **two messaging systems** for different purposes:

1. **Ephemeral Messaging (NATS)** - Fast, lightweight, for real-time sync
2. **Durable Messaging (Pulsar)** - Persistent, for event sourcing

---

## Categories

### [Ephemeral](./ephemeral/)
**Purpose:** Real-time agent-to-agent communication

- Fast, sub-millisecond latency
- No persistence (memory only)
- Pub/sub, request/reply, queue groups
- Ideal for: coordination, job queues, heartbeats

**Implementation:** [NATS](./ephemeral/nats/)

### [Durable](./durable/)
**Purpose:** Event streaming and "Conveyor Belt" pattern

- Persistent storage
- Event replay and time-travel
- Guaranteed delivery
- Ideal for: event sourcing, audit logs, CDC

**Implementation:** [Apache Pulsar](./durable/pulsar/)

---

## When to Use Which?

| Use Case | Use This |
|----------|----------|
| Agent asks another agent to do something | NATS (ephemeral) |
| Distribute work across workers | NATS (queue groups) |
| Request/reply pattern | NATS |
| Record events for audit log | Pulsar (durable) |
| Event sourcing / CQRS | Pulsar (durable) |
| Replay historical events | Pulsar (durable) |
| Cross-service event distribution | Pulsar (durable) |

---

## Architecture

```
Fast Sync Layer (NATS)
    ↓
Agent Communication
    ↓
Event Bus (Pulsar)
    ↓
Event Store & Replay
```

---

## See Also

- [Core Services](../README.md)
- [Architecture Guide](../../docs/architecture/)
# Gateway

API Gateway and reverse proxy services for the A.R.C. Framework.

---

## Overview

The gateway layer provides:
- Unified entry point for all services
- Dynamic service discovery
- Load balancing
- SSL/TLS termination
- Request routing

---

## Implementations

### [Traefik](./traefik/)
**Status:** ✅ Active  
**Type:** Cloud-native API Gateway

- Automatic service discovery via Docker labels
- Dynamic configuration
- Let's Encrypt support
- Dashboard for monitoring

---

## Alternatives

The gateway is **swappable**. Alternative implementations:
- **Kong** - Plugin-based API gateway
- **Envoy** - CNCF service proxy
- **NGINX** - Traditional reverse proxy
- **Caddy** - Modern web server with auto-HTTPS

---

## See Also

- [Core Services](../README.md)
- [Operations Guide](../../docs/OPERATIONS.md)

