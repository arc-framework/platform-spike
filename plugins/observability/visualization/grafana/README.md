# Grafana - Visualization Platform

Unified observability dashboards for metrics, logs, and traces.

---

## Overview

**Grafana** provides:
- Multi-datasource dashboards
- Unified visualization
- Alerting and notifications
- Explore mode for ad-hoc queries
- Dashboard templates and sharing

---

## Ports

- **3000** - Web UI and API

---

## Configuration

Grafana is auto-provisioned with datasources for:
- **Prometheus** - Metrics
- **Loki** - Logs
- **Jaeger** - Traces

**Datasource Config:** `provisioning/datasources/`

---

## Usage

### Start Service
```bash
make up-observability
# or
docker compose up grafana
```

### Access Web UI
```bash
open http://localhost:3000
```

### Default Credentials
```
Username: admin
Password: admin
```

⚠️ **Change password on first login!**

---

## Key Features

### 1. Dashboards
Create visual dashboards with:
- Time-series graphs
- Gauge panels
- Tables and lists
- Heatmaps
- Stat panels
- Bar charts

### 2. Explore Mode
Ad-hoc querying across datasources:
- Query metrics (PromQL)
- Search logs (LogQL)
- Find traces (Jaeger UI)
- Correlate data across sources

### 3. Alerting
Set up alerts based on queries:
- Threshold alerts
- Query-based alerts
- Alert routing
- Notification channels

### 4. Unified Search
Search across all observability data:
- Find logs by trace ID
- Jump from metric to trace
- Correlate events across sources

---

## Quick Start

### 1. Explore Metrics
1. Open Grafana (http://localhost:3000)
2. Go to Explore (compass icon)
3. Select "Prometheus" datasource
4. Enter PromQL query:
   ```promql
   rate(http_requests_total[5m])
   ```
5. Click "Run Query"

### 2. Search Logs
1. Go to Explore
2. Select "Loki" datasource
3. Enter LogQL query:
   ```logql
   {service_name="swiss-army-go"}
   ```
4. Filter and search logs

### 3. View Traces
1. Go to Explore
2. Select "Jaeger" datasource
3. Search by service or trace ID
4. Click trace to view details

---

## Creating Dashboards

### Basic Dashboard
1. Click "+" → "Dashboard"
2. Add panel
3. Select datasource (Prometheus, Loki, Jaeger)
4. Write query
5. Choose visualization type
6. Save dashboard

### Example Panels

#### Request Rate (Prometheus)
```promql
sum(rate(http_requests_total[5m])) by (service)
```

#### Error Logs (Loki)
```logql
sum(count_over_time({service_name="api"} |= "level=error" [5m])) by (service_name)
```

#### Trace Count (Custom)
Query Jaeger API for trace statistics

---

## Dashboard Templates

### RED Metrics Dashboard
Monitor Rate, Errors, Duration:

```promql
# Rate
sum(rate(http_requests_total[5m])) by (service)

# Errors
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)

# Duration (P95)
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
)
```

### Service Overview Dashboard
- Request rate graph
- Error rate graph
- Latency percentiles (P50, P95, P99)
- Active instances
- Recent error logs
- Trace samples

---

## Trace-Log-Metric Correlation

### Drill-down Flow
```
1. See metric spike in dashboard
   ↓
2. Click to explore metrics
   ↓
3. Find high-latency traces
   ↓
4. Click trace ID to view in Jaeger
   ↓
5. Find error span in trace
   ↓
6. Copy trace ID
   ↓
7. Search logs for trace_id in Loki
   ↓
8. Find root cause in logs
```

### Example Workflow
1. **Dashboard alert** - High error rate
2. **Explore metrics** - Which endpoint?
3. **Search logs** - What errors?
4. **Find trace** - Which request failed?
5. **Analyze trace** - Where did it fail?
6. **Check logs** - Why did it fail?

---

## Alerting

### Create Alert
1. Open dashboard panel
2. Click "Alert" tab
3. Define alert rule:
   ```
   WHEN avg() OF query(A, 5m, now)
   IS ABOVE 100
   ```
4. Add notification channel
5. Save alert

### Notification Channels
- Email
- Slack
- PagerDuty
- Webhook
- Discord
- Teams

---

## Data Source Configuration

### Prometheus
```yaml
# provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
```

### Loki
```yaml
# provisioning/datasources/loki.yml
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    url: http://loki:3100
```

### Jaeger
```yaml
# provisioning/datasources/jaeger.yml
apiVersion: 1
datasources:
  - name: Jaeger
    type: jaeger
    url: http://jaeger:16686
```

---

## Variables and Templating

### Dashboard Variables
Create dynamic dashboards:

```
# Service selector
$service = label_values(service_name)

# Query using variable
rate(http_requests_total{service="$service"}[5m])
```

### Common Variables
- **Service** - Filter by service
- **Environment** - dev/staging/prod
- **Time range** - Quick time selection
- **Instance** - Filter by instance

---

## Performance Tips

1. **Limit time ranges** - Don't query years of data
2. **Use caching** - Enable query caching
3. **Reduce refresh rate** - Don't refresh every second
4. **Optimize queries** - Use recording rules in Prometheus
5. **Dashboard organization** - Separate dashboards by team/service

---

## Production Notes

1. **Authentication** - Enable proper auth (OAuth, LDAP, etc.)
2. **User Management** - Set up teams and permissions
3. **Backup Dashboards** - Export and version control dashboards
4. **High Availability** - Deploy multiple Grafana instances
5. **Database** - Use external database (PostgreSQL) instead of SQLite
6. **Security** - Use HTTPS, secure datasource credentials
7. **Monitoring** - Monitor Grafana itself

---

## Troubleshooting

### Datasource Not Working
1. Check datasource configuration
2. Verify network connectivity
3. Test datasource URL from Grafana container
4. Check datasource logs

### Dashboard Not Loading
1. Check query syntax
2. Verify time range
3. Check datasource availability
4. Review Grafana logs

### Slow Performance
1. Reduce time range
2. Optimize queries
3. Enable query caching
4. Increase Grafana resources

---

## Alternatives

If Grafana doesn't fit your needs:
- **Kibana** - For Elasticsearch/OpenSearch stack
- **Datadog** - SaaS, full platform
- **Custom Dashboards** - Build your own
- **Prometheus UI** - Basic metrics UI
- **Jaeger UI** - For traces only

---

## See Also

- [Observability Plugins](../../README.md)
- [Prometheus](../../metrics/prometheus/)
- [Loki](../../logging/loki/)
- [Jaeger](../../tracing/jaeger/)
- [Grafana Documentation](https://grafana.com/docs/grafana/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

