# Persistence

Data persistence services for the A.R.C. Framework.

---

## Overview

The persistence layer provides relational database storage with vector search capabilities for agent state and embeddings.

---

## Implementation

### [PostgreSQL](./postgres/)
**Status:** ✅ Active  
**Type:** Relational database with vector extensions

- ACID transactions
- pgvector extension for RAG/embeddings
- JSONB support for flexible schemas
- Full-text search
- Mature replication and backup tools

---

## Alternatives

The database is **swappable**. Alternative implementations:
- **MySQL** - Popular, slightly different feature set
- **CockroachDB** - Distributed SQL, PostgreSQL compatible
- **YugabyteDB** - Distributed SQL, PostgreSQL compatible
- **TimescaleDB** - Time-series optimized PostgreSQL

---

## See Also

- [Core Services](../README.md)
- [Operations Guide](../../docs/OPERATIONS.md)

