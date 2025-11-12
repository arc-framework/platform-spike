# Services

Application services and AI agents built on the A.R.C. Framework.

---

## Overview

This directory contains all application-level services organized by function. Unlike core and plugins, these are the actual workloads that deliver business value.

---

## Service Categories

### [Agents](./agents/)
AI agent services - the primary workload type

#### Purpose
Intelligent agents that:
- Process natural language
- Reason about problems
- Execute complex workflows
- Interact with tools and APIs
- Learn from interactions

#### Subdirectories
- **[Examples](./agents/examples/)** - Example agent implementations
- **[Templates](./agents/templates/)** - Service templates for creating new agents
- **User Agents** - Production agent services (to be added)

#### Example Agents
```
agents/
├── reasoning-agent/      # Multi-step reasoning agent
├── code-agent/           # Code generation and analysis
├── rag-agent/            # RAG (Retrieval Augmented Generation)
└── orchestrator-agent/   # Multi-agent orchestration
```

### [Platform](./platform/)
Platform support services

#### Purpose
Services that support the framework itself:
- User management
- Authentication services
- API gateways
- Admin interfaces

#### Example Services
```
platform/
├── user-service/         # User management
├── auth-api/             # Authentication API
└── admin-dashboard/      # Admin interface
```

### [Utilities](./utilities/)
Utility and helper services

#### Purpose
Supporting services:
- Health checkers
- Data transformers
- Batch processors
- Monitoring agents

#### Current Services
```
utilities/
└── toolbox/           # Multi-purpose utility service
```

---

## Service Naming Convention

**Format**: `[domain]-[type]`

### Type Suffixes
- `-agent` - AI agent service
- `-service` - General microservice
- `-api` - HTTP API
- `-worker` - Background worker
- `-job` - Scheduled/batch job

### Examples
```
✅ reasoning-agent        # AI agent
✅ user-service           # Microservice
✅ auth-api               # HTTP API
✅ embedding-worker       # Background worker
✅ cleanup-job            # Batch job
```

---

## Standard Service Structure

Every service should follow this structure:

```
service-name/
├── README.md                   # Service overview
├── CHANGELOG.md                # Version history
├── Dockerfile                  # Container definition
├── docker-compose.[name].yml   # Service compose file
├── .env.example                # Environment template
├── config/                     # Configuration
│   ├── app.yml
│   └── [environment].yml
├── src/                        # Source code
│   └── (language-specific)
├── tests/                      # Tests
│   ├── unit/
│   └── integration/
└── docs/                       # Documentation
    ├── API.md
    ├── DEPLOYMENT.md
    └── ARCHITECTURE.md
```

---

## Multi-Language Support

Services can be written in any language:

### Currently Supported
- **Go** - Platform services, performance-critical
- **Python** - AI agents, ML workloads
- **TypeScript** - Web services, Node.js apps

### Language Detection
The framework auto-detects language from:
- `go.mod` → Go service
- `requirements.txt` / `pyproject.toml` → Python service
- `package.json` / `tsconfig.json` → TypeScript/Node service

---

## Creating New Services

### 1. Choose Category
- Is it an AI agent? → `agents/`
- Is it a platform infrastructure? → `platform/`
- Is it a utility? → `utilities/`

### 2. Use Template
```bash
# Copy appropriate template
cp -r services/agents/templates/python-agent services/agents/my-agent
cd services/agents/my-agent
```

### 3. Follow Standards
- Use kebab-case for directory name
- Include all required files (README, Dockerfile, etc.)
- Add `.env.example` with documented variables
- Write tests (unit + integration)

### 4. Document
- README.md - What it does, how to run
- API.md - API endpoints and schemas
- DEPLOYMENT.md - How to deploy

---

## Service Development Workflow

1. **Develop locally** - Use Docker Compose for dependencies
2. **Test** - Unit tests + integration tests
3. **Build image** - `docker build -t service:version .`
4. **Deploy** - Use deployment configs in `deployments/`

---

## See Also

- [Core Services](../core/) - Framework infrastructure
- [Plugins](../plugins/) - Optional components
- [Naming Conventions](../docs/guides/NAMING-CONVENTIONS.md)
- [Service Templates](./agents/templates/)
