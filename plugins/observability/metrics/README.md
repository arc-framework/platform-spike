# Metrics
Metrics storage and querying backends.
---
## Overview
Metrics storage plugins receive metrics from the OpenTelemetry Collector and provide time-series database capabilities.
---
## Active Implementation
### [Prometheus](./prometheus/)
**Status:** ✅ Active  
**Type:** Time-series database
- PromQL query language
- Pull-based scraping model
- Native Grafana integration
- CNCF graduated project
---
## Alternatives
- **InfluxDB** - Time-series optimized
- **Victoria Metrics** - Prometheus-compatible, faster
- **Datadog** - SaaS platform
- **Thanos** - Prometheus with long-term storage
---
## See Also
- [Observability](../)
- [Core Telemetry](../../../core/telemetry/)
