# Docker Image Tagging Strategy

**Task:** T038
**Last Updated:** January 2026

This guide describes the Docker image tagging conventions used throughout the A.R.C. platform.

---

## Overview

A.R.C. uses a structured tagging strategy that balances:

- **Reproducibility**: Every build can be traced to a specific commit
- **Stability**: Production environments use stable tags
- **Development**: Development workflows use flexible tags

---

## Tag Format

### Standard Tag Pattern

```
ghcr.io/arc-framework/{image}:{version}[-{variant}]
```

**Components:**

| Part | Description | Example |
|------|-------------|---------|
| `ghcr.io/arc-framework` | GitHub Container Registry organization | - |
| `{image}` | Image name following naming convention | `arc-sherlock-brain` |
| `{version}` | Semantic version or special tag | `1.2.3`, `latest` |
| `{variant}` | Optional variant suffix | `-alpine`, `-debug` |

---

## Tag Categories

### 1. Semantic Version Tags

For production releases:

```
arc-sherlock-brain:1.0.0      # Exact version
arc-sherlock-brain:1.0        # Latest patch in 1.0.x
arc-sherlock-brain:1          # Latest minor in 1.x.x
```

**When to use:** Production deployments, stable references

### 2. Git Reference Tags

For traceability:

```
arc-sherlock-brain:sha-abc1234     # Git commit SHA (first 7 chars)
arc-sherlock-brain:main            # Branch name
arc-sherlock-brain:pr-123          # Pull request number
```

**When to use:** CI/CD pipelines, debugging specific builds

### 3. Special Tags

```
arc-sherlock-brain:latest          # Most recent build (main branch)
arc-sherlock-brain:edge            # Development builds
arc-sherlock-brain:local           # Local development builds
```

**When to use:**
- `latest`: Default for docker pull (use sparingly in prod)
- `edge`: Integration testing
- `local`: Local development only (never pushed)

### 4. Base Image Tags

Base images include language/Alpine version:

```
ghcr.io/arc-framework/base-python-ai:3.11-alpine3.19
ghcr.io/arc-framework/base-go-infra:1.21-alpine3.19
```

**Format:** `{language_version}-alpine{alpine_version}`

---

## Tagging by Environment

### Development

```yaml
# Local builds
services:
  sherlock:
    image: arc-sherlock-brain:local
```

- Use `:local` tag for local builds
- Never push `:local` tags to registry

### Staging

```yaml
# Staging/QA environment
services:
  sherlock:
    image: ghcr.io/arc-framework/arc-sherlock-brain:edge
```

- Use `:edge` or PR-specific tags
- Auto-updated by CI/CD

### Production

```yaml
# Production environment
services:
  sherlock:
    image: ghcr.io/arc-framework/arc-sherlock-brain:1.2.3
```

- Always use exact semantic version
- Never use `:latest` in production
- Pin to immutable SHA tag for critical deployments

---

## Tagging Workflow

### Feature Branch

```bash
# Build creates tag with branch name and SHA
arc-sherlock-brain:feature-add-logging
arc-sherlock-brain:sha-abc1234
```

### Pull Request

```bash
# CI creates PR-specific tag
arc-sherlock-brain:pr-123
arc-sherlock-brain:sha-def5678
```

### Merge to Main

```bash
# Updates latest and edge
arc-sherlock-brain:latest
arc-sherlock-brain:edge
arc-sherlock-brain:sha-ghi9012
```

### Release

```bash
# Creates semantic version tags
arc-sherlock-brain:1.2.3
arc-sherlock-brain:1.2
arc-sherlock-brain:1
arc-sherlock-brain:sha-jkl3456
```

---

## Tag Immutability

### Mutable Tags (Can Change)

- `:latest` - Points to newest build
- `:edge` - Points to development builds
- `:{branch}` - Points to latest commit on branch
- `:{major}` - Points to latest minor.patch
- `:{major}.{minor}` - Points to latest patch

### Immutable Tags (Never Change)

- `:{major}.{minor}.{patch}` - Exact version
- `:sha-{commit}` - Git commit reference
- `:pr-{number}-{sha}` - PR with commit SHA

**Best Practice:** For production, combine mutable and immutable:

```yaml
# Explicit version + SHA for audit trail
image: ghcr.io/arc-framework/arc-sherlock-brain:1.2.3@sha256:abc123...
```

---

## Build Commands

### Local Development

```bash
# Build with local tag
docker build -t arc-sherlock-brain:local services/arc-sherlock-brain/

# Build with specific version
docker build -t arc-sherlock-brain:1.2.3 services/arc-sherlock-brain/
```

### CI/CD Pipeline

```bash
# Set variables
VERSION="1.2.3"
SHA=$(git rev-parse --short HEAD)
REGISTRY="ghcr.io/arc-framework"

# Build with multiple tags
docker build \
  -t ${REGISTRY}/arc-sherlock-brain:${VERSION} \
  -t ${REGISTRY}/arc-sherlock-brain:${VERSION%.*} \
  -t ${REGISTRY}/arc-sherlock-brain:sha-${SHA} \
  -t ${REGISTRY}/arc-sherlock-brain:latest \
  services/arc-sherlock-brain/
```

### Using Makefile

```bash
# Build base images with local tag
make build-base-images

# Custom service build
docker build -t arc-sherlock-brain:$(git rev-parse --short HEAD) \
  services/arc-sherlock-brain/
```

---

## Retention Policy

### GitHub Container Registry

| Tag Pattern | Retention | Notes |
|-------------|-----------|-------|
| `:{semver}` | Forever | Release versions |
| `:sha-*` | 90 days | Commit references |
| `:pr-*` | 30 days | PR builds |
| `:edge` | Current only | Replaced each build |
| `:latest` | Current only | Replaced each build |

### Cleanup Script

```bash
# Remove old PR images (run in CI)
gh api --paginate repos/arc-framework/arc-platform/packages | \
  jq -r '.[] | select(.package_type=="container") | .name' | \
  while read pkg; do
    # Delete PR tags older than 30 days
    ...
  done
```

---

## Verification

### Check Image Tags

```bash
# List all tags for an image
docker images arc-sherlock-brain --format "{{.Tag}}"

# Check remote tags
gh api repos/arc-framework/arc-platform/packages/container/arc-sherlock-brain/versions | \
  jq -r '.[].metadata.container.tags[]'
```

### Verify Tag Contents

```bash
# Inspect image metadata
docker inspect arc-sherlock-brain:1.2.3 | jq '.[0].Config.Labels'

# Compare two tags
docker inspect arc-sherlock-brain:latest --format '{{.Id}}'
docker inspect arc-sherlock-brain:1.2.3 --format '{{.Id}}'
```

---

## Related Documentation

- [Docker Image Hierarchy](../architecture/DOCKER-IMAGE-HIERARCHY.md) - Image dependency structure
- [GHCR Publishing](./GHCR-PUBLISHING.md) - Registry publishing guide
- [Docker Standards](./DOCKER-STANDARDS.md) - Dockerfile requirements
