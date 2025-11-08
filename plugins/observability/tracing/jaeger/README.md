# Jaeger - Distributed Tracing

Distributed tracing platform for monitoring microservices and troubleshooting performance.

---

## Overview

**Jaeger** provides:
- Distributed trace collection
- Trace visualization and analysis
- Service dependency graphs
- Performance monitoring
- Root cause analysis

---

## Ports

- **16686** - Web UI
- **14268** - HTTP collector (Jaeger native)
- **14250** - gRPC collector
- **4317/4318** - OTLP (via collector)

---

## Configuration

Jaeger receives traces from the OpenTelemetry Collector.

### Key Features
- **Trace Search** - Find traces by service, operation, tags
- **Service Map** - Visualize service dependencies
- **Span Details** - Drill down into trace spans
- **Performance Analysis** - Identify bottlenecks

---

## Architecture

```
Services → OpenTelemetry Collector → Jaeger
                                        ↓
                                   Visualization UI
```

---

## Usage

### Start Service
```bash
make up-observability
# or
docker compose up jaeger
```

### Access Web UI
```bash
open http://localhost:16686
```

### Check Health
```bash
curl http://localhost:14269/
```

---

## Using the UI

### Search for Traces
1. Open http://localhost:16686
2. Select service from dropdown
3. Choose operation (optional)
4. Set time range
5. Click "Find Traces"

### Analyze a Trace
1. Click on a trace in search results
2. View span timeline
3. Examine span details and tags
4. Check logs attached to spans

### Service Dependencies
1. Go to "System Architecture" tab
2. View service dependency graph
3. See request flow between services

---

## Trace Features

### Trace Structure
```
Trace
└─ Root Span (e.g., HTTP request)
   ├─ Child Span (e.g., database query)
   ├─ Child Span (e.g., external API call)
   │  └─ Nested Span (e.g., auth check)
   └─ Child Span (e.g., cache lookup)
```

### Span Attributes
- **Operation name** - What the span represents
- **Duration** - How long it took
- **Tags** - Key-value metadata
- **Logs** - Events that happened during span
- **Trace ID** - Links all spans in a trace

---

## Common Analysis Patterns

### Find Slow Requests
1. Search with min duration filter
2. Look for spans with long duration
3. Identify bottlenecks in trace timeline

### Debug Errors
1. Search for error tags
2. Examine error span details
3. Check logs attached to error span
4. Trace error propagation

### Compare Performance
1. Search for same operation
2. Compare trace durations
3. Identify differences in span patterns

---

## Integration with Logs

### Trace-Log Correlation
When logs include trace IDs, you can:
1. Find trace in Jaeger
2. Copy trace ID
3. Search logs in Loki/Grafana by trace_id
4. See logs in context of trace

Example log query:
```logql
{service_name="api"} | json | trace_id="abc123..."
```

---

## Sampling

### Sampling Strategies
Jaeger supports different sampling strategies:

**Always Sample** (Development)
```yaml
# All traces captured
sampler:
  type: const
  param: 1
```

**Probabilistic** (Production)
```yaml
# 1% of traces captured
sampler:
  type: probabilistic
  param: 0.01
```

**Rate Limiting**
```yaml
# Max traces per second
sampler:
  type: ratelimiting
  param: 10
```

---

## Storage

### In-Memory (Default)
- Fast, ephemeral
- Lost on restart
- Good for development

### Elasticsearch (Production)
```yaml
services:
  jaeger:
    environment:
      - SPAN_STORAGE_TYPE=elasticsearch
      - ES_SERVER_URLS=http://elasticsearch:9200
```

### Cassandra (Production)
```yaml
services:
  jaeger:
    environment:
      - SPAN_STORAGE_TYPE=cassandra
      - CASSANDRA_SERVERS=cassandra:9042
```

---

## Performance Analysis

### Identify Bottlenecks
1. Look for long-duration spans
2. Check span relationships
3. Find sequential vs parallel execution
4. Optimize critical path

### Service Dependencies
1. View service map
2. Identify chattiness (many calls)
3. Find circular dependencies
4. Optimize service communication

---

## Monitoring Jaeger

### Metrics
Jaeger exposes Prometheus metrics:

```bash
curl http://localhost:14269/metrics
```

### Key Metrics
- Spans received/sec
- Traces received/sec
- Storage latency
- Query latency

---

## Production Notes

1. **Persistent Storage** - Use Elasticsearch or Cassandra
2. **Sampling** - Use probabilistic sampling (1-10%)
3. **Retention** - Set trace retention policy
4. **Resource Limits** - Monitor memory and storage
5. **High Availability** - Deploy multiple collectors
6. **Security** - Enable authentication and TLS

---

## Troubleshooting

### No Traces Appearing
1. Check OTel Collector is sending to Jaeger
2. Verify service instrumentation
3. Check network connectivity
4. Review Jaeger logs

### High Memory Usage
1. Reduce sampling rate
2. Shorten retention period
3. Use persistent storage
4. Add resource limits

### Slow Queries
1. Add indexes in storage backend
2. Reduce time range of searches
3. Use more specific filters
4. Optimize storage configuration

---

## Alternatives

If Jaeger doesn't fit your needs:
- **Grafana Tempo** - Designed for high volume, cheaper storage
- **Zipkin** - Simpler, less features
- **Lightstep** - SaaS, advanced analysis
- **Honeycomb** - SaaS, full observability platform
- **AWS X-Ray** - Cloud-native (AWS only)

---

## See Also

- [Observability Plugins](../../README.md)
- [Core Telemetry](../../../../core/telemetry/)
- [Loki](../../logging/loki/) - For trace-log correlation
- [Grafana](../../visualization/grafana/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)

