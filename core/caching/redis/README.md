# Redis - Cache & Session Store

In-memory data store for caching, sessions, and real-time data.

---

## Overview

**Redis** provides:
- High-performance caching
- Session storage
- Rate limiting
- Real-time data structures
- Pub/sub messaging
- Distributed locks

---

## Ports

- **6379** - Redis server

---

## Configuration

See `.env.example` for configuration options.

### Key Features
- **In-Memory** - Sub-millisecond access
- **Persistence** - Optional RDB/AOF persistence
- **Data Structures** - Strings, hashes, lists, sets, sorted sets
- **TTL** - Automatic expiration
- **Atomic Operations** - Race-condition free updates

---

## Environment Variables

See `.env.example` for configuration options.

**Key Variables:**
```bash
REDIS_PASSWORD=<strong-password>  # CHANGE THIS!
REDIS_MAXMEMORY=256mb
REDIS_MAXMEMORY_POLICY=allkeys-lru
```

---

## Usage

### Start Service
```bash
make up-stack
# or
docker compose -f docker-compose.yml -f docker-compose.stack.yml up redis
```

### Check Health
```bash
make health-redis
# or
docker compose exec redis redis-cli ping
```

### Connect to Redis
```bash
# Interactive CLI
docker compose exec redis redis-cli

# With authentication (if password set)
docker compose exec redis redis-cli -a <password>
```

---

## Common Use Cases

### 1. Caching
```bash
# Store cache entry with TTL
SET user:123:profile '{"name":"John"}' EX 3600

# Get cached value
GET user:123:profile

# Check TTL
TTL user:123:profile
```

### 2. Session Storage
```bash
# Store session
SETEX session:abc123 1800 '{"user_id":123,"role":"admin"}'

# Get session
GET session:abc123

# Delete session (logout)
DEL session:abc123
```

### 3. Rate Limiting
```bash
# Increment request counter
INCR rate:user:123:requests

# Set expiration on first request
EXPIRE rate:user:123:requests 60

# Check if rate limited
GET rate:user:123:requests
# If > threshold, reject request
```

### 4. Distributed Locks
```bash
# Acquire lock
SET lock:resource:123 "worker-1" NX EX 10

# Release lock
DEL lock:resource:123
```

### 5. Leaderboards (Sorted Sets)
```bash
# Add scores
ZADD leaderboard 100 "player1"
ZADD leaderboard 150 "player2"
ZADD leaderboard 120 "player3"

# Get top 10
ZREVRANGE leaderboard 0 9 WITHSCORES
```

---

## Client Libraries

Redis has clients for all major languages:
- **Go:** `github.com/redis/go-redis`
- **Python:** `redis-py`
- **JavaScript:** `ioredis`, `node-redis`
- **Java:** `Jedis`, `Lettuce`

### Example (Go)
```go
import "github.com/redis/go-redis/v9"

client := redis.NewClient(&redis.Options{
    Addr:     "localhost:6379",
    Password: "", // if set
    DB:       0,
})

// Set value
client.Set(ctx, "key", "value", time.Hour)

// Get value
val, err := client.Get(ctx, "key").Result()

// Increment
client.Incr(ctx, "counter")
```

---

## Data Persistence

### Persistence Options

#### RDB (Point-in-time snapshots)
```bash
# Save snapshot now
SAVE

# Configure automatic snapshots
# In redis.conf:
save 900 1     # After 900s if 1 key changed
save 300 10    # After 300s if 10 keys changed
save 60 10000  # After 60s if 10000 keys changed
```

#### AOF (Append-only file)
```bash
# Enable AOF in redis.conf
appendonly yes
appendfsync everysec  # Sync every second (balanced)
```

---

## Memory Management

### Eviction Policies
```bash
# Set in redis.conf or via CONFIG SET
maxmemory 256mb
maxmemory-policy allkeys-lru

# Policies:
# allkeys-lru    - Evict least recently used keys
# volatile-lru   - Evict LRU keys with TTL
# allkeys-random - Evict random keys
# volatile-ttl   - Evict keys with shortest TTL
# noeviction     - Return errors when memory full
```

### Check Memory Usage
```bash
# Memory stats
INFO memory

# See largest keys
redis-cli --bigkeys
```

---

## Monitoring

### Key Metrics
- Memory usage
- Hit rate (cache effectiveness)
- Connected clients
- Operations per second
- Slow commands

### Check Metrics
```bash
# General info
INFO

# Stats
INFO stats

# Memory
INFO memory

# Clients
CLIENT LIST

# Monitor commands in real-time
MONITOR
```

---

## Performance Tips

1. **Use Pipelining** - Batch multiple commands
2. **Use Connection Pooling** - Reuse connections
3. **Set Appropriate TTLs** - Prevent memory bloat
4. **Avoid Blocking Commands** - KEYS, SMEMBERS on large sets
5. **Use Redis Cluster** - For horizontal scaling

---

## Production Notes

1. **Set Password** - Always use authentication
2. **Resource Limits** - Set maxmemory
3. **Enable Persistence** - RDB + AOF for durability
4. **Monitoring** - Track hit rate, memory, latency
5. **Backup** - Regular RDB snapshots
6. **Redis Sentinel** - For automatic failover (HA)
7. **Redis Cluster** - For horizontal scaling

---

## Backup & Recovery

### Backup
```bash
# Create snapshot
docker compose exec redis redis-cli SAVE

# Copy RDB file
docker compose cp redis:/data/dump.rdb ./backup/

# Or use BGSAVE for non-blocking backup
docker compose exec redis redis-cli BGSAVE
```

### Restore
```bash
# Stop Redis
docker compose stop redis

# Copy RDB file back
docker compose cp ./backup/dump.rdb redis:/data/

# Start Redis
docker compose start redis
```

---

## See Also

- [Core Services](../../README.md)
- [Operations Guide](../../../docs/OPERATIONS.md)
- [Redis Documentation](https://redis.io/docs/)
- [Redis Best Practices](https://redis.io/docs/manual/patterns/)
# PostgreSQL - Primary Database

Relational database with vector search capabilities for the A.R.C. Framework.

---

## Overview

**PostgreSQL** provides:
- Relational data storage
- ACID transactions
- Vector similarity search (pgvector extension)
- JSON/JSONB support
- Full-text search
- Agent state persistence

---

## Ports

- **5432** - PostgreSQL server

---

## Configuration

**Files:**
- `.env.example` - Environment variables
- `init.sql` - Initialization script

### Key Features
- **pgvector Extension** - Vector embeddings for RAG
- **JSONB** - Flexible schema for agent data
- **Partitioning** - Scale large tables
- **Replication** - HA with streaming replication

---

## Environment Variables

See `.env.example` for configuration options.

**Key Variables:**
```bash
POSTGRES_USER=arc
POSTGRES_PASSWORD=<strong-password>  # CHANGE THIS!
POSTGRES_DB=arc
```

⚠️ **Security Warning:** Never use default passwords in production!

---

## Initialization

The `init.sql` script runs on first startup:
```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS agents;
CREATE SCHEMA IF NOT EXISTS events;
```

---

## Usage

### Start Service
```bash
make up-stack
# or
docker compose -f docker-compose.yml -f docker-compose.stack.yml up postgres
```

### Check Health
```bash
make health-postgres
# or
docker compose exec postgres pg_isready
```

### Connect to Database
```bash
# Interactive shell
make shell-postgres
# or
docker compose exec postgres psql -U arc -d arc

# From host (requires psql installed)
psql -h localhost -U arc -d arc
```

### Run Migrations
```bash
make migrate-postgres
```

---

## Schema Design

### Recommended Structure
```sql
-- Agents table
CREATE TABLE agents.agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    config JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Agent state with vector embeddings
CREATE TABLE agents.memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID REFERENCES agents.agents(id),
    content TEXT,
    embedding vector(1536),  -- For OpenAI embeddings
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create vector index for similarity search
CREATE INDEX ON agents.memories USING ivfflat (embedding vector_cosine_ops);
```

---

## Vector Search (pgvector)

### Store Embeddings
```sql
INSERT INTO agents.memories (agent_id, content, embedding)
VALUES (
    'agent-id',
    'Some text content',
    '[0.1, 0.2, 0.3, ...]'::vector
);
```

### Similarity Search
```sql
-- Find similar memories (cosine similarity)
SELECT 
    content,
    1 - (embedding <=> query_vector) AS similarity
FROM agents.memories
WHERE agent_id = 'agent-id'
ORDER BY embedding <=> query_vector
LIMIT 10;
```

---

## Backup & Recovery

### Manual Backup
```bash
# Backup database
docker compose exec postgres pg_dump -U arc arc > backup.sql

# Backup with compression
docker compose exec postgres pg_dump -U arc arc | gzip > backup.sql.gz
```

### Restore
```bash
# Restore from backup
docker compose exec -T postgres psql -U arc arc < backup.sql

# Restore from compressed backup
gunzip -c backup.sql.gz | docker compose exec -T postgres psql -U arc arc
```

### Automated Backups
See [Operations Guide](../../../docs/OPERATIONS.md) for automated backup procedures.

---

## Monitoring

### Key Metrics
- Connection count
- Active queries
- Database size
- Cache hit ratio
- Lock waits
- Replication lag (if using replication)

### Check Metrics
```sql
-- Connection count
SELECT count(*) FROM pg_stat_activity;

-- Database size
SELECT pg_size_pretty(pg_database_size('arc'));

-- Cache hit ratio
SELECT 
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as cache_hit_ratio
FROM pg_statio_user_tables;

-- Active queries
SELECT pid, now() - query_start as duration, query 
FROM pg_stat_activity 
WHERE state = 'active';
```

---

## Performance Tuning

### Configuration
```bash
# Adjust in docker-compose.yml or postgresql.conf
shared_buffers=256MB          # 25% of RAM
effective_cache_size=1GB      # 50-75% of RAM
work_mem=16MB                 # Per query work memory
maintenance_work_mem=128MB    # For VACUUM, CREATE INDEX
```

### Indexes
```sql
-- Create indexes on frequently queried columns
CREATE INDEX idx_agents_type ON agents.agents(type);
CREATE INDEX idx_memories_agent_id ON agents.memories(agent_id);

-- Vector index for similarity search
CREATE INDEX idx_memories_embedding ON agents.memories 
USING ivfflat (embedding vector_cosine_ops);
```

---

## Production Notes

1. **Use Strong Passwords** - Never use defaults
2. **Enable SSL** - Configure SSL certificates
3. **Set Resource Limits** - Configure memory and CPU limits
4. **Regular Backups** - Automated daily backups
5. **Monitoring** - Monitor connection pool, slow queries
6. **Replication** - Set up streaming replication for HA
7. **Connection Pooling** - Use PgBouncer for connection pooling

---

## See Also

- [Core Services](../../README.md)
- [Operations Guide](../../../docs/OPERATIONS.md)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)

