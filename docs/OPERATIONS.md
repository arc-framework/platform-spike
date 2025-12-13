# A.R.C. Platform Spike - Operations Guide

This guide covers enterprise-grade operations, deployment patterns, monitoring, and troubleshooting for the A.R.C. platform spike.

---

## Table of Contents

1. [Environment Configuration](#environment-configuration)
2. [Service Lifecycle Management](#service-lifecycle-management)
3. [Monitoring & Observability](#monitoring--observability)
4. [Database Operations](#database-operations)
5. [Backup & Recovery](#backup--recovery)
6. [Scaling & Performance](#scaling--performance)
7. [Security Best Practices](#security-best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Environment Configuration

### Multi-Environment Setup

A.R.C. supports three environment tiers via dedicated `.env` files:

#### Development (Local)

```bash
cp .env.example .env.dev
# Edit .env.dev with development values
make up  # Loads .env by default; override with ENV_FILE=.env.dev
```

#### Staging

```bash
cp .env.example .env.staging
# Edit .env.staging with staging values (reduced resource limits, test credentials)
ENV_FILE=.env.staging make up
```

#### Production

```bash
cp .env.example .env.prod
# Edit .env.prod with production values (strong secrets, high resource limits)
ENV_FILE=.env.prod docker compose -f docker-compose.yml -f docker-compose.stack.yml up -d
```

### Configuration Best Practices

1. **Separate config directories per environment**:

   ```
   config/
     postgres/
       .env.example
       .env.dev
       .env.staging
       .env.prod
     kratos/
       .env.example
       .env.dev
       ...
   ```

2. **Use environment-specific overrides**:

   ```bash
   # Load base config, then layer environment-specific config
   export $(cat .env.dev | xargs)
   make up
   ```

3. **Store secrets in secure vaults** (for production):
   - Use `docker secret` instead of `.env` files
   - Use `aws secrets manager`, `HashiCorp Vault`, or `Infisical` (already in stack)

---

## Service Lifecycle Management

### Health Monitoring

Monitor service health continuously:

```bash
# One-time health check
make health-all

# Continuous health monitoring (every 10s)
watch -n 10 'make health-all'

# Monitor specific service
watch -n 5 'make health-postgres'
```

### Graceful Shutdown Sequence

```bash
# Stop services gracefully (preserves data)
make down

# Hard stop (kill all immediately)
docker compose kill

# Remove everything including volumes (DATA LOSS)
make clean
```

### Blue-Green Deployment

For zero-downtime updates:

```bash
# Keep current stack running
make ps

# Prepare new stack in parallel
COMPOSE_PROJECT_NAME=arc-v2 docker compose -f docker-compose.yml -f docker-compose.stack.yml up -d

# Test new stack
COMPOSE_PROJECT_NAME=arc-v2 make health-all

# Switch traffic to new stack (via Traefik routing)
# ...

# Tear down old stack
COMPOSE_PROJECT_NAME=arc-v1 docker compose down
```

---

## Monitoring & Observability

### Key Metrics to Track

#### Infrastructure

- Container restarts: `docker stats --no-stream`
- Disk usage: `df -h` and `docker volume ls`
- Network I/O: `docker stats`
- Memory pressure: Watch for OOMkill events

#### Application

- Trace latency: Query Jaeger for P95/P99 latencies
- Error rates: Graph error spans in Grafana
- Log volumes: Monitor Loki ingestion rate

#### Data Layer

```sql
-- Postgres table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables ORDER BY pg_total_relation_size DESC;

-- Connection count
SELECT count(*) FROM pg_stat_activity;
```

### Alerting Setup

Configure alerts in Grafana:

```bash
# Access Grafana
open http://localhost:3000

# Navigate to: Alerting > Alert Rules > Create Alert
# Example: Alert if Postgres CPU > 80%
```

---

## Database Operations

### Postgres Maintenance

```bash
# Connect to Postgres
make shell-postgres

# Analyze query performance
EXPLAIN ANALYZE SELECT * FROM my_table WHERE id = 1;

# Vacuum and analyze (maintenance)
VACUUM ANALYZE;

# Check slow queries
SELECT query, calls, total_time FROM pg_stat_statements
  ORDER BY total_time DESC LIMIT 10;

# Dump database
docker exec arc_postgres pg_dump -U arc arc_db > backup_$(date +%Y%m%d).sql

# Restore database
docker exec arc_postgres psql -U arc arc_db < backup.sql
```

### Redis Operations

```bash
# Connect to Redis
make shell-redis

# Monitor journal in real-time
MONITOR

# View memory usage
INFO memory

# Find large keys
SCAN 0 MATCH * TYPE string | xargs -L 1 STRLEN

# Clear expired keys
DEBUG OBJECT key_name

# Dump and restore
redis-cli --rdb dump.rdb
redis-cli < dump.rdb
```

### Backup Strategy

Implement daily backups:

```bash
#!/bin/bash
# backup.sh - Run daily via cron

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/backups/arc-platform-spike

mkdir -p $BACKUP_DIR

# Postgres
docker exec arc_postgres pg_dump -U arc arc_db | gzip > $BACKUP_DIR/postgres_$DATE.sql.gz

# Redis
docker exec arc_redis redis-cli BGSAVE
docker exec arc_redis redis-cli LASTSAVE | xargs -I {} cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis_$DATE.rdb

# Uploaded to S3 (example)
aws s3 sync $BACKUP_DIR s3://my-backup-bucket/arc-spike/

# Cleanup old backups (keep last 30 days)
find $BACKUP_DIR -type f -mtime +30 -delete
```

---

## Backup & Recovery

### Disaster Recovery Plan

**RTO (Recovery Time Objective)**: < 30 minutes
**RPO (Recovery Point Objective)**: < 1 hour

#### Recovery Steps

1. **Restore Postgres**:

   ```bash
   # Stop current services
   make down

   # Restore from backup
   docker compose up -d postgres
   docker exec arc_postgres psql -U arc arc_db < backup.sql

   # Start remaining services
   docker compose up -d
   ```

2. **Restore Redis**:

   ```bash
   docker compose up -d redis
   docker cp redis_backup.rdb arc_redis:/data/dump.rdb
   docker exec arc_redis redis-cli SHUTDOWN
   docker restart arc_redis
   ```

3. **Validate services**:
   ```bash
   make health-all
   ```

---

## Scaling & Performance

### Horizontal Scaling (Multiple Instances)

Use Traefik for load balancing:

```yaml
# docker-compose.stack.yml
services:
  raymond:
    deploy:
      replicas: 3
    labels:
      traefik.enable: 'true'
      traefik.http.services.raymond.loadbalancer.server.port: '8081'
```

### Vertical Scaling (Resource Limits)

Edit resource limits in compose files:

```yaml
services:
  postgres:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '1'
        memory: 1G
```

### Performance Tuning

#### Postgres

```bash
# Increase max connections
docker exec arc_postgres psql -U arc -c "ALTER SYSTEM SET max_connections = 200;"
docker restart arc_postgres
```

#### Redis

```bash
# Increase memory limit
# Edit config/redis/.env.example:
# REDIS_MAXMEMORY=2gb
```

#### Pulsar

```bash
# Increase broker threads
# Edit config/pulsar/.env.example:
# PULSAR_NUM_IO_THREADS=10
```

---

## Security Best Practices

### Secrets Management

1. **Never commit `.env` files** containing real secrets
2. **Use `docker secret` for orchestration**:

   ```bash
   echo "my-password" | docker secret create postgres_password -
   ```

3. **Use Infisical for centralized secrets**:
   - Store all secrets in Infisical (in the stack)
   - Retrieve secrets via Infisical API at runtime
   - Rotate secrets without redeploying

### Network Isolation

1. **Expose only necessary ports**:

   ```yaml
   # Remove external port mappings for internal-only services
   redis:
     # ports:
     #   - "6379:6379"  # Only expose if needed
     networks:
       - arc_net
   ```

2. **Use Traefik for public-facing services**:
   - Single entry point on port 80/443
   - TLS termination at Traefik
   - Rate limiting and authentication via middleware

### TLS/SSL

Enable TLS in production:

```yaml
# config/traefik/traefik.yml
entryPoints:
  websecure:
    address: ':443'
    tls:
      certResolver: letsencrypt
```

### Database Security

```bash
# Connect with TLS
# Edit config/postgres/.env.example:
# POSTGRES_SSL_MODE=require

# Restrict connections
# docker exec arc_postgres psql -U arc -c "ALTER ROLE arc WITH PASSWORD 'strong-password';"
```

---

## Troubleshooting

### Common Issues & Solutions

#### Services Hang on Startup

**Symptom**: Services stuck in "restarting" loop

```bash
# Check logs
make logs

# Check resource constraints
docker stats

# Solutions:
# 1. Increase timeout in docker-compose
# 2. Check health check configuration
# 3. Review startup dependencies (depends_on)
```

#### High Memory Usage

**Symptom**: Docker reports OOMkill events

```bash
# Check which service is consuming memory
docker stats --no-stream

# Solutions:
# 1. Reduce Pulsar memory: PULSAR_MEM=-Xms64m -Xmx256m
# 2. Reduce Postgres work_mem: ALTER SYSTEM SET work_mem = '64MB';
# 3. Add memory swap: docker run -m 4g --memory-swap 8g
```

#### Database Migrations Fail

**Symptom**: Kratos/Unleash/Infisical won't start with DB errors

```bash
# Check Postgres is healthy
make health-postgres

# Check migrations manually
docker exec arc_postgres psql -U arc -l  # List databases

# Run migrations explicitly
make migrate-kratos
make migrate-unleash
make migrate-infisical

# Check logs
make logs-service SERVICE=kratos
```

#### Connectivity Between Services

**Symptom**: "Connection refused" or "Network unreachable"

```bash
# Test DNS resolution
docker exec arc-raymond-services nslookup postgres

# Test port connectivity
docker exec arc-raymond-services nc -zv postgres 5432

# Check network
docker network inspect arc_net

# Solutions:
# 1. Ensure services are on same network (arc_net)
# 2. Check firewall/iptables on host
# 3. Verify service names match (dns names in compose)
```

#### Logs Not Appearing in Grafana

**Symptom**: Logs sent to OTel Collector but not visible in Loki

```bash
# Check OTel Collector health
make health-otel

# Check Loki health
make health-loki

# Verify collector config
cat config/otel-collector-config.yml | grep -A 10 "exporters:"

# Check OTel collector logs
make logs-service SERVICE=otel-collector

# Solutions:
# 1. Verify OTLP endpoint in app (OTEL_EXPORTER_OTLP_ENDPOINT)
# 2. Check OTel receiver is enabled
# 3. Check Loki exporter endpoint in collector config
```

### Debug Mode

Enable debug logging across all services:

```bash
# In each .env file, set:
# SERVICE_LOG_LEVEL=debug

# Or for specific service:
make logs-service SERVICE=postgres | grep ERROR
```

### Collecting Diagnostics

For support/debugging:

```bash
# Collect full diagnostic bundle
mkdir arc-diagnostics
docker compose -f docker-compose.yml -f docker-compose.stack.yml ps > arc-diagnostics/services.txt
docker stats --no-stream > arc-diagnostics/resources.txt
make logs > arc-diagnostics/logs.txt 2>&1
docker volume ls > arc-diagnostics/volumes.txt
docker network ls > arc-diagnostics/networks.txt
docker exec arc_postgres psql -U arc -l > arc-diagnostics/postgres_dbs.txt 2>&1

# Compress and share
tar -czf arc-diagnostics.tar.gz arc-diagnostics/
```

---

## Maintenance Windows

### Weekly

- Check disk usage: `df -h`
- Review error logs: Filter ERROR in Loki
- Monitor slowest queries: Check pg_stat_statements

### Monthly

- Rotate secrets (if not using automated rotation)
- Upgrade images to latest patches (test in dev first)
- Run `VACUUM ANALYZE` on Postgres
- Archive old traces/logs

### Quarterly

- Disaster recovery drill (practice restoring from backup)
- Load testing (with replica setup)
- Security audit (review access logs, check for anomalies)

---

## Support & Escalation

For issues not covered here:

1. Check logs: `make logs`
2. Check health: `make health-all`
3. Collect diagnostics (see above)
4. Review [README.md](./README.md) Service Reference
5. Check A.R.C. framework documentation: https://github.com/arc-framework
6. Open an issue with diagnostics attached
