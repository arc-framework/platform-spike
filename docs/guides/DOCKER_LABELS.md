# Docker Labels Guide - A.R.C. Platform

This guide shows you how to use Docker labels to inspect and manage the A.R.C. platform services.

## 📋 Label Schema

Every A.R.C. service has the following labels:

| Label                      | Description              | Example                                   |
| -------------------------- | ------------------------ | ----------------------------------------- |
| `arc.service.layer`        | Infrastructure layer     | `core`, `plugin`, `application`           |
| `arc.service.category`     | Service category         | `gateway`, `persistence`, `observability` |
| `arc.service.subcategory`  | Subcategory (optional)   | `logging`, `metrics`, `tracing`           |
| `arc.service.codename`     | Hero/character codename  | `heimdall`, `oracle`, `watson`            |
| `arc.service.role`         | Descriptive role         | `The Gatekeeper`, `The Knowledge Keeper`  |
| `arc.service.tech`         | Underlying technology    | `traefik`, `postgresql`, `livekit`        |
| `arc.service.swappable`    | Can be replaced?         | `true`, `false`                           |
| `arc.service.alternatives` | Alternative tech options | `keycloak,auth0,cognito`                  |

---

## 🦸 Quick Roster View

Show all running services with their codenames and roles:

```bash
make roster
```

Or directly:

```bash
./scripts/show-roster.sh
```

**Output:**

```
═══════════════════════════════════════════════════════════════════
                  🦸 A.R.C. SERVICE ROSTER 🦸
═══════════════════════════════════════════════════════════════════

CONTAINER                 CODENAME     ROLE                 TECH            STATUS
─────────────────────────────────────────────────────────────────────────────────
arc-heimdall-gateway      heimdall     The Gatekeeper       traefik         Up 5 minutes
arc-oracle-sql            oracle       The Knowledge Keeper postgresql      Up 5 minutes
arc-sonic-cache           sonic        The Speedster        redis           Up 5 minutes
arc-daredevil-voice       daredevil    The Listener         livekit         Up 5 minutes
...
```

---

## 🔍 Filtering Services by Labels

### Show All Core Services

```bash
docker ps --filter "label=arc.service.layer=core" --format "table {{.Names}}\t{{.Status}}"
```

### Show All Observability Plugins

```bash
docker ps --filter "label=arc.service.category=observability" --format "table {{.Names}}\t{{.Label \"arc.service.role\"}}"
```

### Find a Specific Codename

```bash
docker ps --filter "label=arc.service.codename=oracle" --format "{{.Names}}"
# Output: arc-oracle-sql
```

### Show All Swappable Services

```bash
docker ps --filter "label=arc.service.swappable=true" \
  --format "table {{.Names}}\t{{.Label \"arc.service.alternatives\"}}"
```

**Output:**

```
NAMES                     ALTERNATIVES
arc-watson-logs           elasticsearch,splunk,cloudwatch
arc-house-metrics         influxdb,datadog,cloudwatch
arc-jarvis-identity       keycloak,auth0,cognito,okta
```

---

## 📊 Inspecting Labels

### Show All Labels for a Container

```bash
docker inspect arc-oracle-sql --format '{{json .Config.Labels}}' | jq
```

**Output:**

```json
{
  "arc.service.layer": "core",
  "arc.service.category": "persistence",
  "arc.service.codename": "oracle",
  "arc.service.role": "The Knowledge Keeper",
  "arc.service.tech": "postgresql"
}
```

### Get a Specific Label Value

```bash
docker inspect arc-daredevil-voice --format '{{index .Config.Labels "arc.service.role"}}'
# Output: The Listener
```

---

## 🎯 Practical Use Cases

### 1. **Automated Monitoring Setup**

Find all services that need Prometheus scraping:

```bash
docker ps --filter "label=arc.service.layer" --format '{{.Names}}' | \
  xargs -I {} docker inspect {} --format \
  '{{.Name}}: {{index .Config.Labels "arc.service.tech"}}'
```

### 2. **Generate Documentation**

Create a service inventory:

```bash
docker ps --filter "label=arc.service.codename" \
  --format "| {{.Label \"arc.service.codename\"}} | {{.Label \"arc.service.role\"}} | {{.Label \"arc.service.tech\"}} |"
```

### 3. **Restart All Core Services**

```bash
docker ps --filter "label=arc.service.layer=core" --format "{{.Names}}" | \
  xargs docker restart
```

### 4. **Find Services by Technology**

Who's using Redis?

```bash
docker ps --filter "label=arc.service.tech=redis" --format "{{.Names}}"
# Output: arc-sonic-cache
```

### 5. **Security Audit - Find All Swappable Services**

```bash
docker ps --filter "label=arc.service.swappable=true" \
  --format "table {{.Names}}\t{{.Label \"arc.service.alternatives\"}}"
```

---

## 🧪 Advanced Queries

### Find Services by Multiple Criteria

Core services that are NOT swappable:

```bash
docker ps --filter "label=arc.service.layer=core" | \
  grep -v "arc.service.swappable=true"
```

### Custom Table Output

```bash
docker ps --filter "label=arc.service.codename" \
  --format "table {{.Names}}\t{{.Label \"arc.service.codename\"}}\t{{.Label \"arc.service.role\"}}\t{{.Status}}"
```

---

## 🛠️ Using Labels in Docker Compose

When deploying with Docker Compose, labels are automatically applied:

```yaml
arc-oracle:
  image: ghcr.io/arc-framework/arc-oracle-sql:latest
  container_name: arc-oracle-sql
  labels:
    - 'arc.service.layer=core'
    - 'arc.service.codename=oracle'
    - 'arc.service.role=The Knowledge Keeper'
    - 'arc.service.tech=postgresql'
```

---

## 📝 Label Naming Conventions

- **Keys**: Use dot notation (`arc.service.codename`)
- **Values**: Lowercase, hyphen-separated for multi-word (`knowledge-keeper`)
- **Codenames**: Single word, lowercase (`heimdall`, `oracle`, `sonic`)
- **Roles**: Title case with "The" prefix (`The Gatekeeper`)
- **Tech**: Official name, lowercase (`postgresql` not `postgres`)

---

## 🔗 Integration with Monitoring Tools

### Prometheus Service Discovery

Labels are exposed in Prometheus via Docker SD:

```yaml
scrape_configs:
  - job_name: 'docker'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [__meta_docker_container_label_arc_service_codename]
        target_label: arc_codename
      - source_labels: [__meta_docker_container_label_arc_service_role]
        target_label: arc_role
```

### Grafana Dashboards

Filter panels by service layer:

```promql
rate(http_requests_total{arc_layer="core"}[5m])
```

---

## 🎨 Custom Scripts

Create your own label-based utilities:

```bash
#!/usr/bin/env bash
# show-tech-stack.sh - Display all technologies in use

echo "A.R.C. Technology Stack:"
docker ps --filter "label=arc.service.tech" \
  --format "{{.Label \"arc.service.tech\"}}" | \
  sort -u | \
  awk '{printf "  • %s\n", $0}'
```

---

## 📚 Complete Label Reference

### Core Services

| Codename    | Role                 | Tech            |
| ----------- | -------------------- | --------------- |
| `heimdall`  | The Gatekeeper       | `traefik`       |
| `jarvis`    | The Butler           | `kratos`        |
| `oracle`    | The Knowledge Keeper | `postgresql`    |
| `sonic`     | The Speedster        | `redis`         |
| `flash`     | The Messenger        | `nats`          |
| `strange`   | The Time Keeper      | `pulsar`        |
| `fury`      | The Spymaster        | `infisical`     |
| `mystique`  | The Shapeshifter     | `unleash`       |
| `daredevil` | The Listener         | `livekit`       |
| `widow`     | The All-Seeing       | `opentelemetry` |

### Observability Plugins

| Codename  | Role              | Tech         |
| --------- | ----------------- | ------------ |
| `watson`  | The Chronicler    | `loki`       |
| `house`   | The Diagnostician | `prometheus` |
| `columbo` | The Detective     | `jaeger`     |
| `friday`  | The UI Overlay    | `grafana`    |

---

## 💡 Tips

1. **Use `jq` for JSON parsing**: `docker inspect <container> | jq '.[] | .Config.Labels'`
2. **Combine with `grep`**: Filter output further for complex queries
3. **Script it**: Automate common queries in shell scripts
4. **Document it**: Add custom labels for your own services
5. **Monitor it**: Use labels in your monitoring dashboards

---

**Next Steps:**

- Run `make roster` to see your superhero lineup
- Try filtering by `arc.service.swappable=true` to see what's pluggable
- Create custom scripts using these labels for your workflow
