# Infisical

**Status:** ✅ Active  
**Type:** Self-hosted Secrets Management Platform

---

## Overview

Infisical provides secure, centralized secrets management for the A.R.C. Framework, offering:

- **End-to-End Encryption** - Secrets encrypted at rest and in transit
- **Version Control** - Track changes and rollback when needed
- **Multi-Environment** - Separate secrets for dev, staging, production
- **Access Control** - Role-based permissions and audit logs
- **Developer Tools** - CLI, SDKs, and API for secret injection
- **Self-Hosted** - Full control over your secrets infrastructure

---

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Infisical configuration
INFISICAL_PORT=3001
ENCRYPTION_KEY=your-32-char-encryption-key
JWT_SECRET=your-jwt-secret
MONGO_URL=mongodb://mongo:27017/infisical
```

### Initial Setup

1. Start Infisical:
   ```bash
   make up-stack
   ```

2. Access the web UI at http://localhost:3001

3. Create an admin account

4. Create a workspace for your project

5. Add environments (development, staging, production)

---

## Usage

### Web Interface

Access the Infisical dashboard at:
- **URL**: http://localhost:3001
- **Features**: Manage secrets, teams, access controls

### CLI

Install the Infisical CLI:
```bash
# macOS
brew install infisical

# Linux
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
sudo apt-get update && sudo apt-get install -y infisical
```

Login and run commands:
```bash
# Login
infisical login

# Run application with injected secrets
infisical run -- npm start

# Export secrets to .env file
infisical export > .env
```

### SDK Integration

**Go Example:**
```go
import "github.com/infisical/go-sdk"

client := infisical.NewInfisicalClient(infisical.Config{
    SiteURL: "http://localhost:3001",
})

err := client.Auth().UniversalAuthLogin("client-id", "client-secret")
secret, err := client.Secrets().Get(infisical.GetSecretOptions{
    Environment: "production",
    ProjectID:   "project-id",
    SecretName:  "DATABASE_PASSWORD",
})
```

**Node.js Example:**
```javascript
const InfisicalClient = require("infisical-node");

const client = new InfisicalClient({
    siteURL: "http://localhost:3001",
});

await client.auth().universalAuth.login({
    clientId: "client-id",
    clientSecret: "client-secret",
});

const secret = await client.secrets().get({
    environment: "production",
    projectId: "project-id",
    secretName: "DATABASE_PASSWORD",
});
```

---

## Ports

| Port | Purpose |
|------|---------|
| `3001` | Infisical web UI and API |

---

## Secret Organization

### Recommended Structure

```
Workspace: arc-platform
├── Project: core-services
│   ├── Environment: development
│   │   ├── DATABASE_PASSWORD
│   │   ├── REDIS_PASSWORD
│   │   └── API_KEY
│   ├── Environment: staging
│   └── Environment: production
├── Project: agents
│   ├── Environment: development
│   └── Environment: production
└── Project: utilities
```

### Naming Conventions

- Use `UPPER_SNAKE_CASE` for secret names
- Group related secrets with prefixes (e.g., `DB_*`, `API_*`)
- Include environment context in descriptions
- Tag secrets for easier filtering

---

## Security Best Practices

### Access Control
- Create service accounts for automated access
- Use machine identities for CI/CD
- Implement least privilege access
- Regularly audit access logs

### Secret Rotation
- Rotate secrets on a regular schedule
- Update dependent services when rotating
- Use version history to track changes
- Test rotation process in development first

### Backup and Recovery
- Enable backups of the underlying MongoDB
- Export critical secrets to secure offline storage
- Document recovery procedures
- Test restore process periodically

---

## Health Check

Check Infisical availability:

```bash
curl http://localhost:3001/api/status
```

---

## Troubleshooting

### View Logs
```bash
docker-compose -f docker-compose.stack.yml logs infisical
```

### Common Issues

1. **Cannot connect**: Check if the service is running and port 3001 is available
2. **Authentication errors**: Verify JWT_SECRET is set correctly
3. **Secrets not loading**: Check workspace and project IDs
4. **Performance issues**: Ensure MongoDB has sufficient resources

### Reset Installation

To completely reset Infisical:
```bash
# Stop and remove volumes
docker-compose -f docker-compose.stack.yml down -v

# Remove any persisted data
docker volume rm infisical-data mongo-data

# Restart
docker-compose -f docker-compose.stack.yml up infisical -d
```

---

## Integration Examples

### Docker Compose

Inject secrets into container:
```yaml
services:
  myapp:
    image: myapp:latest
    environment:
      - INFISICAL_TOKEN=${INFISICAL_TOKEN}
    command: infisical run -- npm start
```

### Kubernetes

Use Infisical Kubernetes operator:
```yaml
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: infisical-secret
spec:
  hostAPI: http://infisical:3001/api
  projectId: PROJECT_ID
  environment: production
  secretsPath: /
```

---

## See Also

- [Secrets Management Overview](../README.md)
- [Infisical Documentation](https://infisical.com/docs)
- [Infisical GitHub](https://github.com/Infisical/infisical)
- [Security Best Practices](../../../plugins/security/README.md)
- [Operations Guide](../../../docs/OPERATIONS.md)

