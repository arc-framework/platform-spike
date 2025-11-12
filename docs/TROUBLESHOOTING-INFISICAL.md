# Troubleshooting Infisical

**Last Updated:** November 9, 2025

---

## Common Issues

### Issue 1: Infisical Container Restarting

**Symptoms:**
- Container shows `Restarting (1)` status
- Logs show: `relation "super_admin" does not exist`

**Root Cause:**
Infisical requires database schema to be initialized before it can start. The error occurs because Infisical is trying to query tables that don't exist yet.

**Solution:**

The Infisical Docker image should automatically run migrations on startup. If it's not:

1. **Check the database connection:**
   ```bash
   docker exec arc_postgres psql -U arc -d arc_db -c "SELECT version();"
   ```

2. **Verify Infisical environment variables:**
   ```bash
   docker inspect arc_infisical --format '{{range .Config.Env}}{{println .}}{{end}}' | grep DB_CONNECTION_URI
   ```

3. **Check if Infisical schema exists:**
   ```bash
   docker exec arc_postgres psql -U arc -d arc_db -c "\dt" | grep super_admin
   ```

4. **Force restart Infisical to trigger migration:**
   ```bash
   docker restart arc_infisical
   docker logs -f arc_infisical
   ```

5. **If still failing, check Infisical version compatibility:**
   - The image `infisical/infisical:v0.46.0-postgres` should auto-migrate
   - Verify Postgres version is compatible (we're using PostgreSQL 17)

---

## Workarounds

### Option 1: Use Separate Postgres Database

Infisical might prefer its own database instance to avoid conflicts:

```yaml
environment:
  DB_CONNECTION_URI: "postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@arc_postgres:5432/infisical_db?sslmode=disable"
```

Then create the database:
```bash
docker exec arc_postgres psql -U arc -c "CREATE DATABASE infisical_db;"
docker restart arc_infisical
```

### Option 2: Manual Migration

If auto-migration fails, run migrations manually:

```bash
# Enter the container
docker exec -it arc_infisical sh

# Run migrations (if available)
npm run migration:latest
# OR
yarn migration:latest
```

### Option 3: Increase Start Period

The healthcheck might be failing too quickly. Update docker-compose.yml:

```yaml
healthcheck:
  start_period: 60s  # Increase from 20s
  retries: 10        # Increase from 5
```

---

## Verification

After applying fixes, verify Infisical is working:

```bash
# Check container status
docker ps | grep infisical

# Check health
curl http://localhost:3001/api/status

# Check logs
docker logs arc_infisical --tail 50

# Test web UI
open http://localhost:3001
```

---

## Known Limitations

1. **First Startup**: Infisical may take 30-60 seconds on first startup to initialize schema
2. **Postgres Version**: Infisical v0.46.0 is tested with PostgreSQL 14-15, we're using 17
3. **Schema Conflicts**: Sharing database with other services may cause table name conflicts

---

## Recommended Configuration

For production use, consider:

1. **Separate Database**: Give Infisical its own PostgreSQL database
2. **Volume Persistence**: Ensure Postgres data is persisted
3. **Health Check Tuning**: Adjust timeouts based on your environment
4. **Connection Pooling**: Configure appropriate connection limits

---

## Alternative: Disable Infisical

If not needed immediately, you can disable Infisical:

```bash
# Comment out in docker-compose or use profiles
docker-compose --profile core up -d
```

Then use environment variables or Infisical Cloud instead of self-hosted.

