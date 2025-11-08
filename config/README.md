# Configuration Files

**Note**: Configuration files have been moved to their respective component directories.

---

## New Structure

Configuration files are now co-located with their components:

### Core Services
- `core/gateway/traefik/` - Traefik configuration
- `core/telemetry/otel-collector/` - OpenTelemetry Collector configuration
- `core/messaging/ephemeral/nats/` - NATS configuration
- `core/messaging/durable/pulsar/` - Pulsar configuration
- `core/persistence/postgres/` - Postgres configuration
- `core/caching/redis/` - Redis configuration
- `core/secrets/infisical/` - Infisical configuration
- `core/feature-management/unleash/` - Unleash configuration

### Plugin Services
- `plugins/security/identity/kratos/` - Kratos configuration
- `plugins/observability/logging/loki/` - Loki configuration
- `plugins/observability/metrics/prometheus/` - Prometheus configuration
- `plugins/observability/tracing/jaeger/` - Jaeger configuration
- `plugins/observability/visualization/grafana/` - Grafana configuration

---

## Migration Note

This directory now serves as a reference only. All actual configuration has been moved to follow the official naming conventions documented in `docs/guides/NAMING-CONVENTIONS.md`.

### Why the Change?

1. **Co-location** - Config with component (easier to find)
2. **Clear ownership** - Component owns its config
3. **Better organization** - Follows core/plugins architecture
4. **Standard pattern** - Matches industry best practices

---

## See Also

- [Core Services](../core/) - Core component configurations
- [Plugins](../plugins/) - Plugin component configurations
- [Naming Conventions](../docs/guides/NAMING-CONVENTIONS.md) - Official standards

