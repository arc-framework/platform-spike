# Prometheus - Metrics Storage

Time-series database for storing and querying metrics.

---

## Overview

**Prometheus** provides:
- Time-series metrics storage
- PromQL query language
- Pull-based scraping model
- Built-in alerting
- Service discovery

---

## Ports

- **9090** - Web UI and API

---

## Configuration

**Primary Config:** `prometheus.yaml`

### Key Features
- **Scraping** - Pull metrics from targets
- **PromQL** - Powerful query language
- **Storage** - Local time-series database
- **Alerting** - Alert manager integration
- **Federation** - Multi-cluster support

---

## Architecture

```
Prometheus → Scrapes metrics from:
  - OpenTelemetry Collector
  - Service /metrics endpoints
  - Node exporters
```

---

## Usage

### Start Service
```bash
make up-observability
# or
docker compose up prometheus
```

### Access Web UI
```bash
open http://localhost:9090
```

### Check Health
```bash
curl http://localhost:9090/-/healthy
```

---

## PromQL Query Examples

### Basic Queries
```promql
# Current CPU usage
rate(cpu_usage_seconds_total[5m])

# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status="500"}[5m])

# Request duration (P95)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### RED Metrics
```promql
# Rate - requests per second
sum(rate(http_requests_total[5m])) by (service)

# Errors - error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)

# Duration - request latency P95
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
)
```

### Alerting
```promql
# High error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) / 
sum(rate(http_requests_total[5m])) > 0.05

# Service down
up{job="my-service"} == 0
```

---

## Metrics from OpenTelemetry

OTel Collector exports metrics to Prometheus:

```yaml
# In otel-collector-config.yml
exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
```

Prometheus scrapes from the collector:

```yaml
# In prometheus.yaml
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8889']
```

---

## Data Retention

### Configuration
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Retention
storage:
  tsdb:
    retention.time: 15d    # Keep data for 15 days
    retention.size: 50GB   # Or until 50GB
```

### Check Storage
```bash
# Via API
curl http://localhost:9090/api/v1/status/tsdb

# Via container
docker compose exec prometheus df -h /prometheus
```

---

## Grafana Integration

Prometheus is auto-provisioned as a datasource in Grafana.

### Use in Grafana
1. Open Grafana (http://localhost:3000)
2. Create dashboard
3. Add panel with Prometheus datasource
4. Write PromQL queries

---

## Performance Tuning

### Scrape Configuration
```yaml
scrape_configs:
  - job_name: 'high-frequency'
    scrape_interval: 5s   # Fast scraping
    
  - job_name: 'low-frequency'
    scrape_interval: 60s  # Slower scraping
```

### Resource Limits
```yaml
# In docker-compose
services:
  prometheus:
    deploy:
      resources:
        limits:
          memory: 2GB
          cpus: '1.0'
```

---

## Monitoring Prometheus

Prometheus monitors itself:

```bash
# Check targets
open http://localhost:9090/targets

# Check configuration
open http://localhost:9090/config

# Check service discovery
open http://localhost:9090/service-discovery
```

---

## Production Notes

1. **External Storage** - Use remote write for long-term storage
2. **High Availability** - Deploy multiple Prometheus instances
3. **Alertmanager** - Set up alert routing and notifications
4. **Federation** - Aggregate metrics across clusters
5. **Retention Policy** - Balance storage vs data retention
6. **Backup** - Regular snapshots of TSDB

---

## Alternatives

If Prometheus doesn't fit your needs:
- **Victoria Metrics** - Prometheus-compatible, faster, cheaper
- **InfluxDB** - Time-series DB with different query language
- **Datadog** - SaaS platform
- **Thanos** - Prometheus with long-term storage

---

## See Also

- [Observability Plugins](../../README.md)
- [Core Telemetry](../../../../core/telemetry/)
- [Grafana](../../visualization/grafana/)
- [Prometheus Documentation](https://prometheus.io/docs/)

