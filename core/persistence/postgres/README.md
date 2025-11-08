# PostgreSQL

**Status:** ✅ Active  
**Type:** Relational Database with Vector Extensions

---

## Overview

PostgreSQL serves as the primary data store for the A.R.C. Framework, providing:

- **ACID Transactions** - Reliable data persistence
- **pgvector Extension** - Vector embeddings for RAG and semantic search
- **JSONB Support** - Flexible schema design for agent state
- **Full-Text Search** - Advanced text indexing and querying
- **Mature Ecosystem** - Rich tooling for backup, replication, and monitoring

---

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
POSTGRES_USER=arc_user
POSTGRES_PASSWORD=arc_password
POSTGRES_DB=arc_db
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
```

### Initialization

The database is automatically initialized using [`init.sql`](./init.sql) on first startup. This script:
- Sets up initial schemas
- Installs extensions (pgvector)
- Creates default users and permissions

---

## Usage

### Starting PostgreSQL

```bash
# Start with the full stack
make up-stack

# Or start PostgreSQL specifically
docker-compose -f docker-compose.stack.yml up postgres -d
```

### Connecting to the Database

**From Host:**
```bash
psql -h localhost -p 5432 -U arc_user -d arc_db
```

**From Another Container:**
```bash
psql -h postgres -p 5432 -U arc_user -d arc_db
```

**Using Docker Exec:**
```bash
docker exec -it postgres psql -U arc_user -d arc_db
```

---

## Ports

| Port | Purpose |
|------|---------|
| `5432` | PostgreSQL server |

---

## Data Persistence

Data is persisted in a Docker volume:
- **Volume Name**: `postgres-data`
- **Location**: Managed by Docker

To backup the database:
```bash
docker exec postgres pg_dump -U arc_user arc_db > backup.sql
```

To restore:
```bash
cat backup.sql | docker exec -i postgres psql -U arc_user -d arc_db
```

---

## pgvector Extension

The pgvector extension enables vector similarity search for AI embeddings:

```sql
-- Create a table with vector column
CREATE TABLE embeddings (
  id SERIAL PRIMARY KEY,
  content TEXT,
  embedding vector(1536)  -- OpenAI embedding dimension
);

-- Create an index for fast similarity search
CREATE INDEX ON embeddings USING ivfflat (embedding vector_cosine_ops);

-- Query by similarity
SELECT content, embedding <=> '[0.1, 0.2, ...]'::vector AS distance
FROM embeddings
ORDER BY distance
LIMIT 10;
```

---

## Health Check

Check PostgreSQL health:

```bash
docker exec postgres pg_isready -U arc_user
```

---

## Troubleshooting

### View Logs
```bash
docker-compose -f docker-compose.stack.yml logs postgres
```

### Common Issues

1. **Connection refused**: Ensure container is running and port is not blocked
2. **Authentication failed**: Check username/password in `.env`
3. **Database does not exist**: Verify `POSTGRES_DB` matches your connection string
4. **Permission denied**: Check user has appropriate grants

### Reset Database

To completely reset the database:
```bash
# Stop and remove volumes
docker-compose -f docker-compose.stack.yml down -v

# Restart
docker-compose -f docker-compose.stack.yml up postgres -d
```

---

## See Also

- [Persistence Overview](../README.md)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Operations Guide](../../../docs/OPERATIONS.md)

