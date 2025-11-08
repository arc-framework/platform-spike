# Secrets Management

Secrets and configuration management services for the A.R.C. Framework.

---

## Overview

The secrets layer provides secure storage and management of sensitive configuration data including:

- API keys and tokens
- Database credentials
- Service certificates
- Environment-specific configurations
- Feature flags with sensitive data

---

## Implementation

### [Infisical](./infisical/)
**Status:** ✅ Active  
**Type:** Self-hosted secrets management platform

- End-to-end encrypted secret storage
- Version history and rollback
- Role-based access control (RBAC)
- Multiple environment support
- SDK and CLI for secret injection
- Audit logging

---

## Alternatives

The secrets management system is **swappable**. Alternative implementations:

- **HashiCorp Vault** - Enterprise-grade secrets management
- **AWS Secrets Manager** - Cloud-native AWS solution
- **Azure Key Vault** - Cloud-native Azure solution
- **GCP Secret Manager** - Cloud-native GCP solution
- **Doppler** - Developer-first secrets management
- **Chamber** - AWS Parameter Store wrapper

---

## Best Practices

### Secret Storage
- **Never commit secrets** to version control
- **Use environment-specific** secrets for dev/staging/prod
- **Rotate secrets regularly** and maintain version history
- **Audit access** to sensitive secrets

### Secret Access
- **Use service accounts** for automated access
- **Implement least privilege** access controls
- **Inject secrets** at runtime, not build time
- **Use short-lived tokens** when possible

### Development
- **Use `.env.example`** files as templates (no real secrets)
- **Document required secrets** in README files
- **Provide secure defaults** for local development
- **Use separate secrets** for development vs production

---

## Integration

### Environment Variables
Services can retrieve secrets as environment variables:

```bash
# Traditional approach
export DATABASE_PASSWORD="secret_from_vault"

# Using Infisical CLI
infisical run -- your-application
```

### SDK Integration
Applications can fetch secrets programmatically:

```go
// Go example
import "github.com/infisical/go-sdk"

client := infisical.NewClient(...)
secret, err := client.GetSecret("DATABASE_PASSWORD", "production")
```

---

## See Also

- [Core Services](../README.md)
- [Infisical Implementation](./infisical/README.md)
- [Operations Guide](../../docs/OPERATIONS.md)
- [Security Best Practices](../../plugins/security/README.md)

