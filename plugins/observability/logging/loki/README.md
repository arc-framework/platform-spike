# Loki - Log Aggregation

Log aggregation system optimized for Kubernetes and cloud-native applications.

---

## Overview

**Loki** provides:
- Cost-effective log storage
- Label-based indexing (like Prometheus)
- Integration with Grafana
- LogQL query language
- High compression
- Multi-tenancy support

---

## Ports

- **3100** - HTTP API and query interface

---

## Configuration

See `.env.example` for configuration options.

### Key Features
- **Cost-Effective** - Only indexes labels, not full text
- **LogQL** - Powerful query language similar to PromQL
- **Grafana Integration** - Native datasource in Grafana
- **Compression** - Excellent compression ratios
- **Scalable** - Horizontally scalable architecture

---

## Architecture

```
Services → OpenTelemetry Collector → Loki → Grafana
```

Loki receives logs from:
- OpenTelemetry Collector (OTLP HTTP)
- Promtail (log shipper)
- Docker plugin
- Direct HTTP API

---

## Usage

### Start Service
```bash
make up-observability
# or
docker compose up loki
```

### Check Health
```bash
curl http://localhost:3100/ready
```

### Query Logs
```bash
# Via API
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={service_name="swiss-army-go"}'

# Via Grafana (recommended)
open http://localhost:3000/explore
```

---

## LogQL Query Examples

### Basic Queries
```logql
# All logs from a service
{service_name="swiss-army-go"}

# Logs with specific level
{service_name="swiss-army-go"} |= "level=error"

# Logs matching regex
{service_name="swiss-army-go"} |~ "error|exception"

# Logs NOT containing text
{service_name="swiss-army-go"} != "healthcheck"
```

### JSON Parsing
```logql
# Parse JSON and filter
{service_name="swiss-army-go"} | json | user_id="123"

# Extract field and aggregate
sum by (status_code) (
  rate({service_name="api"} | json [5m])
)
```

### Metrics from Logs
```logql
# Count logs per minute
count_over_time({service_name="swiss-army-go"}[1m])

# Error rate
sum(rate({service_name="swiss-army-go"} |= "level=error" [5m]))

# Average response time from JSON logs
avg_over_time(
  {service_name="api"} | json | unwrap duration [5m]
)
```

### Trace Correlation
```logql
# Find logs for specific trace
{service_name="swiss-army-go"} | json | trace_id="abc123"
```

---

## Labels

### Recommended Labels
```
service_name    - Service identifier
level          - Log level (info, warn, error)
environment    - Environment (dev, staging, prod)
```

### Label Best Practices
- **Low Cardinality** - Limit unique label values
- **Don't Over-Label** - Too many labels hurt performance
- **Use Filters** - Parse content with LogQL, don't label everything

### Bad Examples ❌
```
user_id="123"           # High cardinality
request_id="abc-def"    # High cardinality
timestamp="..."         # Already tracked
```

### Good Examples ✅
```
service_name="api"
level="error"
environment="production"
```

---

## Storage & Retention

### Configuration
```yaml
# In loki config
limits_config:
  retention_period: 744h  # 31 days

compactor:
  retention_enabled: true
  retention_delete_delay: 2h
```

### Disk Usage
```bash
# Check storage size
du -sh /var/lib/loki

# Clean old chunks
docker compose exec loki rm -rf /loki/chunks/fake/*
```

---

## Integration with OpenTelemetry

### Collector Configuration
```yaml
exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    labels:
      attributes:
        service.name: "service_name"
        severity: "level"
```

---

## Grafana Integration

Loki is auto-provisioned as a datasource in Grafana.

### Access in Grafana
1. Open http://localhost:3000
2. Go to Explore
3. Select "Loki" datasource
4. Enter LogQL query

### Example Dashboard Queries
```logql
# Error rate panel
sum(rate({service_name="api"} |= "level=error" [5m]))

# Log volume by service
sum by (service_name) (count_over_time({job="docker"}[1m]))

# Top error messages
topk(10, 
  sum by (message) (count_over_time({level="error"}[1h]))
)
```

---

## Performance Tuning

### Optimize Queries
```logql
# ✅ Good - Uses labels
{service_name="api", level="error"}

# ❌ Bad - Full text search
{job="docker"} |= "error"

# ✅ Better - Label + filter
{service_name="api"} |= "error"
```

### Query Limits
```yaml
limits_config:
  max_query_length: 721h       # Max time range
  max_query_lookback: 30d      # Lookback limit
  max_entries_limit_per_query: 5000
```

---

## Monitoring

### Key Metrics
- Ingestion rate (lines/second)
- Query latency
- Storage size
- Failed requests

### Loki Metrics
```bash
# Scrape Loki metrics with Prometheus
curl http://localhost:3100/metrics
```

---

## Production Notes

1. **Object Storage** - Use S3/GCS for chunk storage
2. **Compactor** - Enable compaction for retention
3. **Resource Limits** - Set memory and CPU limits
4. **Query Limits** - Prevent expensive queries
5. **Label Cardinality** - Monitor and control
6. **Multi-Tenancy** - Use tenant IDs for isolation
7. **Backup** - Regular backups of index and chunks

---

## Alternatives

If Loki doesn't fit your needs:
- **Elasticsearch** - Full-text search, resource-intensive
- **Splunk** - Enterprise features, expensive
- **CloudWatch Logs** - AWS-native
- **Datadog** - SaaS, full observability platform

---

## See Also

- [Plugin Services](../../../README.md)
- [Core Telemetry](../../../../core/telemetry/)
- [Grafana](../../visualization/grafana/)
- [Loki Documentation](https://grafana.com/docs/loki/)

