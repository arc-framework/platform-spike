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
