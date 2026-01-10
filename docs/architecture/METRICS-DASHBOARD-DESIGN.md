# Metrics Dashboard Design

This document outlines the design for tracking build times, image sizes, and security issues across the A.R.C. platform.

---

## Overview

The metrics dashboard tracks three key areas:
1. **Build Performance** - Build times and cache efficiency
2. **Image Sizes** - Container image sizes against targets
3. **Security Posture** - Vulnerability counts and compliance

---

## Dashboard Panels

### Panel 1: Build Performance Trend

```
┌─────────────────────────────────────────────────────────────────┐
│  Build Time Trend (Last 30 Days)                                │
├─────────────────────────────────────────────────────────────────┤
│  90s ─┬─────────────────────────────────────────────────────   │
│       │      ╭─╮                                                │
│  60s ─┤   ╭──╯ ╰─╮                                              │
│       │ ╭─╯       ╰────────────────────────────────────────    │
│  30s ─┤─╯          Target: <60s                                 │
│       │                                                         │
│   0s ─┴────────────────────────────────────────────────────    │
│        Jan 1    Jan 5    Jan 10   Jan 15   Jan 20   Jan 25     │
└─────────────────────────────────────────────────────────────────┘

Legend:
  ─── arc-sherlock-brain    ─── arc-scarlett-voice
  ─── arc-piper-tts         ─── raymond
```

**Data Source**: `reports/build-performance-baseline.json`
**Query**: Build time per service per commit
**Alert**: Build time > 90s for 3 consecutive builds

### Panel 2: Image Size Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│  Image Sizes vs Targets                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  arc-sherlock-brain  ████████████████████░░░░░  380MB / 500MB  │
│  arc-scarlett-voice  █████████████████░░░░░░░░  320MB / 500MB  │
│  arc-piper-tts       ████████████░░░░░░░░░░░░░  240MB / 500MB  │
│  raymond             ██░░░░░░░░░░░░░░░░░░░░░░░   18MB / 50MB   │
│  arc-base-python-ai  ████████████░░░░░░░░░░░░░  245MB / 300MB  │
│                                                                 │
│  ████ Current Size    ░░░░ Remaining Budget                     │
└─────────────────────────────────────────────────────────────────┘
```

**Data Source**: `docker images --format json`
**Query**: Image size per service
**Alert**: Any image > target size

### Panel 3: Security Issues Over Time

```
┌─────────────────────────────────────────────────────────────────┐
│  Security Vulnerabilities                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  12 ─┬─────────────────────────────────────────────────────   │
│      │ ■                                                        │
│   8 ─┤ ■  ■                                                     │
│      │ ■  ■  ■                                                  │
│   4 ─┤ ■  ■  ■  ■  ■                                            │
│      │ ■  ■  ■  ■  ■  ■  ■  ■  ■  ●  ●  ●                      │
│   0 ─┴──────────────────────────────────────────────────────   │
│       W1   W2   W3   W4   W5   W6   W7   W8   W9   W10  W11    │
│                                                                 │
│  ■ HIGH    ● CRITICAL    Target: 0                              │
└─────────────────────────────────────────────────────────────────┘
```

**Data Source**: `reports/security-scan.json`
**Query**: CVE count by severity per week
**Alert**: Any CRITICAL vulnerability, HIGH > 5

### Panel 4: Cache Efficiency

```
┌─────────────────────────────────────────────────────────────────┐
│  Docker Build Cache Hit Rate                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Target: >85%                Current: 92%                       │
│                                                                 │
│         ┌────────────────────────────────────────┐             │
│         │██████████████████████████████████████░░│ 92%         │
│         └────────────────────────────────────────┘             │
│                                                                 │
│  By Service:                                                    │
│    arc-sherlock-brain   95%  ████████████████████░             │
│    arc-scarlett-voice   89%  ██████████████████░░░             │
│    arc-piper-tts        91%  ███████████████████░░             │
│    raymond              94%  ████████████████████░             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Data Source**: BuildKit metrics
**Query**: Cache hit ratio per build
**Alert**: Cache hit rate < 80%

### Panel 5: Service Health Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│  Service Dockerfile Compliance                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Service               │ Multi │ Non- │ Health │ Labels │ Size │
│                        │ Stage │ Root │ Check  │        │      │
│  ──────────────────────┼───────┼──────┼────────┼────────┼──────│
│  arc-sherlock-brain    │  ✅   │  ✅  │   ✅   │   ✅   │  ✅  │
│  arc-scarlett-voice    │  ✅   │  ✅  │   ✅   │   ✅   │  ✅  │
│  arc-piper-tts         │  ✅   │  ✅  │   ✅   │   ✅   │  ✅  │
│  raymond               │  ✅   │  ✅  │   ✅   │   ✅   │  ✅  │
│  arc-base-python-ai    │  ─    │  ✅  │   ✅   │   ✅   │  ✅  │
│  arc-oracle-sql        │  ─    │  ✅  │   ✅   │   ✅   │  ─   │
│  arc-otel-collector    │  ✅   │  ✅  │   ✅   │   ✅   │  ─   │
│  arc-deckard-identity  │  ─    │  ✅  │   ✅   │   ✅   │  ─   │
│                                                                 │
│  ✅ Compliant   ─ Not Applicable   ❌ Non-compliant             │
└─────────────────────────────────────────────────────────────────┘
```

**Data Source**: `scripts/validate/check-dockerfile-standards.py`
**Query**: Compliance checks per Dockerfile
**Alert**: Any ❌ in the matrix

---

## Data Collection

### Metrics Collection Script

```bash
#!/bin/bash
# scripts/metrics/collect-metrics.sh

# Build times (run after each build)
echo "{
  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"service\": \"$SERVICE\",
  \"build_time_seconds\": $BUILD_TIME,
  \"cache_hit_rate\": $CACHE_RATE
}" >> reports/build-metrics.jsonl

# Image sizes
docker images --format '{"repository":"{{.Repository}}","tag":"{{.Tag}}","size":"{{.Size}}"}' \
  | grep "^arc-" >> reports/image-sizes.jsonl

# Security scan
trivy fs --format json . > reports/trivy-latest.json
```

### Grafana Data Sources

| Data Source | Type | Purpose |
|-------------|------|---------|
| `build-metrics.jsonl` | JSON | Build performance |
| `image-sizes.jsonl` | JSON | Image sizes |
| `trivy-latest.json` | JSON | Security vulnerabilities |
| `hadolint-results.txt` | Text | Dockerfile linting |

---

## Dashboard JSON (Grafana)

```json
{
  "dashboard": {
    "title": "A.R.C. Platform - Build & Security Metrics",
    "tags": ["arc", "docker", "security"],
    "panels": [
      {
        "title": "Build Time Trend",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "title": "Image Sizes",
        "type": "bargauge",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "title": "Security Vulnerabilities",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "title": "Cache Efficiency",
        "type": "gauge",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      },
      {
        "title": "Compliance Matrix",
        "type": "table",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16}
      }
    ]
  }
}
```

---

## Alerting Rules

### Prometheus Alert Rules

```yaml
# prometheus/alerts/build-alerts.yml
groups:
  - name: build-performance
    rules:
      - alert: SlowBuild
        expr: build_duration_seconds > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Build time exceeds 90 seconds"

      - alert: LargImage
        expr: image_size_bytes > 500000000
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Image size exceeds 500MB target"

  - name: security
    rules:
      - alert: CriticalVulnerability
        expr: trivy_critical_count > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Critical vulnerability detected"

      - alert: HighVulnerabilityCount
        expr: trivy_high_count > 5
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "More than 5 HIGH vulnerabilities"

  - name: cache
    rules:
      - alert: LowCacheHitRate
        expr: build_cache_hit_rate < 0.8
        for: 30m
        labels:
          severity: info
        annotations:
          summary: "Docker build cache hit rate below 80%"
```

---

## Implementation Plan

### Phase 1: Data Collection
- [ ] Create metrics collection script
- [ ] Add metrics export to CI/CD
- [ ] Set up JSON file storage

### Phase 2: Visualization
- [ ] Import Grafana dashboard JSON
- [ ] Configure data sources
- [ ] Test panel queries

### Phase 3: Alerting
- [ ] Add Prometheus alert rules
- [ ] Configure notification channels
- [ ] Test alert firing

---

## Success Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Build time (incremental) | <60s | TBD |
| Python image size | <500MB | ~350MB |
| Go image size | <50MB | ~18MB |
| Cache hit rate | >85% | TBD |
| CRITICAL CVEs | 0 | 0 |
| HIGH CVEs | <5 | TBD |

---

## Related Documentation

- [Build Performance Baseline](../../reports/build-performance-baseline.json)
- [Security Scan Results](../../reports/security-scan.json)
- [Docker Build Optimization](../guides/DOCKER-BUILD-OPTIMIZATION.md)
