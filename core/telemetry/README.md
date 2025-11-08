# OpenTelemetry Collector

Unified telemetry collection hub for the A.R.C. Framework.

---

## Overview

The **OpenTelemetry Collector** serves as the central telemetry pipeline, receiving logs, metrics, and traces from all services and distributing them to backend systems.

---

## Ports

- **4317** - OTLP gRPC receiver
- **4318** - OTLP HTTP receiver
- **13133** - Health check endpoint

---

## Configuration

**Primary Config:** `otel-collector-config.yml`

### Pipeline Architecture

```
Applications
    ↓
OTLP Receivers (gRPC/HTTP)
    ↓
Processors (batch, spanmetrics, attributes)
    ↓
Exporters (Loki, Prometheus, Jaeger)
```

### Key Features
- **Trace-Log Correlation** - Adds trace context to logs
- **Span Metrics** - Generates RED metrics from traces
- **Batching** - Optimizes export performance
- **Multi-backend** - Exports to Loki, Prometheus, Jaeger

---

## Custom Build

This service uses a custom Docker image with health check support:

**Dockerfile Location:** `Dockerfile` (in this directory)

**Build:**
```bash
docker build -t arc/otel-collector:latest ./core/telemetry/otel-collector
```

---

## Environment Variables

See `.env.example` for configuration options.

---

## Usage

### Start Service
```bash
make up-observability
# or
docker compose up otel-collector
```

### Check Health
```bash
curl http://localhost:13133/
```

### View Configuration
```bash
docker compose exec otel-collector cat /etc/otel-collector-config.yaml
```

---

## Instrumentation

Services send telemetry to the collector:

```yaml
# Example: Go application
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

---

## Monitoring

The collector itself is monitored:
- Health endpoint: http://localhost:13133
- Prometheus metrics: Available when configured
- Logs: Standard output

---

## Troubleshooting

### No Data Received
1. Check application instrumentation
2. Verify network connectivity
3. Check collector logs: `make logs service=otel-collector`

### High Memory Usage
1. Adjust batch processor settings in config
2. Reduce retention in backends
3. Add resource limits in docker-compose

---

## See Also

- [Core Services](../../README.md)
- [Operations Guide](../../../docs/OPERATIONS.md)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/collector/)
# Traefik - API Gateway

API Gateway and reverse proxy for the A.R.C. Framework.

---

## Overview

**Traefik** provides:
- Automatic service discovery
- Dynamic routing
- Load balancing
- SSL/TLS termination
- Access to multiple backend services through a single entry point

---

## Ports

- **80** - HTTP traffic
- **443** - HTTPS traffic (when SSL configured)
- **8080** - Dashboard/API (development only)

---

## Configuration

**Primary Config:** `traefik.yml`

### Key Features
- Docker provider for automatic service discovery
- Health checks enabled
- Access logs for observability
- Dashboard for monitoring routes

### Dashboard Access
```bash
# Development
open http://localhost:8080/dashboard/
```

---

## Environment Variables

See `.env.example` for configuration options.

**Key Variables:**
```bash
TRAEFIK_LOG_LEVEL=INFO
TRAEFIK_DASHBOARD_ENABLED=true  # Disable in production
```

---

## Usage

### Start Service
```bash
make up-stack
# or
docker compose -f docker-compose.yml -f docker-compose.stack.yml up traefik
```

### Check Health
```bash
make health-traefik
# or
curl http://localhost:8080/ping
```

---

## Routing

Services are auto-discovered via Docker labels. Example:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myservice.rule=Host(`myservice.local`)"
  - "traefik.http.services.myservice.loadbalancer.server.port=8080"
```

---

## Production Notes

1. **Disable Dashboard** - Set `TRAEFIK_DASHBOARD_ENABLED=false`
2. **Enable SSL** - Configure Let's Encrypt or provide certificates
3. **Restrict Access** - Use middleware for authentication
4. **Monitor Metrics** - Export to Prometheus

---

## See Also

- [Core Services](../../README.md)
- [Operations Guide](../../../docs/OPERATIONS.md)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

