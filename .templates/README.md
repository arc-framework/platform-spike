# A.R.C. Dockerfile Templates

Templates for creating new A.R.C. services with consistent patterns.

## Overview

These templates enforce:
- **Multi-stage builds**: Separate build from runtime
- **Security hardening**: Non-root users, minimal attack surface
- **Build optimization**: Proper layer ordering for cache efficiency
- **OCI compliance**: Standard labels and metadata

## Available Templates

| Template | Language | Use Case |
|----------|----------|----------|
| `Dockerfile.python.template` | Python 3.11 | AI agents, reasoning engines |
| `Dockerfile.go.template` | Go 1.21 | Infrastructure tools, CLI |

## Using Templates

### Quick Start

```bash
# Create a new Python service
./scripts/create-service.sh --name arc-analytics --tier services --lang python
```

### Manual Usage

1. Copy the appropriate template:
   ```bash
   cp .templates/Dockerfile.python.template services/arc-my-service/Dockerfile
   ```

2. Replace placeholders:
   - `{SERVICE_NAME}` - Service name (e.g., `my-service`)
   - `{CODENAME}` - Marvel/Hollywood codename (e.g., `stark`)

3. Customize for your service:
   - Add service-specific dependencies
   - Update health check endpoint
   - Add environment variables

## Template Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{SERVICE_NAME}` | Service name without `arc-` prefix | `sherlock-brain` |
| `{CODENAME}` | Short codename for the service | `sherlock` |

## Template Requirements

All templates must include:

1. **Multi-stage build** - Separate builder and runtime stages
2. **Non-root user** - `USER arcuser` with UID 1000
3. **Health check** - `HEALTHCHECK` instruction
4. **OCI labels** - Standard metadata labels
5. **No `:latest` tags** - Pinned base image versions
6. **Cache-optimized layers** - Dependencies before source code

## Validation

Templates are validated in CI/CD:
- Linted with hadolint
- Tested with sample builds
- Checked for security compliance

## Related Documentation

- [Dockerfile Standards](../docs/guides/dockerfile-standards.md)
- [Base Images](./.docker/README.md)
- [Service Registry](../SERVICE.MD)
