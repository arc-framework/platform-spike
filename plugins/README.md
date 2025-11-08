# Plugins

Optional components that extend the A.R.C. Framework. These can be added or removed based on needs.

---

## Overview

Plugins provide additional functionality that isn't core to the framework. They can be completely removed or swapped with alternatives without breaking the framework.

---

## Plugin Categories

### [Security](./security/)
Security and identity management

#### [Identity](./security/identity/)
Authentication and user management (optional)
- **Options**: Kratos, Keycloak, Auth0, Cognito
- **Purpose**: User authentication, identity provider
- **Note**: Framework works without this for agent-to-agent scenarios

### [Observability](./observability/)
Monitoring and observability backends

#### [Logging](./observability/logging/)
Log storage and querying
- **Options**: Loki, Elasticsearch, Splunk
- **Purpose**: Store and search logs from OTel Collector

#### [Metrics](./observability/metrics/)
Metrics storage and querying
- **Options**: Prometheus, InfluxDB, Datadog
- **Purpose**: Store and query metrics from OTel Collector

#### [Tracing](./observability/tracing/)
Distributed tracing storage
- **Options**: Jaeger, Zipkin, Tempo
- **Purpose**: Store and visualize traces from OTel Collector

#### [Visualization](./observability/visualization/)
Dashboards and visualization
- **Options**: Grafana, Kibana
- **Purpose**: Unified dashboards for metrics, logs, traces

### [Storage](./storage/)
Object storage for artifacts
- **Options**: MinIO, S3, GCS, Azure Blob
- **Purpose**: Store agent artifacts, documents, generated files

### [Search](./search/)
Full-text search engines
- **Options**: Elasticsearch, OpenSearch, Meilisearch, Typesense
- **Purpose**: Search agent conversations, documents

---

## Architecture Pattern

```
Pattern: category/[subcategory]/implementation/

Example:
plugins/
├── observability/
│   ├── logging/
│   │   └── loki/           # Implementation
│   ├── metrics/
│   │   └── prometheus/     # Implementation
```

---

## Core vs Plugin Decision

A component is a **plugin** if:
- ✅ Framework works without it
- ✅ Multiple alternatives exist
- ✅ Can be swapped at runtime
- ✅ Only some deployments need it

A component is **core** if:
- ❌ Framework breaks without it
- ❌ No reasonable alternative
- ❌ Required by most services
- ❌ Deeply integrated

---

## Deployment Profiles

### Minimal (No Plugins)
```bash
# Core services only
make up profile=minimal
```
- OTel Collector
- Traefik
- NATS
- Pulsar
- Postgres
- Redis
- Infisical

### Observability (With Monitoring)
```bash
# Core + observability plugins
make up profile=observability
```
- All minimal services
- Loki (logging)
- Prometheus (metrics)
- Jaeger (tracing)
- Grafana (visualization)

### Full Stack (Everything)
```bash
# All services including optional plugins
make up profile=full-stack
```
- All observability services
- Kratos (if needed)
- MinIO (storage)
- Elasticsearch (search)

---

## See Also

- [Core Services](../core/) - Required components
- [Services](../services/) - Application services
- [Architecture Documentation](../docs/architecture/)

