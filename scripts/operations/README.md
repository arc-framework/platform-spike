# Operations Scripts
**Status:** 🚧 Active Development
Operational maintenance and management scripts.
---
## Note
Journal generation script has moved to `tools/journal/generate-journal.sh`.
---

## Available Scripts

### Health Check & Diagnostics

#### `apply-health-fixes.sh`
**Status:** ✅ Active  
Applies fixes for Infisical database configuration and Traefik health check issues.

```bash
./scripts/operations/apply-health-fixes.sh
```

**What it does:**
- Creates separate `infisical_db` database for Infisical
- Restarts Infisical with updated configuration
- Verifies Traefik health endpoint
- Reports health status of both services

#### `diagnose-health.sh`
**Status:** ✅ Active  
Comprehensive diagnostic script for troubleshooting service health issues.

```bash
./scripts/operations/diagnose-health.sh
```

**What it checks:**
- Infisical container status and logs
- Traefik container status and health
- Postgres database connectivity
- Service API endpoints

#### `fix-infisical.sh`
**Status:** ✅ Active  
Focused script for fixing Infisical-specific database issues.

```bash
./scripts/operations/fix-infisical.sh
```

**What it does:**
- Creates infisical_db database
- Removes and recreates Infisical container
- Waits for Infisical to initialize (up to 60s)
- Reports final status

#### `init-infisical.sh`
**Status:** ✅ Active  
Initialization script for Infisical database migrations.

```bash
./scripts/operations/init-infisical.sh
```

**What it does:**
- Checks if Infisical is running
- Attempts to run Infisical migrations
- Waits for Infisical to become healthy

---

## Planned Scripts

- `backup.sh` - Backup data volumes
- `restore.sh` - Restore from backup  
- `rotate-logs.sh` - Log rotation

---

## Related Documentation

- [Health Check Fixes](../../docs/HEALTH-CHECK-FIXES.md) - Details on recent health check fixes
- [Troubleshooting Infisical](../../docs/TROUBLESHOOTING-INFISICAL.md) - Infisical-specific troubleshooting
- [Operations Guide](../../docs/OPERATIONS.md) - General operations guide
- [Scripts Overview](../) - Main scripts directory

---
