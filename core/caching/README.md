# Caching

In-memory caching and session storage for the A.R.C. Framework.

---

## Overview

The caching layer provides high-performance, in-memory data storage for:
- Application caching
- Session storage
- Rate limiting
- Distributed locks
- Real-time data structures

---

## Implementation

### [Redis](./redis/)
**Status:** ✅ Active  
**Type:** In-memory data store

- Sub-millisecond access times
- Rich data structures (strings, hashes, lists, sets, sorted sets)
- Optional persistence (RDB, AOF)
- Pub/sub messaging
- Lua scripting support

---

## Alternatives

The cache is **swappable**. Alternative implementations:
- **Valkey** - Redis fork (OSS)
- **DragonflyDB** - Modern Redis alternative
- **KeyDB** - Multi-threaded Redis fork
- **Memcached** - Simpler, cache-only

---

## See Also

- [Core Services](../README.md)
- [Operations Guide](../../docs/OPERATIONS.md)
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

