# Ephemeral Messaging
Real-time, low-latency messaging for agent-to-agent communication.
---
## Overview
Ephemeral messaging provides fast, memory-based message delivery without persistence. Messages are delivered in real-time and are not stored.
---
## Implementation
### [NATS](./nats/)
**Status:** ✅ Active  
**Type:** Lightweight message broker
- Sub-millisecond latency
- Pub/sub and request/reply patterns
- Queue groups for load balancing
- No persistence (memory only)
---
## Alternatives
- **RabbitMQ** - Feature-rich, slower than NATS
- **Redis Streams** - Simple, limited features
- **ZeroMQ** - Library, not a broker
---
## See Also
- [Messaging Overview](../)
- [Durable Messaging](../durable/)
- [Core Services](../../README.md)
