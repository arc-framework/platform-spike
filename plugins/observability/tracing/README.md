# Tracing
Distributed tracing storage and visualization backends.
---
## Overview
Tracing storage plugins receive traces from the OpenTelemetry Collector and provide trace visualization and analysis.
---
## Active Implementation
### [Jaeger](./jaeger/)
**Status:** ✅ Active  
**Type:** Distributed tracing platform
- OTLP native support
- Service dependency graphs
- Trace search and filtering
- Performance analysis
---
## Alternatives
- **Zipkin** - Simpler, less features
- **Grafana Tempo** - Designed for high volume
- **Lightstep** - SaaS, advanced analysis
- **Honeycomb** - SaaS, observability platform
---
## See Also
- [Observability](../)
- [Core Telemetry](../../../core/telemetry/)
