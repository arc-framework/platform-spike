# Base Image Migration Guide

This document describes the migration path for Python services to use the `arc-base-python-ai` base image.

---

## Current State

### Services Using Python

| Service | Python Version | Current Base | Migration Status |
|---------|---------------|--------------|------------------|
| arc-sherlock-brain | 3.11 | python:3.11-alpine3.19 | Ready |
| arc-scarlett-voice | 3.11 | python:3.11-alpine3.19 | Ready |
| arc-piper-tts | 3.12 | python:3.12-alpine3.19 | Needs version alignment |

### Base Image

- **Image**: `arc-base-python-ai`
- **Location**: `.docker/base/python-ai/Dockerfile`
- **Published**: Not yet (requires GHCR setup)
- **Registry target**: `ghcr.io/arc-framework/base-python-ai`

---

## Migration Prerequisites

Before migrating services to use the base image:

1. **Publish base image to GHCR**
   ```bash
   # Build with metadata
   docker build \
     --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
     --build-arg VCS_REF=$(git rev-parse --short HEAD) \
     -t ghcr.io/arc-framework/base-python-ai:3.11-alpine3.19 \
     .docker/base/python-ai/

   # Push to registry
   docker push ghcr.io/arc-framework/base-python-ai:3.11-alpine3.19
   ```

2. **Set up GitHub Actions for base image CI/CD**
   - Workflow: `.github/workflows/build-base-images.yml`
   - Triggers on changes to `.docker/base/**`

3. **Align Python versions**
   - arc-piper-tts uses Python 3.12
   - Either create a 3.12 base image variant or migrate piper to 3.11

---

## Migration Steps

### Step 1: Update Dockerfile FROM Statement

**Before** (current):
```dockerfile
FROM python:3.11-alpine3.19 AS builder
# ... builder stage ...

FROM python:3.11-alpine3.19
# ... runtime stage ...
```

**After** (migrated):
```dockerfile
FROM python:3.11-alpine3.19 AS builder
# ... builder stage (unchanged - needs build tools) ...

FROM ghcr.io/arc-framework/base-python-ai:3.11-alpine3.19
# ... runtime stage (simplified) ...
```

### Step 2: Remove Duplicate Dependencies

The base image already includes:
- `libpq` (PostgreSQL client)
- `curl`, `wget` (health checks)
- `libgomp`, `libstdc++` (math libraries)
- `libffi` (FFI support)
- `tzdata`, `ca-certificates`
- Non-root user `arcuser:1000`

**Remove from service Dockerfiles**:
```dockerfile
# REMOVE these lines - provided by base image
RUN apk add --no-cache \
    curl \
    libpq \
    libgomp \
    libstdc++
```

### Step 3: Simplify User Setup

**Remove** (provided by base image):
```dockerfile
# REMOVE - base image provides arcuser:1000
RUN addgroup -g 1000 sherlock && \
    adduser -D -u 1000 -G sherlock sherlock && \
    chown -R sherlock:sherlock /app
USER sherlock
```

**Keep** (if using service-specific username):
```dockerfile
# Optional: Can still use base image's arcuser
USER arcuser
```

### Step 4: Test the Migration

```bash
# Build migrated service
docker build -t arc-sherlock-brain:migrated services/arc-sherlock-brain/

# Compare image sizes
docker images | grep sherlock

# Run tests
docker run --rm arc-sherlock-brain:migrated python --version
docker run --rm arc-sherlock-brain:migrated wget --spider localhost:8000/health
```

---

## Example: Migrated arc-sherlock-brain Dockerfile

```dockerfile
# ==============================================================================
# arc-sherlock-brain Dockerfile (Migrated to base image)
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder (unchanged - needs build dependencies)
# ------------------------------------------------------------------------------
FROM python:3.11-alpine3.19 AS builder

WORKDIR /build

RUN apk add --no-cache \
    build-base \
    gcc \
    g++ \
    musl-dev \
    postgresql-dev

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -r requirements.txt

# ------------------------------------------------------------------------------
# Stage 2: Runtime (uses base image)
# ------------------------------------------------------------------------------
FROM ghcr.io/arc-framework/base-python-ai:3.11-alpine3.19

LABEL org.opencontainers.image.title="arc-sherlock-brain" \
      org.opencontainers.image.description="LangGraph reasoning engine" \
      org.opencontainers.image.version="0.1.0"

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Ensure ownership (arcuser from base image)
RUN chown -R arcuser:arcuser /app

# Expose FastAPI port
EXPOSE 8000

# Override base image healthcheck with service-specific
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Migration Decision

### Current Recommendation: **Defer Migration**

**Reasoning**:
1. Base image not yet published to GHCR
2. Current Dockerfiles are already well-optimized
3. Services work correctly with current approach
4. Migration can happen incrementally after GHCR setup

### When to Migrate

Migrate when **all** of these are true:
- [ ] Base image published to GHCR
- [ ] GitHub Actions workflow for base image CI/CD is active
- [ ] Python version aligned across all services
- [ ] Team agrees on base image update cadence

---

## Benefits After Migration

| Benefit | Impact |
|---------|--------|
| Reduced duplication | ~20MB per service |
| Faster builds | Shared layers cached |
| Consistent security | One place to patch |
| Simplified Dockerfiles | Less code to maintain |

---

## Related Documentation

- [Docker Image Hierarchy](../architecture/DOCKER-IMAGE-HIERARCHY.md)
- [Docker Standards](../standards/DOCKER-STANDARDS.md)
- [GHCR Publishing Guide](./GHCR-PUBLISHING.md)
