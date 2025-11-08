# Setup Scripts

Scripts for initializing and configuring the A.R.C. Framework platform.

## Status: ✅ Active

---

## Available Scripts

### `generate-secrets.sh`

Generates secure random secrets and creates a production-ready `.env` file.

**Usage:**
```bash
./scripts/setup/generate-secrets.sh
```

**Features:**
- Generates cryptographically secure random secrets using OpenSSL
- Creates `.env` file with all required configuration
- Backs up existing `.env` file before overwriting
- Displays summary of generated credentials
- Prevents accidental overwrites with confirmation prompt

**Generated Secrets:**
- PostgreSQL password (32 chars base64)
- Infisical encryption key and auth secret (32 chars base64)
- Unleash API and client tokens (64 chars hex)
- Grafana admin password (32 chars base64)
- Kratos cookie and cipher secrets (32 chars base64)

**Example Output:**
```
=================================================================
A.R.C. Framework - Generate Secrets
=================================================================

Generating secure secrets...

✓ Generated .env file with secure secrets

=================================================================
Credentials Summary
=================================================================

PostgreSQL:
  User: arc
  Password: XyZ9...
  Database: arc_db

Grafana:
  URL: http://localhost:3000
  User: admin
  Password: AbC1...
```

---

### `validate-secrets.sh`

Validates that all required secrets are properly configured in `.env` file.

**Usage:**
```bash
./scripts/setup/validate-secrets.sh
```

**Features:**
- Checks all required environment variables are set
- Validates secrets don't contain placeholder values
- Warns about weak or short secrets
- Provides clear error messages and remediation steps

**Validation Checks:**
1. ✅ Variable is set (not empty)
2. ✅ Variable doesn't contain "CHANGE_ME" or other placeholders
3. ⚠️ Variable meets minimum length requirements
4. ⚠️ Variable doesn't contain weak patterns (e.g., "password", "admin")

**Example Output:**
```
=================================================================
A.R.C. Framework - Secrets Validation
=================================================================

Validating required secrets...

PostgreSQL Database:
✓ POSTGRES_PASSWORD is set

Infisical Secrets Management:
✓ INFISICAL_ENCRYPTION_KEY is set
✓ INFISICAL_AUTH_SECRET is set

Grafana Observability:
✗ GRAFANA_ADMIN_PASSWORD contains placeholder value

=================================================================
Validation Summary
=================================================================

✗ 1 error(s) found - please fix before deployment

To generate secure secrets, use these commands:

  # For passwords (32 chars):
  openssl rand -base64 32

  # For tokens (64 hex chars):
  openssl rand -hex 32
```

---

## Integration with Makefile

These scripts are integrated into the Makefile for easy use:

```bash
# Initialize environment (interactive)
make init-env

# Generate secure secrets
make generate-secrets

# Validate secrets before deployment
make validate-secrets

# Complete initialization (includes secret validation)
make init
```

---

## Security Best Practices

### ✅ DO:
- Use `generate-secrets.sh` for production deployments
- Run `validate-secrets.sh` before every deployment
- Keep `.env` file secure (never commit to version control)
- Use different secrets for each environment (dev, staging, prod)
- Rotate secrets periodically
- Store production secrets in a secure vault (e.g., Infisical)

### ❌ DON'T:
- Don't use `.env.example` values in production
- Don't commit `.env` file to version control
- Don't share secrets via unencrypted channels
- Don't reuse passwords across services
- Don't use weak or short passwords

---

## Secret Generation Commands

If you need to generate individual secrets manually:

```bash
# Base64-encoded secret (recommended for most secrets)
openssl rand -base64 32

# Hex-encoded secret (for tokens)
openssl rand -hex 32

# Alphanumeric password (if special chars cause issues)
openssl rand -base64 32 | tr -d '=+/'

# UUID (for unique identifiers)
uuidgen
```

---

## Troubleshooting

### "Command not found: openssl"

Install OpenSSL:
- **macOS**: `brew install openssl`
- **Ubuntu/Debian**: `apt-get install openssl`
- **Alpine**: `apk add openssl`

### "Permission denied"

Make scripts executable:
```bash
chmod +x scripts/setup/*.sh
```

### "POSTGRES_PASSWORD must be set"

This error occurs when `.env` file doesn't exist or contains placeholder values:

1. Run `make generate-secrets` to create `.env` with secure values
2. Or manually update `.env` with strong passwords

### Validation fails with "placeholder value"

Replace all `CHANGE_ME` values in `.env` with actual secrets:
```bash
make generate-secrets
```

---

## Related Documentation

- [Environment Configuration](../../.env.example) - Configuration template
- [Operations Guide](../../docs/OPERATIONS.md) - Deployment procedures
- [Security Concerns](../../reports/2025/11/0911-CONCERNS_AND_ACTION_PLAN.md) - Security analysis

---

**Last Updated:** November 9, 2025

