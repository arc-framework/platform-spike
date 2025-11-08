# Ory Kratos Configuration

This directory contains the configuration files for [Ory Kratos](https://www.ory.sh/kratos/docs/), an open-source identity and user management system.

## Files

- `kratos.yml` - Main Kratos configuration file
- `identity.schema.json` - Identity schema defining user traits (email, name)

## Configuration Overview

The current setup includes:
- Email/password authentication
- Self-service flows (login, registration, recovery, verification)
- PostgreSQL database integration (configured via DSN environment variable)
- Debug logging enabled

## Important Security Notes

⚠️ **WARNING**: This configuration is for DEVELOPMENT ONLY!

The following settings MUST be changed for production:

1. **Secrets** in `kratos.yml`:
   ```yaml
   secrets:
     cookie:
       - PLEASE-CHANGE-ME-I-AM-VERY-INSECURE  # Change this!
     cipher:
       - 32-LONG-SECRET-NOT-SECURE-AT-ALL     # Change this!
   ```

2. **Database**: Currently uses PostgreSQL via environment variable DSN

3. **SMTP/Email**: Configure a real SMTP server for production

## Database Migrations

Before running Kratos, you need to run database migrations:

```bash
# Using docker-compose
docker-compose -f docker-compose.yml -f docker-compose.stack.yml run --rm kratos migrate sql -e --yes

# Or using Make
make migrate-kratos
```

## Testing Kratos

After starting the services:

- Public API: http://localhost:4433
- Admin API: http://localhost:4434
- Health check: http://localhost:4434/health/alive

## References

- [Kratos Documentation](https://www.ory.sh/kratos/docs/)
- [Kratos Configuration Reference](https://www.ory.sh/kratos/docs/reference/configuration)
- [Identity Schema Guide](https://www.ory.sh/kratos/docs/concepts/identity-schema)

