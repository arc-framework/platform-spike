# Health Check Fixes - November 9, 2025

## Issues Identified

### 1. Infisical Container Restarting
**Problem:** Infisical was crash-looping with database error: `relation "super_admin" does not exist`

**Root Cause:** Infisical was trying to use the shared `arc_db` database which didn't have its schema initialized, and it was failing before it could run migrations.

**Solution:**
- Changed Infisical to use a separate `infisical_db` database
- Increased healthcheck `start_period` from 20s to 60s
- Increased healthcheck `retries` from 5 to 10
- Updated postgres init.sql to create the infisical_db database automatically

### 2. Traefik Health Check Failing
**Problem:** `make health-core` reported Traefik as unhealthy even though `docker ps` showed it as healthy

**Root Cause:** The Makefile was checking `http://localhost:8080/ping` but Traefik's ping endpoint is configured on the "web" entrypoint (port 80), not port 8080.

**Solution:**
- Updated Makefile health check to use `http://localhost:80/ping` instead of port 8080

## Files Modified

1. **deployments/docker/docker-compose.core.yml**
   - Changed Infisical `DB_CONNECTION_URI` to use `infisical_db` instead of `arc_db`
   - Increased `start_period: 60s` (was 20s)
   - Increased `retries: 10` (was 5)

2. **core/persistence/postgres/init.sql**
   - Added infisical_db creation on postgres initialization

3. **Makefile**
   - Fixed Traefik health check to use port 80 instead of 8080

## Scripts Created

1. **scripts/operations/apply-health-fixes.sh**
   - Automated script to apply all fixes
   - Creates infisical_db database
   - Restarts Infisical
   - Verifies health status

2. **scripts/operations/fix-infisical.sh**
   - Focused script for fixing Infisical issues only

3. **scripts/operations/diagnose-health.sh**
   - Diagnostic script for troubleshooting health issues

4. **docs/TROUBLESHOOTING-INFISICAL.md**
   - Comprehensive troubleshooting guide for Infisical issues

## How to Apply Fixes

### Option 1: Automated (Recommended)
```bash
./scripts/operations/apply-health-fixes.sh
```

### Option 2: Manual
```bash
# Create the database
docker exec arc_postgres psql -U arc -c "CREATE DATABASE infisical_db;"

# Restart services with new configuration
make down
make up

# Verify
make health-all
```

### For Existing Installations
If you already have services running:
```bash
# Create database
docker exec arc_postgres psql -U arc -c "CREATE DATABASE infisical_db;"

# Restart Infisical
docker restart arc_infisical

# Wait for initialization (may take 60 seconds)
docker logs -f arc_infisical
```

## Verification

After applying fixes:

```bash
# Check all service health
make health-all

# Verify Traefik
curl http://localhost:80/ping
# Should return: OK

# Verify Infisical
curl http://localhost:3001/api/status
# Should return: {"message":"Ok"}

# Check Infisical UI
open http://localhost:3001
```

## Expected Results

- **Traefik**: Should show ✓ Healthy in `make health-core`
- **Infisical**: Should start successfully and reach healthy state within 60 seconds
- **Other Services**: Should remain unaffected

## Rollback

If issues occur:

```bash
# Stop everything
make down

# Restore original database connection (if needed)
# Edit deployments/docker/docker-compose.core.yml
# Change DB_CONNECTION_URI back to arc_db

# Start fresh
make up
```

## Notes

- The init.sql changes only affect NEW postgres containers
- For existing postgres containers, the database must be created manually
- Infisical will automatically create its schema on first connection to infisical_db
- The separate database approach prevents table name conflicts and is recommended for production

## Related Documentation

- [TROUBLESHOOTING-INFISICAL.md](TROUBLESHOOTING-INFISICAL.md)
- [OPERATIONS.md](OPERATIONS.md)
- [Infisical README](../core/secrets/infisical/README.md)

