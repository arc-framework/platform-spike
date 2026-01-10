# A.R.C. Services

Application logic, AI agents, and reasoning engines built on the A.R.C. Framework.

---

## Overview

Services contain the business-specific workloads that run on top of A.R.C. infrastructure. Unlike core (required) and plugins (optional infrastructure), services implement the actual AI capabilities and application logic.

---

## Inclusion Criteria

A component belongs in `services/` if:

- Business logic specific to A.R.C. applications
- AI agents and reasoning engines
- Workers and background processors
- Utilities that support the application layer

**NOT services** (belongs elsewhere):

- Infrastructure components → `core/`
- Optional monitoring/auth → `plugins/`
- Shared libraries → `libs/`

---

## Current Services

| Service | Codename | Purpose | Language | Status |
|---------|----------|---------|----------|--------|
| [arc-sherlock-brain](./arc-sherlock-brain/) | sherlock | LangGraph reasoning engine with pgvector memory | Python | Active |
| [arc-scarlett-voice](./arc-scarlett-voice/) | scarlett | Voice agent, speech-to-text processing | Python | Active |
| [arc-piper-tts](./arc-piper-tts/) | piper | Text-to-speech synthesis | Python | Active |
| [raymond](./utilities/raymond/) | raymond | Bootstrap utilities, health monitoring | Go | Active |

---

## Directory Structure

```
services/
├── arc-sherlock-brain/     # AI reasoning engine
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── src/
│   └── README.md
├── arc-scarlett-voice/     # Voice processing agent
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── src/
│   └── README.md
├── arc-piper-tts/          # Text-to-speech service
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── src/
│   └── README.md
└── utilities/
    └── raymond/            # Go utilities
        ├── Dockerfile
        ├── go.mod
        ├── cmd/
        └── README.md
```

---

## Service Naming Convention

Services follow the A.R.C. Constitution naming pattern:

```
arc-{codename}-{function}
```

| Component | Description | Example |
|-----------|-------------|---------|
| `arc-` | Framework prefix | `arc-` |
| `codename` | Marvel/Hollywood inspired | `sherlock`, `scarlett` |
| `function` | What it does | `brain`, `voice`, `tts` |

**Examples**:
- `arc-sherlock-brain` - Sherlock's reasoning capability
- `arc-scarlett-voice` - Scarlett's voice processing
- `arc-piper-tts` - Piper's text-to-speech

---

## Adding a New Service

### 1. Create Directory

```bash
mkdir -p services/arc-{codename}-{function}
cd services/arc-{codename}-{function}
```

### 2. Add Required Files

**Python Service:**
```bash
touch Dockerfile requirements.txt README.md
mkdir src
touch src/__init__.py src/main.py
```

**Go Service:**
```bash
touch Dockerfile README.md
go mod init github.com/arc-framework/arc-{codename}-{function}
mkdir cmd
```

### 3. Use Base Image

```dockerfile
# Python services
FROM ghcr.io/arc/base-python-ai:3.11-alpine3.19 AS base

# Go services
FROM ghcr.io/arc/base-go-infra:1.21-alpine3.19 AS builder
```

### 4. Update SERVICE.MD

Add your service to the root `SERVICE.MD` registry.

### 5. Add to Docker Compose

Add service definition to `deployments/docker/docker-compose.services.yml`.

---

## Building Services

### Local Build

```bash
# Build specific service
docker build -t arc-sherlock-brain:local services/arc-sherlock-brain/

# Build all services
make build-services
```

### Using Base Images

Services should use the shared base images from `.docker/base/`:

```dockerfile
# Use the Python AI base image
FROM ghcr.io/arc/base-python-ai:3.11-alpine3.19

# Your service-specific setup...
```

---

## Running Services

### Development

```bash
# Start core + services
make up-core-services

# Start everything (including observability)
make up-dev
```

### Individual Service

```bash
# Run specific service
docker compose -f deployments/docker/docker-compose.services.yml up arc-sherlock-brain
```

---

## Service Requirements

All services MUST:

1. **Have a Dockerfile** following [docker-standards.md](../specs/002-stabilize-framework/docker-standards.md)
2. **Run as non-root** (UID 1000, `arcuser`)
3. **Include health check** endpoint at `/health`
4. **Have README.md** documenting purpose, dependencies, and usage
5. **Use pinned base images** (no `:latest` tags)
6. **Include OCI labels** for registry management

---

## Related Documentation

- [Core Services](../core/) - Required infrastructure
- [Plugins](../plugins/) - Optional components
- [Docker Standards](../specs/002-stabilize-framework/docker-standards.md) - Dockerfile requirements
- [SERVICE.MD](../SERVICE.MD) - Service registry
- [Base Images](../.docker/) - Shared Docker base images
