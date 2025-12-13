# Migration Guide: Docker Compose & Makefile Restructure

**Date:** November 9, 2025  
**Version:** 1.0 → 2.0  
**Type:** Breaking Changes  
**Status:** 🔄 Migration Required

---

## Overview

The A.R.C. Framework has been restructured to align with the documented Core + Plugins architecture. This migration guide will help you transition from the old setup to the new enterprise-grade structure.

---

## What Changed

### 1. Docker Compose File Structure

**Old Structure:**

```
docker-compose.yml        # Observability services
docker-compose.stack.yml  # Platform services (mixed core + plugins)
```

**New Structure:**

```
docker-compose.base.yml           # Shared resources (networks, volumes)
docker-compose.core.yml           # Required core services
docker-compose.observability.yml  # Observability plugins
docker-compose.security.yml       # Security plugins
docker-compose.services.yml       # Application services
```

### 2. Container Names Standardized

All containers now use the `arc_` prefix for consistency:

| Old Name         | New Name             |
| ---------------- | -------------------- |
| `loki`           | `arc_loki`           |
| `grafana`        | `arc_grafana`        |
| `prometheus`     | `arc_prometheus`     |
| `jaeger`         | `arc_jaeger`         |
| `otel-collector` | `arc_otel_collector` |
| `arc_raymond`    | `arc_raymond`        |
| `nats`           | `arc_nats`           |
| `pulsar`         | `arc_pulsar`         |

### 3. Volume Mount Paths Corrected

**Old Paths (incorrect):**

```yaml
./config/observability/grafana/provisioning
./config/platform/postgres/init.sql
./config/platform/kratos
./services/raymond # Wrong path
```

**New Paths (correct):**

```yaml
./plugins/observability/visualization/grafana/provisioning
./core/persistence/postgres/init.sql
./plugins/security/identity/kratos
./services/utilities/raymond # Correct path
```

### 4. Deployment Profiles Added

New profile-based deployment system:

- **Minimal:** Core services only (~2GB RAM)
- **Observability:** Core + Observability (~4GB RAM)
- **Security:** Core + Observability + Security (~5GB RAM)
- **Full:** All services (~6GB RAM)

### 5. Enhanced Makefile

**New Targets:**

- `make up-minimal` - Start core only
- `make up-observability` - Start core + observability
- `make up-security` - Start core + observability + security
- `make up-full` - Start everything
- `make init` - Initialize environment
- `make validate` - Validate configuration
- `make backup-db` - Backup database
- `make restore-db` - Restore database

**Improved Targets:**

- Better health checks with formatted output
- Enhanced help system with categories
- Colored output for better UX
- Profile-based service management

---

## Migration Steps

### Step 1: Backup Current Setup

```bash
# Backup existing files
cp docker-compose.yml docker-compose.yml.backup
cp docker-compose.stack.yml docker-compose.stack.yml.backup
cp Makefile Makefile.backup

# Backup database (optional but recommended)
make backup-db
```

### Step 2: Stop Existing Services

```bash
# Stop all running services
make down

# Verify all containers are stopped
docker ps -a | grep -E "loki|grafana|prometheus|jaeger|postgres|redis"
```

### Step 3: Update Docker Compose Files

The new files are already created:

- `docker-compose.base.yml` ✅
- `docker-compose.core.yml` ✅
- `docker-compose.observability.yml` ✅
- `docker-compose.security.yml` ✅
- `docker-compose.services.yml` ✅

### Step 4: Update Makefile

Replace the old Makefile:

```bash
# Backup is already done in Step 1
mv Makefile.new Makefile
```

### Step 5: Initialize New Environment

```bash
# Create network and volumes
make init

# Verify initialization
docker network ls | grep arc_net
docker volume ls | grep arc_
```

### Step 6: Start Services with New Structure

Choose your deployment profile:

```bash
# Option 1: Minimal (for development)
make up-minimal

# Option 2: Observability (for staging)
make up-observability

# Option 3: Full stack (for production)
make up-full
```

### Step 7: Verify Health

```bash
# Check all services
make health-all

# Check specific layers
make health-core
make health-observability
make health-security
```

### Step 8: Verify Data Persistence

```bash
# Check database connection
make shell-postgres

# Inside psql, verify data:
\dt
SELECT count(*) FROM your_table;  # If you had existing data
\q

# Check Redis
make shell-redis
# Inside redis-cli:
PING
KEYS *
exit
```

---

## Rollback Plan

If you encounter issues, you can rollback:

```bash
# Stop new services
docker compose -f docker-compose.base.yml \
  -f docker-compose.core.yml \
  -f docker-compose.observability.yml \
  -f docker-compose.security.yml \
  -f docker-compose.services.yml down

# Restore old files
mv Makefile.backup Makefile
mv docker-compose.yml.backup docker-compose.yml
mv docker-compose.stack.yml.backup docker-compose.stack.yml

# Start old services
make up

# Restore database if needed
make restore-db BACKUP_FILE=./backups/arc_db_YYYYMMDD_HHMMSS.sql
```

---

## Volume Persistence

**Important:** Docker volumes persist across container recreation by name. Your data is safe!

### Volume Mapping

| Old Volume      | New Volume            | Data Type  |
| --------------- | --------------------- | ---------- |
| `postgres-data` | `arc_postgres_data`   | Database   |
| `redis-data`    | `arc_redis_data`      | Cache      |
| N/A (unnamed)   | `arc_pulsar_data`     | Messages   |
| N/A (unnamed)   | `arc_prometheus_data` | Metrics    |
| N/A (unnamed)   | `arc_grafana_data`    | Dashboards |
| N/A (unnamed)   | `arc_loki_data`       | Logs       |

**Migration:**
If you have existing data in old volumes, migrate them:

```bash
# Example for postgres
docker run --rm -v postgres-data:/source -v arc_postgres_data:/target alpine \
  sh -c "cp -av /source/. /target/"

# Example for redis
docker run --rm -v redis-data:/source -v arc_redis_data:/target alpine \
  sh -c "cp -av /source/. /target/"
```

---

## Testing Checklist

After migration, verify:

- [ ] All containers start successfully
- [ ] All health checks pass (`make health-all`)
- [ ] Database data is accessible
- [ ] Redis cache works
- [ ] NATS messaging works
- [ ] Pulsar broker is healthy
- [ ] Grafana dashboards load
- [ ] Prometheus has targets
- [ ] Jaeger shows traces
- [ ] Loki receives logs
- [ ] OTel Collector accepts telemetry
- [ ] arc_raymond service responds

---

## Common Issues & Solutions

### Issue 1: Network Not Found

**Error:** `network arc_net declared as external, but could not be found`

**Solution:**

```bash
make init-network
```

### Issue 2: Volume Not Found

**Error:** `volume arc_postgres_data declared as external, but could not be found`

**Solution:**

```bash
make init-volumes
```

### Issue 3: Container Name Conflict

**Error:** `container name "arc_postgres" is already in use`

**Solution:**

```bash
# Remove old containers
docker rm -f $(docker ps -aq)

# Or remove specific container
docker rm -f arc_postgres
```

### Issue 4: Port Already in Use

**Error:** `bind: address already in use`

**Solution:**

```bash
# Find process using the port (example: port 5432)
lsof -i :5432

# Kill the process or stop the old service
make down
```

### Issue 5: Old Volumes Not Accessible

**Error:** Data from old setup not visible

**Solution:**

```bash
# Check existing volumes
docker volume ls

# If old volumes exist, migrate data (see Volume Persistence section)
```

---

## New Workflow Examples

### Development Workflow

```bash
# Initialize (first time only)
make init

# Start core services only
make up-minimal

# Check health
make health-core

# View logs
make logs-core

# Access services
make shell-postgres
make shell-redis

# Stop services
make down-minimal
```

### Production Workflow

```bash
# Initialize
make init

# Start full stack
make up-full

# Monitor health
watch -n 5 'make health-all'

# View logs by layer
make logs-core
make logs-observability
make logs-services

# Backup database regularly
make backup-db

# Stop gracefully
make down
```

### Testing Workflow

```bash
# Validate configuration
make validate

# Test specific profile
make up-observability
make test-connectivity
make health-observability

# Clean up
make down
```

---

## Environment Variables

The new structure supports better environment management:

```bash
# Development
ENV_FILE=.env.dev make up-minimal

# Staging
ENV_FILE=.env.staging make up-observability

# Production
ENV_FILE=.env.prod make up-full
```

---

## Documentation Updates

Updated documentation locations:

- **Operations Guide:** `docs/OPERATIONS.md`
- **Architecture:** `docs/architecture/README.md`
- **Naming Conventions:** `docs/guides/NAMING-CONVENTIONS.md`
- **Analysis Report:** `reports/2025/11/0911-MAKEFILE-ARCHITECTURE-ANALYSIS.md`
- **This Migration Guide:** `docs/guides/MIGRATION-v1-to-v2.md`

---

## Support

If you encounter issues:

1. Check this migration guide
2. Review `docs/OPERATIONS.md`
3. Run `make validate` to check configuration
4. Check service logs: `make logs`
5. Review health status: `make health-all`
6. Verify paths: `make validate-paths`

---

## Benefits of New Structure

✅ **Architecture Alignment:** Compose files match documented architecture  
✅ **Better Organization:** Clear separation of core, plugins, and services  
✅ **Profile-Based Deployment:** Choose services based on needs  
✅ **Resource Optimization:** Run only what you need (saves RAM)  
✅ **Consistent Naming:** All containers use `arc_` prefix  
✅ **Path Correctness:** Volume mounts reference actual directory structure  
✅ **Enhanced Makefile:** More targets, better UX, colored output  
✅ **Enterprise-Grade:** Follows best practices for production deployments  
✅ **Better Testability:** Validate architecture and configuration  
✅ **Easier Debugging:** Layer-specific logs and health checks

---

## Timeline

- **Old Structure Support:** Deprecated as of November 9, 2025
- **Migration Period:** November 9-16, 2025 (1 week)
- **Removal of Old Files:** November 16, 2025

**Action Required:** Migrate to new structure before November 16, 2025

---

**Questions or Issues?** Review `reports/2025/11/0911-MAKEFILE-ARCHITECTURE-ANALYSIS.md` for detailed analysis.
