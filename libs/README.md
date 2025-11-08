# Shared Libraries & SDKs

Shared code libraries and Software Development Kits (SDKs) for building services on the A.R.C. Framework.

---

## Overview

This directory contains reusable libraries and SDKs that services can import. These provide common functionality, reduce code duplication, and ensure consistency across services.

---

## Planned Libraries

### arc-sdk-go
Go SDK for building services on A.R.C.
- Core client libraries
- Telemetry integration (OTel)
- Messaging helpers (NATS, Pulsar)
- Common middleware
- Authentication helpers

### arc-sdk-python
Python SDK for building AI agents
- Agent framework
- LLM integrations
- RAG utilities
- Vector database clients
- Telemetry integration

### arc-sdk-typescript
TypeScript SDK for web services
- API client libraries
- React components
- WebSocket helpers
- State management
- Telemetry integration

---

## Library Organization

```
libs/
├── arc-sdk-go/
│   ├── go.mod
│   ├── README.md
│   ├── client/              # Client libraries
│   ├── middleware/          # HTTP/gRPC middleware
│   ├── telemetry/           # OTel helpers
│   └── messaging/           # NATS/Pulsar clients
│
├── arc-sdk-python/
│   ├── pyproject.toml
│   ├── README.md
│   ├── arc/
│   │   ├── agent/           # Agent framework
│   │   ├── llm/             # LLM integrations
│   │   ├── rag/             # RAG utilities
│   │   └── telemetry/       # OTel helpers
│   └── tests/
│
└── arc-sdk-typescript/
    ├── package.json
    ├── README.md
    ├── src/
    │   ├── client/          # API clients
    │   ├── components/      # React components
    │   └── telemetry/       # OTel helpers
    └── tests/
```

---

## Usage

### In Go Services
```go
import (
    "github.com/arc-framework/arc-sdk-go/client"
    "github.com/arc-framework/arc-sdk-go/telemetry"
)
```

### In Python Services
```python
from arc.agent import Agent
from arc.llm import LLMClient
from arc.telemetry import configure_telemetry
```

### In TypeScript Services
```typescript
import { ARCClient } from '@arc-framework/sdk';
import { configureT elemetry } from '@arc-framework/sdk/telemetry';
```

---

## Development

### Creating a New Library

1. Create directory under `libs/`
2. Follow language conventions for structure
3. Include comprehensive README
4. Write tests
5. Set up CI/CD for testing and publishing

### Versioning

All SDKs follow semantic versioning:
- Major version: Breaking changes
- Minor version: New features (backward compatible)
- Patch version: Bug fixes

Example: `v1.2.3`

---

## See Also

- [Services](../services/) - Application services that use these libraries
- [Core](../core/) - Framework infrastructure
- [Documentation](../docs/) - Framework documentation
# Core Services

Required components for the A.R.C. Framework. These services are essential for the framework to function.

---

## Overview

Core services provide the fundamental infrastructure that all agents and applications depend on. Unlike plugins, these cannot be completely removed (though implementations can be swapped).

---

## Core Components

### [Gateway](./gateway/)
API Gateway and traffic routing
- **Default**: Traefik
- **Alternatives**: Kong, Envoy, NGINX
- **Purpose**: Traffic routing, load balancing, SSL termination

### [Telemetry](./telemetry/)
Centralized telemetry collection and distribution
- **Implementation**: OpenTelemetry Collector (required)
- **Purpose**: Collect logs, metrics, and traces from all services
- **Note**: This is NOT swappable - OTel is the standard

### [Messaging](./messaging/)
Message broker infrastructure for agent communication

#### [Ephemeral](./messaging/ephemeral/)
Temporary message queue for real-time communication
- **Default**: NATS
- **Alternatives**: RabbitMQ, Redis Streams
- **Purpose**: Agent-to-agent messaging, pub/sub

#### [Durable](./messaging/durable/)
Persistent event streaming for conveyor belt pattern
- **Default**: Pulsar
- **Alternatives**: Kafka, EventStoreDB
- **Purpose**: Event sourcing, audit trail, replay capability

### [Persistence](./persistence/)
Database for agent state and vector storage
- **Default**: Postgres + pgvector
- **Alternatives**: MySQL, CockroachDB, TimescaleDB
- **Purpose**: Agent state, RAG vectors, metadata

### [Caching](./caching/)
Distributed cache and session storage
- **Default**: Redis
- **Alternatives**: Valkey, DragonflyDB, KeyDB
- **Purpose**: Session state, locks, rate limiting, fast lookups

### [Secrets](./secrets/)
Secrets management for API keys and credentials
- **Default**: Infisical
- **Alternatives**: HashiCorp Vault, AWS Secrets Manager
- **Purpose**: LLM API keys, database credentials, certificates

### [Feature Management](./feature-management/)
Feature flags and configuration (optional)
- **Default**: Unleash
- **Alternatives**: Environment variables, LaunchDarkly
- **Purpose**: Feature toggles, A/B testing, gradual rollouts
- **Note**: Optional - can use environment variables instead

---

## Architecture Pattern

```
Pattern: category/[subcategory]/implementation/

Example:
core/
├── messaging/
│   ├── ephemeral/
│   │   └── nats/           # Implementation
│   └── durable/
│       └── pulsar/         # Implementation
```

---

## Swappable vs Required

| Component | Required | Swappable |
|-----------|----------|-----------|
| Gateway | ✅ YES | ✅ YES |
| Telemetry (OTel) | ✅ YES | ❌ NO |
| Messaging | ✅ YES | ✅ YES |
| Persistence | ✅ YES | ✅ YES |
| Caching | ✅ YES | ✅ YES |
| Secrets | ✅ YES | ✅ YES |
| Feature Management | ⚠️ OPTIONAL | ✅ YES |

**Required**: Framework won't function without this category  
**Swappable**: Implementation can be replaced with alternatives

---

## See Also

- [Plugins](../plugins/) - Optional components
- [Services](../services/) - Application services
- [Architecture Documentation](../docs/architecture/)

