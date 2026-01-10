# Docker Standards & Best Practices

**Feature:** 002-stabilize-framework  
**Date:** January 10, 2026  
**Status:** Living Document - Standards evolve with platform needs

---

## Philosophy: Standards, Not Shackles

These are **guidelines based on production experience**, not arbitrary rules. If you have a valid reason to deviate, document it in your Dockerfile comments and move on.

**Key Principle:** Security and maintainability > dogma.

---

## Security Requirements (Non-Negotiable)

### 1. Non-Root User (MUST)

**Why:** Root users in containers = security nightmare. One escape = full host compromise.

```dockerfile
# Create user with explicit UID (consistent across environments)
RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser

USER arcuser
```

**Exception:** Init containers that genuinely need to configure system-level settings. Document why.

### 2. Pinned Base Image Versions (MUST)

**Why:** `latest` tag changes under you. Production breaks mysteriously. Debugging hell.

```dockerfile
# ❌ BAD - What version are you actually running?
FROM python:3.11-alpine

# ✅ GOOD - Reproducible builds
FROM python:3.11-alpine3.19
```

**When to update:** When base image has security patches. Document in commit message.

### 3. Multi-Stage Builds (STRONGLY RECOMMENDED)

**Why:** Build tools in production = 500MB wasted + attack surface.

```dockerfile
# Stage 1: Build (has compilers, dev headers)
FROM python:3.11-alpine3.19 AS builder
# ... build stuff ...

# Stage 2: Runtime (only what's needed to run)
FROM python:3.11-alpine3.19
COPY --from=builder /root/.local /root/.local
# No gcc, no build-base, no attack surface
```

**Exception:** Simple services that genuinely have no build step. Rare in Python/Go.

### 4. Health Checks (RECOMMENDED)

**Why:** Docker needs to know if your service is actually working, not just running.

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1
```

**Alternative:** Application-level health checks (Kubernetes livenessProbe). Choose one, not both.

---

## Language-Specific Patterns

### Go Services (Infrastructure, CLI)

**Current Use Cases:** Future CLI tools, infrastructure controllers

**Pattern:**
```dockerfile
# ==============================================================================
# Multi-stage build for Go service
# ==============================================================================
FROM golang:1.21-alpine3.19 AS builder

WORKDIR /build

# Download dependencies (cached layer)
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# Build (cached unless code changes)
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o app

# ==============================================================================
# Runtime stage
# ==============================================================================
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /build/app /app

RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser

USER arcuser

HEALTHCHECK --interval=30s CMD ["/app", "health"]

ENTRYPOINT ["/app"]
```

**Size Target:** <50MB (Go compiles to static binaries)

**Key Optimizations:**
- `CGO_ENABLED=0` - Static linking (no libc dependency)
- `-ldflags="-s -w"` - Strip debug symbols (smaller binary)
- Cache mounts - Fast rebuilds

### Python Services (AI, Agents, Workers)

**Current Use Cases:** Sherlock (brain), Scarlett (voice), Piper (TTS), Ramsay (critic), Drago (gym)

**Pattern:**
```dockerfile
# ==============================================================================
# Multi-stage build for Python AI service
# ==============================================================================
FROM python:3.11-alpine3.19 AS builder

WORKDIR /build

# Install build dependencies (only in builder stage)
RUN apk add --no-cache \
    build-base \
    gcc \
    g++ \
    musl-dev \
    postgresql-dev \
    libffi-dev

# Install Python dependencies
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -r requirements.txt

# ==============================================================================
# Runtime stage
# ==============================================================================
FROM python:3.11-alpine3.19

# Install ONLY runtime dependencies (no build tools)
RUN apk add --no-cache \
    curl \
    libpq \
    libgomp \
    libstdc++

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local

ENV PATH=/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Create non-root user
RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser && \
    chown -R arcuser:arcuser /app

USER arcuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Size Target:** <500MB (Python + AI libraries are heavy, be realistic)

**Key Optimizations:**
- Build deps only in builder stage
- `--user` flag puts packages in `/root/.local` (easier to copy)
- Cache mounts for pip (fast rebuilds)
- Alpine base (smaller than Debian)

**Common Dependencies:**
- `postgresql-dev` (builder) + `libpq` (runtime) → psycopg2
- `build-base gcc g++` (builder) → numpy, pandas, scikit-learn
- `libgomp libstdc++` (runtime) → numpy, scipy math operations

---

## Build Performance Optimization

### Layer Ordering (Critical for Cache Hits)

**Order from least to most frequently changed:**

1. **OS packages** (rarely change)
2. **Dependency manifests** (requirements.txt, go.mod - change occasionally)
3. **Dependencies themselves** (install from manifests)
4. **Application code** (changes frequently)

```dockerfile
# ✅ GOOD - Dependencies cached separately from code
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/ ./src/

# ❌ BAD - Code change invalidates dependency cache
COPY . .
RUN pip install -r requirements.txt
```

### Cache Mounts (BuildKit Feature)

**Faster than copying dependency caches manually:**

```dockerfile
# Python pip cache
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Go module cache
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
```

**Enables:** Incremental builds complete in <60 seconds (target from spec).

### .dockerignore File

**Prevent copying unnecessary files:**

```
# .dockerignore
.git
.github
.vscode
*.md
docs/
tests/
*.pyc
__pycache__
.pytest_cache
.coverage
htmlcov/
venv/
.env
*.log
```

**Impact:** Faster COPY operations, smaller build context.

---

## OCI Labels & Metadata

**Why:** Track images in GHCR, understand what's running in production, automate monitoring.

```dockerfile
LABEL org.opencontainers.image.title="arc-sherlock-brain" \
      org.opencontainers.image.description="LangGraph reasoning engine with pgvector memory" \
      org.opencontainers.image.version="0.2.1" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      org.opencontainers.image.source="https://github.com/arc/platform-spike" \
      arc.service.codename="sherlock" \
      arc.service.role="brain" \
      arc.service.tier="services" \
      arc.service.type="CORE"
```

**Custom Labels (A.R.C. Specific):**
- `arc.service.codename` - Marvel/Hollywood codename (sherlock, heimdall, sonic)
- `arc.service.role` - Human-readable role (brain, gateway, cache)
- `arc.service.tier` - Directory tier (core, plugins, services)
- `arc.service.type` - Registry type (INFRA, CORE, WORKER, SIDECAR)

**Use Case:** `docker images --filter label=arc.service.tier=core` lists all core services.

---

## Image Size Targets (Guidelines, Not Laws)

| Service Type | Target | Rationale |
|-------------|--------|-----------|
| **Go Services** | <50MB | Static binaries, no runtime needed |
| **Python AI Services** | <500MB | AI libraries (numpy, torch) are heavy - be realistic |
| **Infrastructure** | <100MB | Minimal OS + runtime (Redis, NATS configs) |

**If you exceed the target:**
1. Measure actual size: `docker images <service>`
2. Analyze layers: `docker history <service> --human`
3. Identify bloat (build tools left in? Unnecessary packages?)
4. Document why if bloat is justified (e.g., torch needs CUDA libs)

**Don't obsess over 10MB differences.** Optimize when it matters (network transfer, startup time).

---

## Security Scanning (Automated in CI/CD)

### Tools

1. **hadolint** - Dockerfile linting
   ```bash
   hadolint Dockerfile
   ```

2. **trivy** - Vulnerability scanning
   ```bash
   trivy image arc-sherlock-brain:latest
   ```

3. **grype** - Alternative vulnerability scanner
   ```bash
   grype arc-sherlock-brain:latest
   ```

### Acceptance Criteria

- **Zero hadolint errors** (warnings are negotiable)
- **Zero HIGH/CRITICAL vulnerabilities** in production images
- **Document exceptions** (e.g., false positives, patches not yet available)

---

## Common Anti-Patterns (Don't Do This)

### 1. Running as Root in Production

```dockerfile
# ❌ Security nightmare
USER root
CMD ["python", "app.py"]
```

**Fix:** Create and switch to non-root user.

### 2. Using :latest Tags

```dockerfile
# ❌ Non-reproducible builds
FROM python:latest
```

**Fix:** Pin to specific version `python:3.11-alpine3.19`.

### 3. Installing Build Tools in Runtime Stage

```dockerfile
# ❌ Bloated image + attack surface
FROM python:3.11-alpine3.19
RUN apk add gcc build-base  # WHY IN RUNTIME?
```

**Fix:** Use multi-stage build, install build deps only in builder.

### 4. Copying Everything

```dockerfile
# ❌ Invalidates cache on any file change
COPY . .
```

**Fix:** Copy selectively (requirements first, then code).

### 5. Missing Health Checks

```dockerfile
# ❌ Docker can't detect if service is actually working
# No HEALTHCHECK
```

**Fix:** Add HEALTHCHECK or rely on orchestrator probes.

---

## Template Flexibility

**These patterns are STARTING POINTS, not prison sentences.**

**When to deviate:**
- Service has unique requirements (GPU support, exotic dependencies)
- Performance profiling shows a different approach is faster
- New technology requires a different pattern

**How to deviate properly:**
1. Document WHY in Dockerfile comments
2. Ensure security requirements still met (non-root, pinned versions)
3. Update this doc with the new pattern if it's broadly applicable

**Example:**
```dockerfile
# NOTE: Using Debian instead of Alpine because:
# - TensorFlow wheels don't build reliably on Alpine (musl libc issues)
# - GPU support requires CUDA libs only available for Debian
# - Accepted tradeoff: 200MB larger image for reliable GPU acceleration
FROM python:3.11-slim-bookworm
```

---

## Validation Checklist

Before merging any Dockerfile:

- [ ] Multi-stage build (or documented exception)
- [ ] Non-root user (UID 1000)
- [ ] Pinned base image version
- [ ] Health check present
- [ ] OCI labels complete
- [ ] hadolint passes with no errors
- [ ] Image size within target (or documented why not)
- [ ] .dockerignore file present
- [ ] Build completes in <5 minutes on clean build
- [ ] Incremental build completes in <60 seconds

**Run locally:**
```bash
make validate-dockerfiles  # Runs hadolint
make validate-security     # Runs trivy scan
make validate-images       # Checks sizes
```

---

## References

- **CIS Docker Benchmark:** https://www.cisecurity.org/benchmark/docker
- **Docker Best Practices:** https://docs.docker.com/develop/dev-best-practices/
- **hadolint Rules:** https://github.com/hadolint/hadolint
- **BuildKit Cache Mounts:** https://docs.docker.com/build/cache/

---

**Status:** ✅ Production-Ready Standards

**Last Updated:** January 10, 2026

**"It's not about being perfect. It's about being secure, fast, and maintainable. In that order."** - The A.R.C. Architect

