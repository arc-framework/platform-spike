# Feature Management

Feature flags and A/B testing for the A.R.C. Framework.

---

## Overview

The feature management layer provides:
- Feature flags and toggles
- Gradual rollouts
- A/B testing and experiments
- User targeting
- Kill switches for emergency rollback

---

## Implementation

### [Unleash](./unleash/)
**Status:** ⚠️ Optional  
**Type:** Open-source feature flag platform

- Strategy-based activation
- Environment separation
- User and property targeting
- Gradual rollout support
- SDK for many languages

**Note:** Unleash is optional. You can use environment variables for simple feature flags.

---

## Alternatives

Feature management is **optional and swappable**:
- **LaunchDarkly** - SaaS, enterprise features
- **Split** - SaaS, A/B testing focused
- **Flagsmith** - Open-source, similar to Unleash
- **GrowthBook** - Open-source, experiment-focused
- **Environment Variables** - Simple, no UI

---

## See Also

- [Core Services](../README.md)
- [Operations Guide](../../docs/OPERATIONS.md)
# Secrets Management

Secure secrets storage and management for the A.R.C. Framework.

---

## Overview

The secrets layer provides secure storage and access control for sensitive credentials:
- API keys (LLM providers, external services)
- Database passwords
- Service tokens
- Encryption keys
- Certificates

---

## Implementation

### [Infisical](./infisical/)
**Status:** ✅ Active  
**Type:** Self-hosted secrets vault

- Centralized secrets storage
- Environment-based organization
- Access control and audit logs
- CLI and SDK integrations
- Version control for secrets

---

## Alternatives

The secrets manager is **swappable**. Alternative implementations:
- **HashiCorp Vault** - Enterprise-grade, complex setup
- **AWS Secrets Manager** - Cloud-native (AWS only)
- **Azure Key Vault** - Cloud-native (Azure only)
- **GCP Secret Manager** - Cloud-native (GCP only)
- **Doppler** - SaaS, simple

---

## See Also

- [Core Services](../README.md)
- [Operations Guide](../../docs/OPERATIONS.md)
- [Security Best Practices](../../docs/guides/)

