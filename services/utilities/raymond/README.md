# Raymond - A.R.C. Platform Bootstrap Service

**Codename:** `arc-raymond` (The Utility Runner)  
**Role:** Platform initialization, dependency orchestration, and bootstrap utilities  
**Tech Stack:** Go 1.21+, OpenTelemetry, PostgreSQL, Redis, NATS, Pulsar

---

## 🎯 Overview

Raymond is the **platform bootstrap orchestrator** for the A.R.C. Framework. It handles:

- ✅ **Asynchronous dependency health monitoring**
- ✅ **Non-blocking service initialization** (resilient startup)
- ✅ **NATS JetStream stream provisioning**
- ✅ **Apache Pulsar topic/subscription setup**
- ✅ **Database schema validation**
- ✅ **Cache warming operations**
- ✅ **Full OpenTelemetry observability** (traces, metrics, logs)
- ✅ **Circuit breaker protection** for all external dependencies

---

## 🏗️ Architecture

### Design Principles

1. **Fail-Safe, Not Fail-Fast**: Service starts even if dependencies are unavailable
2. **Async by Default**: All initialization happens in background goroutines
3. **Self-Healing**: Automatic retry with exponential backoff for failed operations
4. **Observable**: Every operation is traced, metered, and logged
5. **Enterprise-Grade**: Production-ready error handling, circuit breakers, timeouts

### Key Components

```
raymond/
├── cmd/raymond/          # Main entry point
├── internal/
│   ├── bootstrap/        # Orchestration logic (async phases)
│   ├── clients/          # Database, cache, messaging clients (with circuit breakers)
│   ├── config/           # Viper-based configuration
│   ├── health/           # Dependency health checks (concurrent probes)
│   ├── server/           # HTTP server (health endpoints, metrics)
│   └── telemetry/        # OpenTelemetry provider (traces + metrics)
├── pkg/
│   └── errors/           # Custom error types
└── tests/                # Integration tests
```

---

## 🚀 Quick Start

### Prerequisites

- Go 1.21+ (for local development)
- Docker & Docker Compose (for containerized deployment)
- A.R.C. platform core services running (Traefik, Postgres, Redis, NATS, Pulsar, OTEL Collector)

### Local Development

```bash
# 1. Navigate to raymond directory
cd services/utilities/raymond

# 2. Install dependencies
go mod download

# 3. Build
go build -o bin/raymond ./cmd/raymond

# 4. Run (requires .env or config file)
./bin/raymond --config config.example.yaml
```

### Docker Deployment

```bash
# From repository root
make up-core-services  # Starts core + raymond
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `localhost:4317` | OpenTelemetry collector endpoint |
| `OTEL_EXPORTER_OTLP_INSECURE` | `true` | Use insecure gRPC connection |
| `OTEL_SERVICE_NAME` | `raymond` | Service name for telemetry |
| `SERVICE_PORT` | `8081` | HTTP server port |
| `LOG_LEVEL` | `info` | Log level (debug, info, warn, error) |

### Configuration File (config.yaml)

```yaml
server:
  port: 8081
  shutdown_timeout: 30s

telemetry:
  otlp_endpoint: "arc-widow:4317"
  otlp_insecure: true
  service_name: "arc-raymond-bootstrap"
  log_level: "info"

bootstrap:
  timeout: 5m
  
  dependencies:
    - name: "postgres"
      type: "tcp"
      address: "arc-oracle:5432"
      critical: true
      timeout: 5s
    
    - name: "redis"
      type: "tcp"
      address: "arc-sonic:6379"
      critical: true
      timeout: 5s
    
    - name: "nats"
      type: "http"
      address: "http://arc-flash:8222/healthz"
      critical: true
      timeout: 5s
    
    - name: "pulsar"
      type: "tcp"
      address: "arc-strange:6650"
      critical: false
      timeout: 5s
  
  postgres:
    url: "postgres://arc:password@arc-oracle:5432/arc_db?sslmode=disable"
    max_connections: 25
    connection_timeout: 10s
  
  redis:
    url: "redis://arc-sonic:6379/0"
    pool_size: 10
    dial_timeout: 5s
  
  nats:
    url: "nats://arc-flash:4222"
    max_reconnects: 5
    reconnect_wait: 2s
    
    streams:
      - name: "platform_events"
        subjects: ["platform.>"]
        retention: "limits"
        max_age: "24h"
        storage: "file"
      
      - name: "agent_tasks"
        subjects: ["agent.tasks.>"]
        retention: "workqueue"
        max_age: "1h"
        storage: "file"
  
  pulsar:
    url: "pulsar://arc-strange:6650"
    operation_timeout: 30s
    connection_timeout: 10s
    
    topics:
      - name: "persistent://arc/platform/events"
        partitions: 4
      
      - name: "persistent://arc/agents/commands"
        partitions: 2
```

---

## 🔧 API Endpoints

### Health Endpoints

```bash
# Liveness probe (always returns 200 if service is running)
GET http://localhost:8081/health/live

# Readiness probe (returns 200 when bootstrap complete)
GET http://localhost:8081/health/ready

# Combined health check
GET http://localhost:8081/health
```

### Metrics Endpoint

```bash
# Prometheus metrics
GET http://localhost:8081/metrics
```

**Key Metrics:**

- `raymond_bootstrap_duration_seconds` - Total bootstrap time
- `raymond_bootstrap_phase_duration_seconds{phase}` - Per-phase duration
- `raymond_bootstrap_errors_total{phase}` - Bootstrap errors by phase
- `raymond_dependency_healthy{service}` - Dependency health status (1=healthy, 0=unhealthy)
- `raymond_http_requests_total{method,path,status}` - HTTP request counts
- `raymond_http_request_duration_seconds{method,path}` - HTTP request latency

---

## 🧪 Testing

### Unit Tests

```bash
go test ./internal/...
```

### Integration Tests

```bash
# Requires running infrastructure
go test ./tests/integration/...
```

### Manual Testing

```bash
# Check service health
curl http://localhost:8081/health

# Check dependency status
curl http://localhost:8081/health/ready

# View metrics
curl http://localhost:8081/metrics
```

---

## 🔍 Observability

### Logs

Raymond outputs **structured JSON logs** to stdout, which are automatically collected by the OTEL collector:

```json
{
  "time": "2025-12-13T16:54:01.526927305Z",
  "level": "INFO",
  "msg": "starting HTTP server",
  "service.name": "arc-raymond-bootstrap",
  "service.version": "1.0.0",
  "service.namespace": "arc",
  "port": 8081
}
```

**View logs:**

```bash
# Via Docker
docker logs arc-raymond-services -f

# Via Makefile
make logs-services

# Via Grafana Loki
# Access: http://localhost:3000 → Explore → Loki
# Query: {service_name="arc-raymond-bootstrap"}
```

### Traces

All bootstrap operations are traced via OpenTelemetry:

**View traces:**

1. Open Jaeger UI: http://localhost:16686
2. Select service: `arc-raymond-bootstrap`
3. Search for traces

**Example trace spans:**

- `bootstrap.run` - Overall bootstrap operation
- `bootstrap.create_nats_stream` - NATS stream creation
- `bootstrap.create_pulsar_topic` - Pulsar topic creation
- `bootstrap.validate_database` - Database validation

### Metrics

Prometheus metrics are exposed at `/metrics` and scraped automatically:

**View metrics:**

1. Open Grafana: http://localhost:3000
2. Navigate to Dashboards → Raymond Bootstrap
3. Or use Prometheus directly: http://localhost:9090

---

## 🛡️ Resilience Features

### 1. Async Startup (Non-Blocking)

Raymond starts immediately and marks itself as `ready`, even if dependencies aren't available:

```go
// Service is marked ready immediately
healthHandler.SetReady(true)

// Bootstrap runs in background
go orchestrator.Run(ctx)
```

### 2. Automatic Retry with Exponential Backoff

All initialization phases retry automatically:

```go
backoffStrategy := backoff.NewExponentialBackOff()
backoffStrategy.InitialInterval = 2 * time.Second
backoffStrategy.MaxInterval = 30 * time.Second
backoffStrategy.MaxElapsedTime = 5 * time.Minute
```

### 3. Circuit Breakers on All Clients

Prevents cascade failures:

```go
client := &NATSClient{
    breaker: gobreaker.NewCircuitBreaker(gobreaker.Settings{
        Name:        "nats-client",
        MaxRequests: 3,
        Interval:    10 * time.Second,
        Timeout:     60 * time.Second,
    }),
}
```

### 4. Background Dependency Monitoring

Continuous health checks every 30 seconds:

```go
ticker := time.NewTicker(30 * time.Second)
for {
    results := checker.RunAll(ctx)
    logHealthSummary(results)
}
```

---

## 🐛 Troubleshooting

### Service Won't Start

**Check logs:**
```bash
docker logs arc-raymond-services --tail 100
```

**Common issues:**

1. **OTEL Collector not available**  
   → Service will start anyway, logs will show warnings  
   → Fix: Ensure `arc-widow-otel` is running

2. **Database connection failed**  
   → Service will retry automatically  
   → Check: `docker exec arc-oracle-sql pg_isready`

3. **Port 8081 already in use**  
   → Change `SERVICE_PORT` environment variable

### Bootstrap Phase Failures

Check which phase failed:

```bash
# View metrics
curl http://localhost:8081/metrics | grep raymond_bootstrap_errors

# Example output:
# raymond_bootstrap_errors_total{phase="initialize_nats"} 3
```

**Phase-specific troubleshooting:**

- `wait_dependencies`: Check dependency health with `make health-core`
- `initialize_nats`: Verify NATS is running: `curl http://localhost:8222/healthz`
- `initialize_pulsar`: Check Pulsar: `docker exec arc-strange bin/pulsar-admin brokers healthcheck`
- `validate_database`: Check Postgres connection

### High Memory Usage

Raymond is lightweight (~50MB RAM), but if memory is high:

1. Check for goroutine leaks: `curl http://localhost:8081/debug/pprof/goroutine`
2. Review circuit breaker settings (may be retrying too aggressively)
3. Check OTEL exporter backpressure

---

## 📊 Performance Characteristics

- **Startup Time:** < 1 second (async mode)
- **Memory Footprint:** ~50MB (idle), ~100MB (under load)
- **CPU Usage:** < 1% (idle), ~5% (bootstrap operations)
- **Health Check Latency:** < 10ms
- **Bootstrap Phase Retry:** Max 5 minutes per phase

---

## 🔐 Security

- **No secrets in code** - All sensitive config via environment variables
- **TLS support** - Can use secure connections to all dependencies
- **Least privilege** - Runs as non-root user in Docker
- **Network isolation** - Only communicates via `arc_net` network

---

## 🚦 Production Deployment

### Recommended Resource Limits

```yaml
resources:
  limits:
    cpus: '1.0'
    memory: 512M
  reservations:
    cpus: '0.1'
    memory: 128M
```

### Health Check Configuration

```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8081/health"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 10s
```

### Scaling Considerations

- **Horizontal scaling**: Not recommended (singleton service)
- **Vertical scaling**: Increase memory if handling many Pulsar topics
- **High availability**: Use Docker restart policies

---

## 🤝 Contributing

See [ARCHITECTURE.md](./ARCHITECTURE.md) for design details.

### Development Workflow

1. Make changes
2. Run tests: `go test ./...`
3. Build: `go build -o bin/raymond ./cmd/raymond`
4. Lint: `golangci-lint run`
5. Format: `gofumpt -w .`

---

## 📝 License

Part of the A.R.C. Framework Platform - See repository LICENSE

---

## 📞 Support

- **Documentation**: `docs/OPERATIONS.md`
- **Architecture**: `docs/architecture/README.md`
- **Issues**: GitHub Issues (when published)

---

**Built with ❤️ by the A.R.C. Architect**  
_"Because your platform deserves a butler who doesn't panic when the lights go out."_

