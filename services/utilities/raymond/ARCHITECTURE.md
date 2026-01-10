# Raymond Bootstrap Service - Architecture Document

**Service Codename:** `arc-raymond-bootstrap`  
**Role:** Platform Initialization Orchestrator  
**Layer:** Application / Utilities  
**Language:** Go 1.25+

---

## 📋 Overview

Raymond is the **bootstrap orchestrator** for the A.R.C. Platform. It ensures all core infrastructure services are healthy, initializes messaging topology (NATS streams, Pulsar topics), validates database schemas, and provides deep health monitoring for the entire platform.

**Key Responsibilities:**

1. Wait for and validate all core service dependencies
2. Initialize NATS JetStream streams and consumers
3. Create Pulsar tenants, namespaces, and topics
4. Validate/seed database schemas (optional)
5. Expose health and readiness endpoints
6. Provide platform-wide connectivity testing

---

## 🏗️ Architecture Style

**Pattern:** Clean Hexagonal Architecture + Domain-Driven Design Lite  
**Principles:**

- Separation of concerns (config, telemetry, business logic)
- Dependency injection via constructors
- Interface-based abstraction for testability
- Graceful degradation and resilience

---

## 📂 Directory Structure

```
raymond/
├── cmd/
│   └── raymond/              # Application entrypoint
│       └── main.go           # Wire dependencies, start/stop services (< 150 LOC)
│
├── internal/                 # Private application code
│   ├── config/               # Configuration management
│   │   ├── config.go         # Viper-based config loader with validation
│   │   └── types.go          # Config structs with tags
│   │
│   ├── telemetry/            # Observability (OpenTelemetry)
│   │   ├── provider.go       # OTEL SDK initialization & shutdown
│   │   ├── logger.go         # Structured logging (slog + OTEL bridge)
│   │   ├── tracer.go         # Tracer interface wrapper
│   │   └── metrics.go        # Metrics registration and helpers
│   │
│   ├── health/               # Health checks & probes
│   │   ├── checker.go        # Health check orchestrator
│   │   ├── probes.go         # TCP/HTTP/gRPC probe implementations
│   │   └── handlers.go       # HTTP handlers for /health endpoints
│   │
│   ├── bootstrap/            # Bootstrap orchestration
│   │   ├── orchestrator.go   # Main bootstrap workflow coordinator
│   │   ├── nats.go           # NATS JetStream initialization
│   │   ├── pulsar.go         # Pulsar admin API (tenants/namespaces/topics)
│   │   ├── postgres.go       # Database schema validation/seeding
│   │   └── redis.go          # Cache warming (if needed)
│   │
│   ├── middleware/           # HTTP middleware
│   │   ├── logging.go        # Request/response logging with slog
│   │   ├── tracing.go        # Distributed tracing context propagation
│   │   ├── metrics.go        # Request duration/count metrics
│   │   ├── recovery.go       # Panic recovery with stack traces
│   │   └── chain.go          # Middleware composition utilities
│   │
│   ├── server/               # HTTP server
│   │   ├── server.go         # Server lifecycle (start, shutdown)
│   │   ├── routes.go         # Route registration
│   │   └── handlers.go       # Request handler implementations
│   │
│   └── clients/              # External service client wrappers
│       ├── nats.go           # NATS JetStream client
│       ├── pulsar.go         # Pulsar admin & producer clients
│       ├── postgres.go       # pgx connection pool wrapper
│       └── redis.go          # Redis client wrapper
│
├── pkg/                      # Public libraries (if needed)
│   └── errors/               # Custom error types
│       └── errors.go
│
├── tests/
│   ├── unit/                 # Unit tests (parallel, fast)
│   └── integration/          # Integration tests (testcontainers)
│
├── ARCHITECTURE.md           # This document
├── Dockerfile                # Multi-stage build (builder + runtime)
├── Makefile                  # Local development tasks
├── .golangci.yml             # Linting configuration
├── go.mod
└── go.sum
```

---

## 🎯 Core Components

### 1. Configuration (`internal/config`)

**Library:** `spf13/viper`  
**Validation:** `go-playground/validator/v10`

**Features:**

- Load from YAML file (defaults)
- Override with environment variables
- Struct validation on startup
- Hot-reload support (future)

**Example Structure:**

```go
type Config struct {
    Server     ServerConfig     `mapstructure:"server"`
    Telemetry  TelemetryConfig  `mapstructure:"telemetry"`
    Bootstrap  BootstrapConfig  `mapstructure:"bootstrap"`
}

type ServerConfig struct {
    Port         int           `mapstructure:"port" validate:"required,min=1024,max=65535"`
    ReadTimeout  time.Duration `mapstructure:"read_timeout"`
    WriteTimeout time.Duration `mapstructure:"write_timeout"`
}
```

**ENV Overrides:**

- `SERVER_PORT=9000` → `config.Server.Port`
- `TELEMETRY_OTLP_ENDPOINT=localhost:4317` → `config.Telemetry.OTLPEndpoint`

---

### 2. Telemetry (`internal/telemetry`)

**SDK:** OpenTelemetry Go SDK  
**Exporters:** OTLP gRPC (traces, metrics, logs)

**Provider Pattern:**

```go
type Provider struct {
    logger   *slog.Logger
    tracer   trace.Tracer
    meter    metric.Meter
    shutdown func(context.Context) error
}

func NewProvider(ctx context.Context, cfg *config.TelemetryConfig) (*Provider, error)
func (p *Provider) Shutdown(ctx context.Context) error
```

**Features:**

- Single gRPC connection for all OTLP exporters
- Multi-handler slog (console + OTEL)
- Pre-registered metrics (bootstrap duration, error counts, dependency health)
- Automatic context propagation

---

### 3. Health Checks (`internal/health`)

**Probe Types:**

- **TCP:** Socket dial with timeout
- **HTTP:** GET request with 2xx validation
- **gRPC:** gRPC health check protocol (future)

**Concurrent Execution:**

```go
type Checker struct {
    probes  []Probe
    logger  *slog.Logger
    timeout time.Duration
}

func (c *Checker) RunAll(ctx context.Context) map[string]Result
```

**Endpoints:**

- `GET /health` → Shallow (app alive, fast)
- `GET /health/deep?mode=deep` → Deep (all dependencies, slower)
- `GET /ready` → Bootstrap complete signal

---

### 4. Bootstrap (`internal/bootstrap`)

**Orchestrator Workflow:**

```
Phase 1: Wait for Dependencies
  ├─ PostgreSQL (arc-oracle-sql:5432)
  ├─ Redis (arc-sonic-cache:6379)
  ├─ NATS (arc-flash-pulse:4222)
  ├─ Pulsar (arc-strange-stream:8080)
  ├─ Infisical (arc-fury-vault:8080)
  └─ Unleash (arc-mystique-flags:4242)

Phase 2: Initialize NATS JetStream
  ├─ Create stream: AGENT_COMMANDS
  ├─ Create stream: AGENT_EVENTS
  └─ Create stream: SYSTEM_METRICS

Phase 3: Initialize Pulsar
  ├─ Create tenant: arc
  ├─ Create namespace: arc/events
  ├─ Create namespace: arc/logs
  └─ Create topic: persistent://arc/events/agent-lifecycle

Phase 4: Database Validation (Optional)
  └─ Validate schema exists: arc_platform

Phase 5: Mark Ready
  └─ Set readiness flag → /ready returns 200
```

**Error Handling:**

- Exponential backoff for retries (`cenkalti/backoff/v4`)
- Circuit breakers for HTTP calls (`sony/gobreaker`)
- Fail fast on critical errors (Postgres, NATS)
- Graceful degradation on non-critical deps (Unleash)

---

### 5. Middleware (`internal/middleware`)

**Chain Order (CRITICAL):**

```go
router.Use(
    middleware.Recovery(logger),    // 1. Panic recovery FIRST
    middleware.RequestID(),          // 2. Generate trace ID
    middleware.Tracing(tracer),      // 3. Start span
    middleware.Logging(logger),      // 4. Log request/response
    middleware.Metrics(meter),       // 5. Record metrics
)
```

**Logging Format:**

```json
{
  "time": "2025-12-13T10:30:00Z",
  "level": "INFO",
  "msg": "request completed",
  "method": "GET",
  "path": "/health/deep",
  "status": 200,
  "duration_ms": 234,
  "request_id": "3f8a9b2c-...",
  "trace_id": "4e7d6c5b-..."
}
```

---

### 6. Server (`internal/server`)

**Framework:** Gin (production mode)  
**Features:**

- Graceful shutdown with timeout
- Request timeout middleware
- CORS support (configurable)
- Rate limiting (future)

**Routes:**

```
GET  /health              → Shallow health check
GET  /health/deep         → Deep dependency check
GET  /ready               → Bootstrap readiness
GET  /metrics             → Prometheus metrics (OTEL exporter)
GET  /debug/pprof/*       → Go profiling (dev only)
```

---

### 7. Clients (`internal/clients`)

**NATS Client:**

```go
type NATSClient struct {
    conn *nats.Conn
    js   nats.JetStreamContext
}

func NewNATSClient(cfg *config.NATSConfig) (*NATSClient, error)
func (c *NATSClient) CreateStream(ctx context.Context, cfg *nats.StreamConfig) error
```

**Pulsar Client:**

```go
type PulsarClient struct {
    admin    *pulsaradmin.Client
    producer pulsar.Producer
}

func NewPulsarClient(cfg *config.PulsarConfig) (*PulsarClient, error)
func (c *PulsarClient) CreateTopic(ctx context.Context, topic string, partitions int) error
```

**Postgres Client:**

```go
type PostgresClient struct {
    pool *pgxpool.Pool
}

func NewPostgresClient(ctx context.Context, cfg *config.PostgresConfig) (*PostgresClient, error)
func (c *PostgresClient) ValidateSchema(ctx context.Context, schema string) error
```

---

## 📦 Tech Stack

### Core Libraries

| Purpose              | Library                       | Justification                          |
| -------------------- | ----------------------------- | -------------------------------------- |
| HTTP Framework       | `gin-gonic/gin`               | Fast, battle-tested, minimal overhead  |
| Config Management    | `spf13/viper`                 | A.R.C. standard, ENV + YAML support    |
| Validation           | `go-playground/validator/v10` | Struct validation with tags            |
| Logging              | `log/slog` (stdlib)           | Go 1.21+ standard, structured logging  |
| Observability        | OpenTelemetry SDK             | Vendor-neutral, OTEL Collector backend |
| NATS Client          | `nats-io/nats.go`             | Official Go client                     |
| Pulsar Client        | `apache/pulsar-client-go`     | Official Go client                     |
| Postgres Driver      | `jackc/pgx/v5`                | Fastest, most feature-rich             |
| Redis Client         | `redis/go-redis/v9`           | De facto standard                      |
| Retry/Backoff        | `cenkalti/backoff/v4`         | Exponential backoff for resilience     |
| Circuit Breaker      | `sony/gobreaker`              | Prevent cascade failures               |
| Graceful Orchestrate | `oklog/run`                   | Supervise goroutines with cancellation |

### Testing

| Purpose           | Library                            |
| ----------------- | ---------------------------------- |
| Assertions        | `stretchr/testify`                 |
| Mocking           | `stretchr/testify/mock`            |
| Integration Tests | `testcontainers/testcontainers-go` |

---

## 🚀 Performance & Resilience

### Startup Performance

- **Target:** <10s in healthy environment
- **Strategy:**
  - Parallel health checks (`errgroup`)
  - Fail-fast timeouts (5s per dependency)
  - Bootstrap tasks run concurrently where possible

### Resource Limits

- **Memory:** <50MB idle, <200MB under load
- **CPU:** <0.1 core idle, <0.5 core during bootstrap
- **Goroutines:** <100 (managed with semaphore)

### Resilience Patterns

1. **Exponential Backoff:** Retry failed probes with increasing delays
2. **Circuit Breakers:** Open circuit after 3 consecutive failures
3. **Timeouts:** Every external call has context deadline
4. **Graceful Degradation:** Non-critical deps don't block startup
5. **Panic Recovery:** All goroutines wrapped in recovery middleware

---

## 📊 Observability

### Logs (Structured)

```go
logger.Info("bootstrap phase started",
    "phase", "nats_initialization",
    "streams", len(streams),
    "attempt", retryCount,
)
```

### Traces (Distributed)

```go
ctx, span := tracer.Start(ctx, "bootstrap.nats.create_stream")
defer span.End()
span.SetAttributes(
    attribute.String("stream.name", streamName),
    attribute.Int("stream.replicas", replicas),
)
if err != nil {
    span.RecordError(err)
    span.SetStatus(codes.Error, "failed to create stream")
}
```

### Metrics (Prometheus)

| Metric Name                             | Type      | Description                          |
| --------------------------------------- | --------- | ------------------------------------ |
| `raymond.bootstrap.duration_seconds`    | Histogram | Total bootstrap time                 |
| `raymond.bootstrap.phase_duration`      | Histogram | Per-phase duration                   |
| `raymond.bootstrap.errors_total`        | Counter   | Bootstrap failures by phase          |
| `raymond.dependency.healthy`            | Gauge     | Dependency health (1=healthy, 0=not) |
| `raymond.http.requests_total`           | Counter   | HTTP requests by endpoint/status     |
| `raymond.http.request_duration_seconds` | Histogram | HTTP request latency                 |

---

## 🧪 Testing Strategy

### Unit Tests

- **Coverage Target:** >80%
- **Location:** `internal/*/`
- **Mocking:** Use interfaces for external dependencies
- **Example:**
  ```go
  func TestProbeTCP_Success(t *testing.T) {
      listener, _ := net.Listen("tcp", ":0")
      defer listener.Close()

      result := probeTCP(context.Background(), listener.Addr().String(), time.Second)
      assert.True(t, result.OK)
      assert.Less(t, result.LatencyMS, int64(1000))
  }
  ```

### Integration Tests

- **Framework:** Testcontainers
- **Location:** `tests/integration/`
- **Services:** Spin up real NATS, Postgres, Redis containers
- **Example:**
  ```go
  func TestBootstrap_NATS(t *testing.T) {
      ctx := context.Background()
      natsContainer, _ := testcontainers.GenericContainer(ctx, ...)
      defer natsContainer.Terminate(ctx)

      cfg := &config.Config{...}
      orchestrator := bootstrap.NewOrchestrator(cfg, logger)

      err := orchestrator.InitializeNATS(ctx)
      require.NoError(t, err)
  }
  ```

---

## 🔧 Development Workflow

### Makefile Targets

```makefile
make build          # Compile binary
make test           # Run unit tests
make test-int       # Run integration tests (requires Docker)
make lint           # golangci-lint
make fmt            # gofumpt formatting
make run            # Local dev server
make docker-build   # Build Docker image
make docker-run     # Run in Docker Compose
```

### Local Development

```bash
# 1. Start dependencies
make up-minimal   # Starts Postgres, Redis, NATS, etc.

# 2. Run Raymond locally
export POSTGRES_HOST=localhost
export NATS_URL=nats://localhost:4222
make run

# 3. Test endpoints
curl http://localhost:8081/health
curl http://localhost:8081/health/deep?mode=deep
```

---

## 🐳 Docker Build

### Multi-Stage Dockerfile

```dockerfile
# Stage 1: Build
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o raymond ./cmd/raymond

# Stage 2: Runtime
FROM alpine:latest
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /app/raymond /raymond
CMD ["/raymond"]
```

**Image Size:** <20MB (statically linked binary + alpine base)

---

## 📋 Configuration Example

### `config.yaml`

```yaml
server:
  port: 8081
  read_timeout: 10s
  write_timeout: 10s
  shutdown_timeout: 30s

telemetry:
  otlp_endpoint: 'arc-widow:4317'
  otlp_insecure: true
  service_name: 'arc-raymond-bootstrap'
  log_level: 'info'

bootstrap:
  timeout: 5m
  retry_attempts: 5
  retry_backoff: 2s

  dependencies:
    - name: 'arc-oracle-sql'
      type: 'tcp'
      address: 'arc-oracle:5432'
      critical: true

    - name: 'arc-flash-pulse'
      type: 'tcp'
      address: 'arc-flash:4222'
      critical: true

    - name: 'arc-strange-stream'
      type: 'http'
      url: 'http://arc-strange:8080/admin/v2/clusters'
      critical: true

  nats:
    url: 'nats://arc-flash:4222'
    streams:
      - name: 'AGENT_COMMANDS'
        subjects: ['agent.*.cmd']
        retention: 'limits'
        max_age: 24h

      - name: 'AGENT_EVENTS'
        subjects: ['agent.*.event']
        retention: 'interest'
        max_age: 168h

  pulsar:
    admin_url: 'http://arc-strange:8080'
    tenant: 'arc'
    namespaces:
      - 'events'
      - 'logs'
      - 'audit'
    topics:
      - name: 'persistent://arc/events/agent-lifecycle'
        partitions: 3
      - name: 'persistent://arc/audit/command-log'
        partitions: 1
```

---

## 🚦 Deployment

### Docker Compose Integration

```yaml
arc-raymond:
  build:
    context: ./services/utilities/raymond
  container_name: arc-raymond-bootstrap
  depends_on:
    arc-oracle:
      condition: service_healthy
    arc-sonic:
      condition: service_healthy
    arc-flash:
      condition: service_healthy
    arc-strange:
      condition: service_started
  healthcheck:
    test: ['CMD', 'wget', '--spider', 'http://localhost:8081/ready']
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 60s # Allow time for bootstrap
```

### Kubernetes Readiness

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8081
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

---

## 🔒 Security Considerations

1. **No secrets in config files:** Use Infisical/environment variables
2. **Least privilege:** Connect with read-only credentials where possible
3. **TLS support:** Add `--tls-cert` and `--tls-key` flags for production
4. **Rate limiting:** Prevent abuse of deep health endpoint
5. **Input validation:** Validate all config struct fields
6. **Dependency scanning:** `gosec` in golangci-lint

---

## 📚 References

- [A.R.C. Framework Documentation](../../docs/)
- [A.R.C. Naming Conventions](../../docs/guides/NAMING-CONVENTIONS.md)
- [Service Codename Matrix](../../../arc-platform/SERVICE.MD)
- [OpenTelemetry Go SDK](https://opentelemetry.io/docs/languages/go/)
- [NATS JetStream](https://docs.nats.io/nats-concepts/jetstream)
- [Apache Pulsar](https://pulsar.apache.org/docs/)

---

## 🎯 Future Enhancements

1. **gRPC API:** Add gRPC server alongside HTTP for inter-service communication
2. **Metrics Export:** Native Prometheus exporter (in addition to OTLP)
3. **CLI Mode:** Run bootstrap tasks as one-shot command (`raymond bootstrap`)
4. **Config Validation API:** `POST /validate` to test config before deployment
5. **Chaos Testing:** Integration with `arc-terminator-chaos` for resilience validation
6. **Multi-cluster Support:** Bootstrap multiple A.R.C. environments

---

**Version:** 1.0.0  
**Last Updated:** 2025-12-13  
**Author:** A.R.C. Architect  
**Status:** 🚧 In Development
