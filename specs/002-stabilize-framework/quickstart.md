# Quick Reference: A.R.C. Framework Structure & Docker Standards

**Last Updated:** January 10, 2026  
**Feature:** 002-stabilize-framework

---

## 📁 Where Does My Service Live?

### Decision Tree

```
Is it required for the platform to function?
├─ YES → core/
│  └─ Examples: Gateway, Database, Cache, Messaging
│
└─ NO → Is it swappable?
   ├─ YES → plugins/
   │  └─ Examples: Identity, Logging, Metrics, Search
   │
   └─ NO → services/
      └─ Examples: Sherlock (brain), Scarlett (voice), Piper (TTS)
```

### Directory Structure

```
platform-spike/
├── core/                        # Essential infrastructure (can't run without it)
│   ├── gateway/traefik/         # arc-heimdall-gateway
│   ├── persistence/postgres/    # arc-oracle-sql
│   ├── caching/redis/           # arc-sonic-cache
│   ├── messaging/ephemeral/nats/    # arc-flash-pulse
│   ├── messaging/durable/pulsar/    # arc-strange-stream
│   └── telemetry/otel-collector/    # arc-widow-otel
│
├── plugins/                     # Optional/swappable components
│   ├── security/identity/kratos/    # arc-jarvis-identity
│   ├── observability/logging/loki/  # arc-watson-logs
│   ├── observability/metrics/prometheus/  # arc-house-metrics
│   └── observability/tracing/jaeger/      # arc-columbo-traces
│
├── services/                    # Application logic (A.R.C.-specific)
│   ├── arc-sherlock-brain/      # LangGraph reasoning engine
│   ├── arc-scarlett-voice/      # Voice agent
│   ├── arc-piper-tts/           # Text-to-speech
│   └── utilities/raymond/       # Utility services
│
├── .docker/base/                # Shared base images (NEW)
├── .templates/                  # Dockerfile templates (NEW)
├── scripts/validate/            # Validation scripts (ENHANCED)
├── deployments/docker/          # Docker Compose files
├── libs/python-sdk/             # Shared Python SDK
└── docs/                        # Documentation
```

---

## 🐳 Dockerfile Standards (Quick Reference)

### Security Checklist

Every production Dockerfile MUST:

- ✅ Use **multi-stage build** (builder + runtime)
- ✅ Run as **non-root user** (UID 1000)
- ✅ Use **pinned versions** (no `:latest` tags)
- ✅ Include **health check**
- ✅ Have **OCI labels** (title, description, version)
- ✅ Remove **build tools** from final image

### Language-Specific Templates

#### Go Services (Infrastructure)

```dockerfile
FROM golang:1.21-alpine3.19 AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o app

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=builder /build/app /app
RUN addgroup -g 1000 arcuser && adduser -D -u 1000 -G arcuser arcuser
USER arcuser
HEALTHCHECK --interval=30s CMD ["/app", "health"]
ENTRYPOINT ["/app"]
```

**Size Target:** <50MB

#### Python Services (AI/Agents)

```dockerfile
FROM python:3.11-alpine3.19 AS builder
WORKDIR /build
RUN apk add --no-cache build-base postgresql-dev
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user -r requirements.txt

FROM python:3.11-alpine3.19
RUN apk add --no-cache curl libpq
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
COPY src/ /app/src/
WORKDIR /app
RUN addgroup -g 1000 arcuser && adduser -D -u 1000 -G arcuser arcuser && \
    chown -R arcuser:arcuser /app
USER arcuser
HEALTHCHECK --interval=30s CMD ["curl", "-f", "http://localhost:8000/health"]
CMD ["python", "-m", "src.main"]
```

**Size Target:** <500MB

#### Node.js Services (Frontend)

```dockerfile
FROM node:20-alpine3.19 AS builder
WORKDIR /build
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --only=production

FROM node:20-alpine3.19
WORKDIR /app
COPY --from=builder /build/node_modules ./node_modules
COPY . .
RUN addgroup -g 1000 arcuser && adduser -D -u 1000 -G arcuser arcuser && \
    chown -R arcuser:arcuser /app
USER arcuser
HEALTHCHECK --interval=30s CMD ["node", "health.js"]
CMD ["node", "server.js"]
```

**Size Target:** <200MB

### OCI Labels (Required)

```dockerfile
LABEL org.opencontainers.image.title="arc-sherlock-brain" \
      org.opencontainers.image.description="LangGraph reasoning engine" \
      org.opencontainers.image.version="0.1.0" \
      arc.service.codename="sherlock" \
      arc.service.role="brain" \
      arc.service.tier="services"
```

---

## 🚀 Quick Commands

### Validate Your Changes

```bash
# Check directory structure consistency
make validate-structure

# Lint all Dockerfiles
make validate-dockerfiles

# Scan for security vulnerabilities
make validate-security

# Check image sizes
make validate-images

# Run all validations
make validate-all
```

### Build & Test Locally

```bash
# Build a specific service
docker build -t arc-sherlock-brain:test services/arc-sherlock-brain/

# Test multi-stage build layers
docker build --target builder -t arc-sherlock-brain:builder services/arc-sherlock-brain/

# Inspect image size
docker images arc-sherlock-brain:test

# Run security scan
trivy image arc-sherlock-brain:test

# Check for non-root user
docker inspect arc-sherlock-brain:test | jq '.[0].Config.User'
```

### Common Issues

#### "Image too large"
```bash
# Check layer sizes
docker history arc-sherlock-brain:test --human --no-trunc

# Common fixes:
# 1. Use multi-stage build (separate build from runtime)
# 2. Remove build tools (gcc, build-base) from final stage
# 3. Use .dockerignore to exclude unnecessary files
# 4. Combine RUN commands to reduce layers
```

#### "Build is slow"
```bash
# Check cache hit rate
docker build --progress=plain ...

# Common fixes:
# 1. Order layers: dependencies before code (changes less frequently)
# 2. Use cache mounts: --mount=type=cache,target=/root/.cache/pip
# 3. Copy only what's needed: COPY requirements.txt . (not COPY . .)
# 4. Enable BuildKit: export DOCKER_BUILDKIT=1
```

#### "Failed security scan"
```bash
# Identify vulnerabilities
trivy image --severity HIGH,CRITICAL arc-sherlock-brain:test

# Common fixes:
# 1. Update base image to latest patch version
# 2. Update dependencies in requirements.txt/go.mod/package.json
# 3. Use distroless or minimal base images
# 4. Remove unnecessary packages
```

---

## 📊 Success Targets

Your service should meet these targets:

| Metric | Target | How to Check |
|--------|--------|--------------|
| **Image Size** | Go <50MB, Python <500MB, Node <200MB | `docker images <service>` |
| **Build Time (incremental)** | <60 seconds | `time docker build ...` |
| **Security Vulnerabilities** | 0 HIGH/CRITICAL | `trivy image <service>` |
| **Dockerfile Lint** | 0 errors | `hadolint Dockerfile` |
| **Non-root User** | UID 1000 | `docker inspect <service> \| jq '.[0].Config.User'` |
| **Multi-stage Build** | Yes | Check for multiple `FROM` statements |
| **Health Check** | Present | `docker inspect <service> \| jq '.[0].Config.Healthcheck'` |

---

## 🦸 Service Registry

All services are defined in [SERVICE.MD](../../../SERVICE.MD) - The A.R.C. Pantheon.

**Common Codenames:**
- **Infrastructure:** Heimdall (Gateway), Oracle (Postgres), Sonic (Redis), Flash (NATS), Dr. Strange (Pulsar)
- **Observability:** Watson (Loki), House (Prometheus), Columbo (Jaeger), Friday (Grafana)
- **Agents:** Sherlock (Brain), Scarlett (Voice), Piper (TTS)
- **Workers:** Ramsay (Critic), Drago (Gym)
- **Security:** J.A.R.V.I.S. (Kratos), Fury (Infisical), RoboCop (Guardrails)

---

## 🔗 Additional Resources

- **Full Standards:** [docker-standards.md](./docker-standards.md)
- **Directory Design:** [directory-design.md](./directory-design.md)
- **Migration Guide:** [migration-guide.md](./migration-guide.md)
- **Implementation Plan:** [plan.md](./plan.md)
- **Feature Spec:** [spec.md](./spec.md)

---

## 🆘 Getting Help

1. **Check existing service Dockerfiles** for examples (e.g., `services/arc-sherlock-brain/Dockerfile`)
2. **Use templates** in `.templates/` directory
3. **Run validation locally** before pushing: `make validate-all`
4. **Review CI/CD feedback** - validation runs on every PR
5. **Ask the team** - #arc-platform Slack channel

---

**"Elementary, my dear Watson."** - Sherlock (A.R.C. Brain)

When in doubt, follow the patterns established by existing services. Consistency > Cleverness.

