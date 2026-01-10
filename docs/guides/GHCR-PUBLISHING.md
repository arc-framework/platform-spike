# GitHub Container Registry (GHCR) Publishing Guide

**Task:** T039
**Last Updated:** January 2026

This guide covers publishing Docker images to GitHub Container Registry for the A.R.C. platform.

---

## Overview

A.R.C. uses GitHub Container Registry (GHCR) for:

- **Base images**: Shared foundation images (`base-python-ai`, `base-go-infra`)
- **Service images**: Production-ready service images
- **CI/CD integration**: Automated builds and deployments

---

## Prerequisites

### 1. GitHub Personal Access Token (PAT)

Create a PAT with the following permissions:

- `read:packages` - Pull images
- `write:packages` - Push images
- `delete:packages` - Remove old images (optional)

```bash
# Store token securely
export GHCR_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
```

### 2. Docker Login

```bash
# Login to GHCR
echo $GHCR_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Verify login
docker pull ghcr.io/arc-framework/base-python-ai:3.11-alpine3.19
```

### 3. Repository Secrets (CI/CD)

Add these secrets to the GitHub repository:

| Secret Name | Description |
|-------------|-------------|
| `GHCR_TOKEN` | Personal Access Token for GHCR |
| `GHCR_USERNAME` | GitHub username |

---

## Image Naming Convention

### Registry Path

```
ghcr.io/arc-framework/{image-name}:{tag}
```

### Image Names

| Type | Pattern | Example |
|------|---------|---------|
| Base images | `base-{language}-{purpose}` | `base-python-ai` |
| Services | `arc-{service-name}` | `arc-sherlock-brain` |
| Utilities | `{utility-name}` | `raymond` |

---

## Publishing Workflow

### Manual Publishing

#### 1. Build the Image

```bash
# Build with proper tags
docker build \
  -t ghcr.io/arc-framework/arc-sherlock-brain:1.0.0 \
  -t ghcr.io/arc-framework/arc-sherlock-brain:latest \
  services/arc-sherlock-brain/
```

#### 2. Push to Registry

```bash
# Push all tags
docker push ghcr.io/arc-framework/arc-sherlock-brain:1.0.0
docker push ghcr.io/arc-framework/arc-sherlock-brain:latest

# Or push all tags at once
docker push --all-tags ghcr.io/arc-framework/arc-sherlock-brain
```

#### 3. Verify Publication

```bash
# Check image in registry
gh api repos/arc-framework/arc-platform/packages/container/arc-sherlock-brain/versions | \
  jq '.[0].metadata.container.tags'
```

### Automated Publishing (CI/CD)

See `.github/workflows/publish-images.yml`:

```yaml
name: Publish Images

on:
  push:
    tags:
      - 'v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository_owner }}/arc-sherlock-brain
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=sha-

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: services/arc-sherlock-brain
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

---

## Publishing Base Images

Base images require special handling since services depend on them.

### Build Order

1. Build and push base images first
2. Wait for base images to be available
3. Build and push dependent services

### Base Image Workflow

```bash
# 1. Build base image
docker build \
  -t ghcr.io/arc-framework/base-python-ai:3.11-alpine3.19 \
  .docker/base/python-ai/

# 2. Push base image
docker push ghcr.io/arc-framework/base-python-ai:3.11-alpine3.19

# 3. Build services (after push completes)
docker build \
  -t ghcr.io/arc-framework/arc-sherlock-brain:1.0.0 \
  services/arc-sherlock-brain/
```

### Makefile Integration

```bash
# Build all base images
make build-base-images

# Push base images (requires login)
make push-base-images
```

---

## Multi-Architecture Builds

For cross-platform support (amd64/arm64):

### Using Docker Buildx

```bash
# Create builder
docker buildx create --name arc-builder --use

# Build multi-arch image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/arc-framework/arc-sherlock-brain:1.0.0 \
  --push \
  services/arc-sherlock-brain/
```

### CI/CD Multi-Arch

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push (multi-arch)
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    push: true
    tags: ghcr.io/arc-framework/arc-sherlock-brain:1.0.0
```

---

## Image Visibility

### Public Images

Make images public for open-source distribution:

```bash
# Via GitHub UI:
# 1. Go to Packages
# 2. Select image
# 3. Package Settings -> Change visibility -> Public
```

### Private Images (Default)

Private images require authentication:

```bash
# Pull requires login
docker login ghcr.io
docker pull ghcr.io/arc-framework/arc-sherlock-brain:1.0.0
```

### Kubernetes Image Pull Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

---

## Troubleshooting

### Authentication Errors

```
Error: denied: permission denied
```

**Solutions:**
1. Verify PAT has `write:packages` scope
2. Re-login: `docker logout ghcr.io && docker login ghcr.io`
3. Check organization permissions

### Image Not Found

```
Error: manifest unknown
```

**Solutions:**
1. Verify image name and tag
2. Check image visibility (public/private)
3. Ensure push completed successfully

### Rate Limiting

```
Error: too many requests
```

**Solutions:**
1. Authenticate requests (higher limits)
2. Implement caching in CI/CD
3. Use GitHub Actions cache for layers

### Build Failures

```
Error: failed to fetch base image
```

**Solutions:**
1. Verify base image tag exists
2. Check GHCR login status
3. Ensure base image was pushed before service build

---

## Security Best Practices

### 1. Token Security

- Use repository secrets, never commit tokens
- Rotate PATs regularly
- Use `GITHUB_TOKEN` in Actions when possible

### 2. Image Signing

```bash
# Sign with cosign (future implementation)
cosign sign ghcr.io/arc-framework/arc-sherlock-brain:1.0.0
```

### 3. Vulnerability Scanning

```bash
# Scan before pushing
trivy image ghcr.io/arc-framework/arc-sherlock-brain:1.0.0
```

### 4. Retention Policy

- Delete old PR/branch tags after 30 days
- Keep all semver release tags
- Implement cleanup in CI/CD

---

## Quick Reference

### Commands

```bash
# Login
echo $GHCR_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build
docker build -t ghcr.io/arc-framework/IMAGE:TAG .

# Push
docker push ghcr.io/arc-framework/IMAGE:TAG

# Pull
docker pull ghcr.io/arc-framework/IMAGE:TAG

# List tags
gh api repos/OWNER/REPO/packages/container/IMAGE/versions | jq '.[].metadata.container.tags'

# Delete tag
gh api -X DELETE repos/OWNER/REPO/packages/container/IMAGE/versions/VERSION_ID
```

### URLs

| Resource | URL |
|----------|-----|
| GHCR Registry | `ghcr.io/arc-framework` |
| Package Settings | `github.com/arc-framework/arc-platform/pkgs/container/IMAGE/settings` |
| Documentation | `docs.github.com/en/packages` |

---

## Related Documentation

- [Image Tagging Strategy](./IMAGE-TAGGING.md) - Tagging conventions
- [Docker Image Hierarchy](../architecture/DOCKER-IMAGE-HIERARCHY.md) - Image dependencies
- [Security Scanning](./SECURITY-SCANNING.md) - Pre-push security checks
