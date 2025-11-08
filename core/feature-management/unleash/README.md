# Unleash - Feature Flags

Feature flag management for gradual rollouts and A/B testing.

---

## Overview

**Unleash** provides:
- Feature flags and toggles
- Gradual rollouts
- A/B testing
- User targeting
- Kill switches
- Environment-based flags

---

## Ports

- **4242** - Web UI and API

---

## Configuration

See `.env.example` for configuration options.

### Key Features
- **Gradual Rollout** - Roll out features to percentage of users
- **User Targeting** - Target specific users or groups
- **Strategy-based** - Multiple activation strategies
- **Environment Support** - Separate flags per environment
- **SDKs** - Client libraries for many languages
- **Audit Trail** - Track flag changes

---

## Environment Variables

See `.env.example` for configuration options.

**Key Variables:**
```bash
UNLEASH_URL=http://unleash:4242
UNLEASH_API_TOKEN=<your-api-token>
DATABASE_URL=postgres://...  # For persistence
```

---

## Usage

### Start Service
```bash
make up-stack
# or
docker compose -f docker-compose.yml -f docker-compose.stack.yml up unleash
```

### Access Web UI
```bash
open http://localhost:4242
```

### First-Time Setup
1. Access http://localhost:4242
2. Login with default credentials (check Unleash docs)
3. Create API tokens
4. Create feature flags
5. Configure strategies

---

## Feature Flag Patterns

### 1. Kill Switch
```
Enable/disable feature instantly without deployment
Use case: Emergency rollback
```

### 2. Gradual Rollout
```
Release to 10% → 25% → 50% → 100% of users
Use case: Safe feature deployment
```

### 3. User Targeting
```
Enable for specific users or user properties
Use case: Beta testing, VIP features
```

### 4. A/B Testing
```
Split users into variants A and B
Use case: Experiment with different approaches
```

### 5. Environment Flags
```
Different flag states per environment
Use case: Test in staging before production
```

---

## Client Libraries

### Go
```go
import "github.com/Unleash/unleash-client-go/v4"

unleash.Initialize(
    unleash.WithUrl("http://localhost:4242/api"),
    unleash.WithAppName("my-service"),
    unleash.WithInstanceId("instance-1"),
)

if unleash.IsEnabled("new-feature") {
    // New feature code
} else {
    // Old code
}

// With context
ctx := context.Context{
    UserId: "user-123",
    Properties: map[string]string{
        "plan": "premium",
    },
}
if unleash.IsEnabled("premium-feature", unleash.WithContext(ctx)) {
    // Premium feature
}
```

### Python
```python
from UnleashClient import UnleashClient

client = UnleashClient(
    url="http://localhost:4242/api",
    app_name="my-service",
    instance_id="instance-1"
)

client.initialize_client()

if client.is_enabled("new-feature"):
    # New feature code
else:
    # Old code

# With context
context = {
    "userId": "user-123",
    "properties": {"plan": "premium"}
}
if client.is_enabled("premium-feature", context):
    # Premium feature
```

### JavaScript/Node
```javascript
const { initialize } = require('unleash-client');

const unleash = initialize({
  url: 'http://localhost:4242/api',
  appName: 'my-service',
  instanceId: 'instance-1'
});

unleash.on('ready', () => {
  if (unleash.isEnabled('new-feature')) {
    // New feature code
  }
});

// With context
const context = {
  userId: 'user-123',
  properties: { plan: 'premium' }
};
if (unleash.isEnabled('premium-feature', context)) {
  // Premium feature
}
```

---

## Activation Strategies

### Standard Strategy
On/off for all users in environment

### Flexible Rollout
Percentage-based gradual rollout
```
0% → 10% → 25% → 50% → 100%
```

### User IDs
Target specific user IDs
```
userIds: user-1, user-2, user-3
```

### Remote Address (IP)
Target specific IP addresses or ranges

### Custom Strategy
Define your own strategy logic

---

## Best Practices

### 1. Naming Convention
```
Format: domain-feature-action

Examples:
✅ agent-reasoning-enable-gpt4
✅ payment-checkout-show-paypal
✅ ui-dashboard-display-analytics
```

### 2. Strategy Selection
- **Kill Switch** - Use standard strategy
- **Gradual Rollout** - Use flexible rollout
- **Beta Testing** - Use user IDs or properties
- **Regional** - Use remote address or custom strategy

### 3. Flag Lifecycle
```
1. Create flag (off in all environments)
2. Enable in development
3. Test thoroughly
4. Enable in staging
5. Gradual rollout in production (10% → 100%)
6. Remove flag after stabilization
```

### 4. Clean Up Old Flags
Remove flags after:
- Feature is 100% rolled out
- Flag has been stable for 1-2 weeks
- Update code to remove flag checks

---

## Monitoring

### Key Metrics
- Flag evaluation count
- Variant distribution
- Toggle state changes
- API response times

### Metrics API
```bash
# Get all toggles
curl http://localhost:4242/api/admin/features

# Get specific toggle
curl http://localhost:4242/api/admin/features/my-feature

# Get metrics
curl http://localhost:4242/api/admin/metrics/features/my-feature
```

---

## Production Notes

1. **Persistence** - Use external Postgres for flag storage
2. **High Availability** - Deploy multiple Unleash instances
3. **Client Caching** - SDKs cache flags locally
4. **API Tokens** - Use separate tokens per environment
5. **Audit Trail** - Monitor who changes flags
6. **Documentation** - Document each flag's purpose
7. **Cleanup** - Remove obsolete flags regularly

---

## Integration with Observability

### Send Flag Evaluations to Telemetry
```go
// Add custom attribute to spans
if unleash.IsEnabled("new-feature") {
    span.SetAttribute("feature.new-feature", true)
}

// Log flag evaluation
logger.Info("feature evaluated",
    "feature", "new-feature",
    "enabled", unleash.IsEnabled("new-feature"),
    "user", userId)
```

---

## Troubleshooting

### Flag Not Updating
1. Check client cache refresh interval (default: 15s)
2. Verify API token has correct permissions
3. Check network connectivity to Unleash server
4. Review Unleash logs for errors

### Inconsistent Flag States
1. Verify environment configuration
2. Check strategy configuration
3. Review context being sent (userId, properties)
4. Test with Unleash playground

---

## Alternatives

If Unleash doesn't fit your needs:
- **LaunchDarkly** - SaaS, enterprise features
- **Split** - SaaS, A/B testing focused
- **Flagsmith** - Open-source, similar to Unleash
- **GrowthBook** - Open-source, experiment-focused
- **Flipt** - Lightweight, self-hosted

---

## See Also

- [Core Services](../../README.md)
- [Operations Guide](../../../docs/OPERATIONS.md)
- [Unleash Documentation](https://docs.getunleash.io/)
# Infisical - Secrets Management

Self-hosted secrets vault for secure credential management.

---

## Overview

**Infisical** provides:
- Centralized secrets storage
- Environment-based secrets
- Access control and audit logs
- API key management
- Secret versioning
- Team collaboration

---

## Ports

- **3001** - Web UI and API

---

## Configuration

See `.env.example` for configuration options.

### Key Features
- **Self-Hosted** - Full control over secrets
- **Version Control** - Track secret changes
- **Access Control** - Role-based permissions
- **Audit Logs** - Who accessed what and when
- **Integrations** - CLI, SDKs, Kubernetes operator

---

## Environment Variables

See `.env.example` for configuration options.

**Key Variables:**
```bash
INFISICAL_URL=http://infisical:3001
INFISICAL_TOKEN=<your-token>
ENCRYPTION_KEY=<strong-encryption-key>  # GENERATE THIS!
```

⚠️ **Critical:** Generate a strong encryption key for production!

---

## Usage

### Start Service
```bash
make up-stack
# or
docker compose -f docker-compose.yml -f docker-compose.stack.yml up infisical
```

### Access Web UI
```bash
open http://localhost:3001
```

### First-Time Setup
1. Access http://localhost:3001
2. Create admin account
3. Create organization
4. Create projects (e.g., "development", "staging", "production")
5. Add secrets to each environment

---

## Workflow

### 1. Store Secrets
```bash
# Via Web UI
1. Navigate to project
2. Select environment (dev/staging/prod)
3. Add secret: KEY=VALUE

# Via CLI
infisical secrets set DATABASE_URL "postgres://..."
```

### 2. Access Secrets in Services
```bash
# Option 1: Infisical CLI
infisical run -- ./your-app

# Option 2: SDK
# See client library examples below
```

---

## Client Libraries

### Go
```go
import "github.com/infisical/go-sdk"

client := infisical.NewClient(infisical.Config{
    SiteURL: "http://localhost:3001",
})

client.Auth().UniversalAuthLogin("client-id", "client-secret")

secret, _ := client.Secrets().Get(infisical.GetSecretOptions{
    ProjectID:   "project-id",
    Environment: "production",
    SecretName:  "DATABASE_URL",
})

fmt.Println(secret.Value)
```

### Python
```python
from infisical_client import InfisicalClient

client = InfisicalClient(site_url="http://localhost:3001")
client.auth.universal_auth_login("client-id", "client-secret")

secret = client.get_secret(
    project_id="project-id",
    environment="production",
    secret_name="DATABASE_URL"
)

print(secret.value)
```

### CLI
```bash
# Install
brew install infisical/get-cli/infisical

# Login
infisical login

# Run command with injected secrets
infisical run -- npm start

# Export secrets to .env file
infisical secrets export > .env
```

---

## Security Best Practices

1. **Strong Encryption Key** - Generate with `openssl rand -hex 32`
2. **Access Control** - Use least-privilege principle
3. **Rotate Secrets** - Regular rotation schedule
4. **Audit Logs** - Monitor access patterns
5. **Backup** - Regular encrypted backups
6. **Network Security** - Use HTTPS in production
7. **Service Tokens** - Use service tokens, not user tokens

---

## Project Structure

```
Organization
└── Project (e.g., "arc-platform")
    ├── development
    │   ├── DATABASE_URL=postgres://dev...
    │   └── API_KEY=dev-key
    ├── staging
    │   ├── DATABASE_URL=postgres://staging...
    │   └── API_KEY=staging-key
    └── production
        ├── DATABASE_URL=postgres://prod...
        └── API_KEY=prod-key
```

---

## Integration with Docker Compose

### Option 1: Service Tokens
```yaml
services:
  myapp:
    environment:
      - INFISICAL_TOKEN=${INFISICAL_TOKEN}
    command: >
      sh -c "infisical run --token=${INFISICAL_TOKEN} -- ./app"
```

### Option 2: Init Container Pattern
```yaml
services:
  myapp:
    depends_on:
      - secrets-init
    volumes:
      - secrets:/secrets
    env_file:
      - /secrets/.env

  secrets-init:
    image: infisical/cli
    command: secrets export --format=dotenv > /secrets/.env
    volumes:
      - secrets:/secrets
```

---

## Backup & Recovery

### Backup
```bash
# Backup Infisical data
docker compose exec infisical pg_dump > infisical-backup.sql

# Backup encryption key
echo $ENCRYPTION_KEY > encryption-key.txt.gpg
```

### Restore
```bash
# Restore database
docker compose exec -T infisical psql < infisical-backup.sql

# Restore encryption key
export ENCRYPTION_KEY=$(cat encryption-key.txt.gpg)
```

---

## Monitoring

### Key Metrics
- Secret access count
- Failed authentication attempts
- API response times
- Audit log volume

### Health Check
```bash
curl http://localhost:3001/api/status
```

---

## Production Notes

1. **HTTPS Only** - Configure SSL certificates
2. **Strong Encryption** - Use 32+ byte encryption key
3. **Backup Strategy** - Encrypted backups to S3/GCS
4. **High Availability** - Deploy multiple instances
5. **Database** - Use external Postgres for persistence
6. **Monitoring** - Alert on failed auth attempts
7. **Disaster Recovery** - Document recovery procedures

---

## Alternatives

If Infisical doesn't fit your needs:
- **HashiCorp Vault** - Enterprise-grade, complex
- **AWS Secrets Manager** - Cloud-native, AWS only
- **Azure Key Vault** - Cloud-native, Azure only
- **GCP Secret Manager** - Cloud-native, GCP only
- **Doppler** - SaaS, simple

---

## See Also

- [Core Services](../../README.md)
- [Operations Guide](../../../docs/OPERATIONS.md)
- [Infisical Documentation](https://infisical.com/docs)

