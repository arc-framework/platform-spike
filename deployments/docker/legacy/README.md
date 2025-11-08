# Legacy Docker Compose Files

**Status:** ⚠️ DEPRECATED  
**Deprecation Date:** November 9, 2025  
**Removal Date:** November 16, 2025 (1 week)  

---

## ⚠️ These Files Are Deprecated

The Docker Compose files in this directory are from the old structure (v1.0) and are **no longer maintained**.

---

## Migration Required

**Please migrate to the new structure immediately.**

### Old Structure (DEPRECATED)
```
docker-compose.yml        # Observability services
docker-compose.stack.yml  # Mixed core + plugin services
```

### New Structure (ACTIVE)
```
deployments/docker/
├── docker-compose.base.yml           # Shared resources
├── docker-compose.core.yml           # Core services
├── docker-compose.observability.yml  # Observability plugins
├── docker-compose.security.yml       # Security plugins
└── docker-compose.services.yml       # Application services
```

---

## How to Migrate

See the comprehensive migration guide:

**📄 docs/guides/MIGRATION-v1-to-v2.md**

Quick migration steps:

```bash
# 1. Stop old services
make down

# 2. Backup database (optional but recommended)
make backup-db

# 3. Start with new structure
make up-full

# 4. Verify everything works
make health-all
```

---

## What Changed

1. **File Organization** - Split into logical layers (base, core, plugins, services)
2. **Container Names** - All use `arc_` prefix
3. **Paths** - Fixed to reference actual directory structure (core/, plugins/)
4. **Profiles** - Added deployment profiles (minimal, observability, security, full)
5. **Makefile** - Enterprise-grade with better targets and UX

---

## Why These Files Are Kept

These legacy files are temporarily preserved for:
1. Reference during migration
2. Rollback capability (if needed)
3. Comparison with new structure

**They will be removed on November 16, 2025.**

---

## Need Help?

- **Migration Guide:** docs/guides/MIGRATION-v1-to-v2.md
- **Analysis Report:** reports/2025/11/0911-MAKEFILE-ARCHITECTURE-ANALYSIS.md
- **Operations Guide:** docs/OPERATIONS.md
- **New Structure README:** deployments/docker/README.md

---

## Do Not Use These Files

❌ **DO NOT** start services using these files:
```bash
# Don't do this:
docker compose -f deployments/docker/legacy/docker-compose.yml up

# Do this instead:
make up-full
```

---

**Action Required:** Migrate to new structure before November 16, 2025.

