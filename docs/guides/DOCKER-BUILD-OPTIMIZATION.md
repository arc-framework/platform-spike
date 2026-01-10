# Docker Build Optimization Guide

**Task:** T050
**Last Updated:** January 2026

This guide covers techniques for optimizing Docker builds in the A.R.C. platform.

---

## Overview

Fast, efficient Docker builds are critical for developer productivity. This guide covers:

- Layer ordering for optimal caching
- Cache mounts for dependency installation
- Multi-stage builds for smaller images
- BuildKit configuration
- Performance measurement

---

## Build Targets

From the A.R.C. Constitution:

| Metric | Target | Notes |
|--------|--------|-------|
| Warm build (code change) | <60 seconds | With cached dependencies |
| Cold build (clean) | <5 minutes | No cache |
| Python image size | <500MB | Final runtime image |
| Go image size | <50MB | Statically compiled |
| Cache hit rate | >85% | For dependency layers |

---

## Layer Ordering

Docker caches layers sequentially. If a layer changes, all subsequent layers are rebuilt. Order layers from least to most frequently changed:

### Optimal Order

```dockerfile
# 1. Base image (rarely changes)
FROM python:3.11-alpine3.19

# 2. System packages (monthly updates)
RUN apk add --no-cache libpq curl

# 3. Dependencies file (weekly changes)
COPY requirements.txt .

# 4. Install dependencies (cached until requirements.txt changes)
RUN pip install -r requirements.txt

# 5. Application code (daily changes)
COPY src/ ./src/
```

### Anti-Pattern: Copying Everything First

```dockerfile
# BAD: Any file change invalidates all subsequent layers
FROM python:3.11-alpine3.19
COPY . .  # <-- This invalidates cache for ANY file change
RUN pip install -r requirements.txt
```

---

## Cache Mounts

BuildKit cache mounts persist package manager caches between builds:

### Python (pip)

```dockerfile
# Mount pip cache - survives between builds
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

### Go (modules)

```dockerfile
# Mount both module cache and build cache
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o app ./cmd/main.go
```

### Node.js (npm)

```dockerfile
RUN --mount=type=cache,target=/root/.npm \
    npm ci
```

---

## Multi-Stage Builds

Separate build-time dependencies from runtime:

### Python Example

```dockerfile
# Stage 1: Builder with dev dependencies
FROM python:3.11-alpine3.19 AS builder
WORKDIR /build

# Install build tools
RUN apk add --no-cache build-base gcc

# Install Python packages to user directory
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user -r requirements.txt

# Stage 2: Runtime without build tools
FROM python:3.11-alpine3.19
WORKDIR /app

# Copy only the installed packages
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY src/ ./src/

CMD ["python", "-m", "src.main"]
```

**Size Impact:**
- With build tools: ~800MB
- Without build tools: ~350MB

### Go Example

```dockerfile
# Stage 1: Build
FROM golang:1.21-alpine AS builder
WORKDIR /build

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o app ./cmd/main.go

# Stage 2: Minimal runtime
FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=builder /build/app /app
CMD ["/app"]
```

**Size Impact:**
- Go builder image: ~400MB
- Final image: ~30MB

---

## .dockerignore Configuration

Reduce build context size by excluding unnecessary files:

### Python Service

```dockerignore
# Git
.git/
.gitignore

# Python artifacts
__pycache__/
*.py[cod]
*.egg-info/
.pytest_cache/
.mypy_cache/
.ruff_cache/

# Testing
tests/
*_test.py
conftest.py

# Development
.env*
.venv/
*.md
docs/

# IDE
.idea/
.vscode/

# Docker
Dockerfile*
docker-compose*.yml
```

### Go Service

```dockerignore
# Git
.git/
.gitignore

# Go artifacts
*.exe
*.test
*.out

# Documentation
*.md
docs/

# Testing
*_test.go
testdata/

# Development
.env*
Makefile
```

---

## BuildKit Configuration

### Enable BuildKit

```bash
# Option 1: Environment variable
export DOCKER_BUILDKIT=1

# Option 2: Docker daemon config (/etc/docker/daemon.json)
{
  "features": {
    "buildkit": true
  }
}

# Option 3: Per-build
DOCKER_BUILDKIT=1 docker build -t myimage .
```

### BuildKit Features

| Feature | Description | Usage |
|---------|-------------|-------|
| Cache mounts | Persist caches | `--mount=type=cache` |
| Secret mounts | Secure credentials | `--mount=type=secret` |
| SSH mounts | Git authentication | `--mount=type=ssh` |
| Parallel builds | Build stages concurrently | Automatic |
| Better output | Progress display | `--progress=plain` |

---

## Parallel Stage Builds

BuildKit automatically parallelizes independent stages:

```dockerfile
# These stages build in parallel
FROM python:3.11-alpine AS python-deps
RUN pip install ...

FROM node:18-alpine AS node-deps
RUN npm install ...

# This stage waits for both
FROM python:3.11-alpine
COPY --from=python-deps /root/.local /root/.local
COPY --from=node-deps /app/node_modules ./node_modules
```

---

## Measuring Performance

### Track Build Times

```bash
# Measure single build
time docker build -t myimage .

# Use A.R.C. tracker
./scripts/validate/track-build-times.sh --warm
./scripts/validate/track-build-times.sh --cold

# JSON output for CI
./scripts/validate/track-build-times.sh --json > report.json
```

### Check Image Sizes

```bash
# List image sizes
docker images arc-* --format "{{.Repository}}\t{{.Size}}"

# Use A.R.C. validator
python scripts/validate/check-image-sizes.py

# Strict mode (fail on violation)
python scripts/validate/check-image-sizes.py --strict
```

### Analyze Layers

```bash
# Show layer history
docker history arc-sherlock-brain:local

# Detailed inspection with dive
dive arc-sherlock-brain:local
```

---

## Common Optimizations

### 1. Use Alpine Base Images

```dockerfile
# Instead of
FROM python:3.11

# Use
FROM python:3.11-alpine3.19
```

**Impact:** 5-10x smaller images

### 2. Combine RUN Commands

```dockerfile
# Instead of
RUN apk add curl
RUN apk add wget
RUN apk add ca-certificates

# Use
RUN apk add --no-cache \
    curl \
    wget \
    ca-certificates
```

**Impact:** Fewer layers, smaller image

### 3. Clean Up in Same Layer

```dockerfile
RUN apk add --no-cache --virtual .build-deps \
        build-base \
        gcc \
    && pip install -r requirements.txt \
    && apk del .build-deps
```

**Impact:** Build deps don't persist to final image

### 4. Use Specific Tags

```dockerfile
# Instead of
FROM python:latest

# Use
FROM python:3.11-alpine3.19
```

**Impact:** Reproducible builds

### 5. Copy Dependency Files First

```dockerfile
# Copy requirements before source
COPY requirements.txt .
RUN pip install -r requirements.txt

# Then copy source
COPY src/ ./src/
```

**Impact:** Dependency cache survives code changes

---

## Troubleshooting

### Build Cache Not Working

**Symptoms:** Every build reinstalls dependencies

**Causes:**
1. File ordering - copying source before deps
2. .dockerignore missing - context changes
3. BuildKit not enabled

**Solutions:**
```bash
# Check if BuildKit is enabled
docker info | grep BuildKit

# Force cache use
docker build --cache-from=previous-image -t new-image .
```

### Image Too Large

**Symptoms:** Python image >500MB, Go image >50MB

**Causes:**
1. Build tools in final image
2. Missing multi-stage build
3. Large files in context

**Solutions:**
```bash
# Analyze image layers
docker history --no-trunc myimage

# Check for large files
docker run --rm myimage du -sh /* | sort -h
```

### Slow Context Transfer

**Symptoms:** "Sending build context" takes long time

**Causes:**
1. Missing .dockerignore
2. Large files in directory
3. node_modules, .git included

**Solutions:**
```bash
# Check context size
du -sh .

# Add comprehensive .dockerignore
cat .dockerignore
```

---

## Related Documentation

- [Docker Standards](./DOCKER-STANDARDS.md) - Dockerfile requirements
- [Security Scanning](./SECURITY-SCANNING.md) - Pre-build security checks
- [Docker Image Hierarchy](../architecture/DOCKER-IMAGE-HIERARCHY.md) - Base image strategy
