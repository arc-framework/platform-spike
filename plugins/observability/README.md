# Observability
Monitoring, logging, and tracing backends for the A.R.C. Framework.
---
## Overview
Observability plugins provide backends for storing and visualizing telemetry data collected by the OpenTelemetry Collector.
**Note:** These are **plugins** - the framework works without them, and they can be swapped with alternatives.
---
## Categories
### [Logging](./logging/)
Log storage and querying backends
- **Active:** [Loki](./logging/loki/)
- **Alternatives:** Elasticsearch, Splunk, CloudWatch
### [Metrics](./metrics/)
Metrics storage and querying backends
- **Active:** [Prometheus](./metrics/prometheus/)
- **Alternatives:** InfluxDB, Datadog, Victoria Metrics
### [Tracing](./tracing/)
Distributed tracing storage and visualization
- **Active:** [Jaeger](./tracing/jaeger/)
- **Alternatives:** Zipkin, Tempo, Lightstep
### [Visualization](./visualization/)
Dashboards and unified visualization
- **Active:** [Grafana](./visualization/grafana/)
- **Alternatives:** Kibana, Datadog dashboards
---
## Architecture
```
Services → OpenTelemetry Collector → Observability Backends
                                           ↓
                                       Grafana
```
---
## See Also
- [Plugin Services](../README.md)
- [Core Telemetry](../../core/telemetry/)
- [Operations Guide](../../docs/OPERATIONS.md)
