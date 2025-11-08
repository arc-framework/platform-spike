# Service Configurations

Configuration files for all platform services, organized by purpose.

## Structure

- **otel-collector-config.yml** - OpenTelemetry Collector configuration (root level)

### observability/
Observability stack configurations:
- grafana/ - Grafana dashboard and datasources
- loki/ - Log aggregation configuration
- prometheus/ - Metrics scraping and storage
- jaeger/ - Distributed tracing
- otel-collector/ - Collector build and health check

### platform/
Platform service configurations:
- postgres/ - Database initialization and config
- redis/ - Cache configuration
- nats/ - Message broker
- pulsar/ - Event streaming
- kratos/ - Identity and authentication
- unleash/ - Feature flags
- infisical/ - Secrets management
- traefik/ - API gateway and reverse proxy

## Environment Files

Each service has a `.env.example` file. Copy to `.env` for local customization.

```bash
# Example
cp config/platform/postgres/.env.example config/platform/postgres/.env
```

## Usage with Docker Compose

Paths are referenced from project root:
```yaml
volumes:
  - ./config/observability/grafana/provisioning:/etc/grafana/provisioning
  - ./config/platform/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
```

