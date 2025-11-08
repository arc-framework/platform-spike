# Logging
Log aggregation and storage backends.
---
## Overview
Log storage plugins receive logs from the OpenTelemetry Collector and provide querying interfaces.
---
## Active Implementation
### [Loki](./loki/)
**Status:** ✅ Active  
**Type:** Cost-effective log aggregation
- Label-based indexing
- LogQL query language
- Native Grafana integration
- Optimized for Kubernetes
---
## Alternatives
- **Elasticsearch** - Full-text search, resource-intensive
- **Splunk** - Enterprise features, expensive
- **CloudWatch Logs** - AWS-native
- **Datadog** - SaaS platform
---
## See Also
- [Observability](../)
- [Core Telemetry](../../../core/telemetry/)
