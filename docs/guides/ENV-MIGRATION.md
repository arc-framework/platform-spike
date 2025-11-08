# Environment Configuration Migration

## Overview

The A.R.C. Framework has been updated to use a **centralized environment configuration** approach.

**Status:** ✅ Completed (November 9, 2025)

---

## What Changed

### Before (Distributed Configuration)
- Each service had its own `.env.example` file
- Configuration was scattered across multiple directories
- Difficult to maintain consistency
- Risk of missing required secrets

### After (Centralized Configuration)
- Single `.env.example` at project root
- All service configuration in one place
- Automated secret generation and validation
- Clear security requirements

---

## Migration Steps

If you have an existing installation with distributed `.env` files:

### 1. Backup Existing Configuration
```bash
# Backup any existing .env files
find . -name ".env" -exec cp {} {}.backup \;
```

### 2. Generate New Centralized Configuration
```bash
# Option A: Generate with secure random secrets (recommended)
make generate-secrets

# Option B: Copy from template and edit manually
cp .env.example .env
```

### 3. Migrate Custom Values
If you had custom configurations in service-specific `.env` files:

```bash
# Review backed up files
find . -name ".env.backup"

# Manually copy any custom values to root .env
```

### 4. Remove Old Files
```bash
# Remove distributed .env files (optional)
find core/ plugins/ services/ -name ".env" -delete
find core/ plugins/ services/ -name ".env.example" -type f
```

### 5. Validate Configuration
```bash
# Ensure all required secrets are set
make validate-secrets
```

---

## Configuration Mapping

### Core Services

| Old Location | New Location | Variable |
|-------------|--------------|----------|
| `core/persistence/postgres/.env` | `.env` (root) | `POSTGRES_*` |
| `core/caching/redis/.env` | `.env` (root) | *auto-configured* |
| `core/secrets/infisical/.env` | `.env` (root) | `INFISICAL_*` |
| `core/feature-management/unleash/.env` | `.env` (root) | `UNLEASH_*` |

### Observability Plugins

| Old Location | New Location | Variable |
|-------------|--------------|----------|
| `plugins/observability/visualization/grafana/.env` | `.env` (root) | `GRAFANA_*` |
| `plugins/observability/metrics/prometheus/.env` | `.env` (root) | *auto-configured* |
| `plugins/observability/logging/loki/.env` | `.env` (root) | *auto-configured* |
| `plugins/observability/tracing/jaeger/.env` | `.env` (root) | *auto-configured* |

### Security Plugins

| Old Location | New Location | Variable |
|-------------|--------------|----------|
| `plugins/security/identity/kratos/.env` | `.env` (root) | `KRATOS_*` |

---

## Benefits

### ✅ Security Improvements
- **No weak defaults**: All passwords must be explicitly set
- **Automated validation**: Pre-flight checks before deployment
- **Secure generation**: Cryptographically strong random secrets
- **Clear requirements**: Error messages show exactly what's needed

### ✅ Operational Improvements
- **Single source of truth**: All configuration in one file
- **Easier management**: No need to update multiple files
- **Better documentation**: All variables documented in one place
- **Version control friendly**: Single `.env.example` to maintain

### ✅ Developer Experience
- **Quick setup**: `make generate-secrets` creates everything
- **Clear errors**: Validation catches missing/weak secrets
- **Consistent naming**: All variables follow same pattern
- **IDE support**: Single file for autocomplete

---

## Environment Variable Reference

All environment variables are now documented in the root `.env.example` file.

### Required Variables (Must be set)
```bash
POSTGRES_PASSWORD              # PostgreSQL database password
INFISICAL_ENCRYPTION_KEY       # Infisical encryption key
INFISICAL_AUTH_SECRET          # Infisical authentication secret
UNLEASH_API_TOKEN             # Unleash frontend API token
UNLEASH_CLIENT_TOKEN          # Unleash client API token
GRAFANA_ADMIN_PASSWORD        # Grafana admin password
KRATOS_SECRET_COOKIE          # Kratos session cookie secret
KRATOS_SECRET_CIPHER          # Kratos encryption cipher secret
```

### Optional Variables (Have defaults)
```bash
POSTGRES_USER=arc             # PostgreSQL username
POSTGRES_DB=arc_db            # PostgreSQL database name
GRAFANA_ADMIN_USER=admin      # Grafana admin username
SWISS_ARMY_PORT=8080          # Application service port
LOG_LEVEL=info                # Global log level
```

---

## Troubleshooting

### "Cannot find .env file"
Run `make init-env` or `make generate-secrets` to create it.

### "POSTGRES_PASSWORD must be set"
The `.env` file exists but contains placeholder values. Run:
```bash
make generate-secrets
```

### "Service-specific .env not found"
This is expected. All configuration is now in the root `.env` file.

### "Variables not being picked up"
Ensure you're using the updated Makefile commands:
```bash
make down
make up
```

The Makefile now properly passes `--env-file .env` to all compose commands.

---

## Backward Compatibility

### Local Development
If you need service-specific overrides for local development:

1. Create `.env.local` (this is gitignored)
2. Set `ENV_FILE=.env.local` when running make commands:
   ```bash
   ENV_FILE=.env.local make up
   ```

### CI/CD Environments
The `ENV_FILE` variable can be overridden:
```bash
ENV_FILE=.env.production make up
ENV_FILE=.env.staging make up
```

---

## Related Changes

This migration is part of the security improvements documented in:
- [Concerns Report](../../reports/2025/11/0911-CONCERNS_AND_ACTION_PLAN.md)
- [Setup Scripts](../../scripts/setup/README.md)
- [Environment Template](../../.env.example)

---

**Migration completed:** November 9, 2025  
**Breaking change:** Yes - requires regeneration of `.env` file  
**Action required:** Run `make generate-secrets` or update `.env` manually

