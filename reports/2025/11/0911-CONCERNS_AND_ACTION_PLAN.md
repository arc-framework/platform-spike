# A.R.C. Platform Spike - Concerns & Action Plan

**Created:** November 9, 2025  
**Status:** Ready for Implementation  
**Previous Report:** November 8, 2025 (0811)  
**Progress Since Last Report:** Minimal (15% - primarily documentation improvements)

---

## EXECUTIVE SUMMARY

**Total Issues:** 18 | **Critical:** 7 | **High:** 6 | **Medium:** 5

**Status:** The platform remains **NOT PRODUCTION-READY** due to unresolved critical security vulnerabilities and missing operational safeguards. The majority of concerns identified in the 0811 report remain unaddressed. Immediate action is required before any staging or production deployment.

**Critical Path to Production:** 22 hours of focused work to resolve blocking issues

---

## CONCERNS INVENTORY

### 🔴 CRITICAL CONCERNS (Production Blockers)

---

#### C1: Environment File Integration Broken (UNRESOLVED from 0811)
**Severity:** 🔴 CRITICAL  
**Category:** Configuration Management  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
Service-level `.env` files exist in the repository but are **completely unused** by docker-compose:

```
core/persistence/postgres/.env.example          (exists but not loaded)
core/caching/redis/.env.example                 (exists but not loaded)
core/messaging/ephemeral/nats/.env.example      (exists but not loaded)
core/telemetry/otel-collector/.env.example      (exists but not loaded)
# ... 10 additional service .env files unused
```

**Evidence:**
```yaml
# docker-compose.core.yml - NO env_file directive
arc_postgres:
  # Missing: env_file: ../../core/persistence/postgres/.env
  environment:
    POSTGRES_USER: ${POSTGRES_USER:-arc}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
```

**Impact:**
- ❌ Cannot isolate secrets per service
- ❌ Cannot deploy multiple environments (dev, staging, prod)
- ❌ OPERATIONS.md documentation is misleading
- ❌ Multi-environment workflow documented but doesn't work
- ❌ Security best practice violated (all secrets in one file)

**Files Affected:**
- `deployments/docker/docker-compose.core.yml` (8 services)
- `deployments/docker/docker-compose.observability.yml` (4 services)
- `deployments/docker/docker-compose.security.yml` (1 service)
- `deployments/docker/docker-compose.services.yml` (1 service)
- All 14 service `.env.example` files

**Solution Approach:**
```yaml
# Add env_file directive to each service
arc_postgres:
  env_file:
    - ../../core/persistence/postgres/.env
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: ${POSTGRES_DB}
```

**Acceptance Criteria:**
```bash
# Test 1: Service config isolation works
echo "POSTGRES_PASSWORD=staging-password" > core/persistence/postgres/.env
make up
docker exec arc_postgres env | grep POSTGRES_PASSWORD
# Should output: POSTGRES_PASSWORD=staging-password

# Test 2: Multi-environment switching works
ENV_FILE=.env.prod make up
# Should load production-specific configs
```

**Estimated Effort:** 4 hours

---

#### C2: Weak Default Passwords (UNRESOLVED from 0811)
**Severity:** 🔴 CRITICAL  
**Category:** Security  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
Multiple services use trivially guessable default passwords that fall back when environment variables aren't set:

```yaml
# docker-compose.core.yml
arc_postgres:
  environment:
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}  # 🔴 Default: "postgres"

arc_postgres (used by multiple services):
  DSN: postgres://arc:postgres@...  # 🔴 Hardcoded in connection strings
```

**Impact:**
- 🔴 **CRITICAL SECURITY VULNERABILITY** - Default credentials are public knowledge
- ❌ Fails any security audit or penetration test
- ❌ Database accessible with known credentials
- ❌ PCI-DSS, SOC 2, ISO 27001 compliance failures
- ❌ Acceptable ONLY for local development on isolated networks

**Files Affected:**
- `deployments/docker/docker-compose.core.yml` (postgres, infisical, unleash, kratos)
- `deployments/docker/docker-compose.security.yml` (kratos DSN)

**Solution Approach:**
```yaml
# Remove fallback defaults - require explicit values
arc_postgres:
  environment:
    POSTGRES_USER: ${POSTGRES_USER}        # No default
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}  # No default - startup will fail if not set
    POSTGRES_DB: ${POSTGRES_DB}

# Add validation to Makefile
.env:
	@if [ -z "$$POSTGRES_PASSWORD" ]; then \
		echo "ERROR: POSTGRES_PASSWORD not set. Run: make init"; \
		exit 1; \
	fi
```

**Additional Actions:**
1. Create `scripts/generate-secrets.sh` to generate strong passwords
2. Update `.env.example` with placeholders, not defaults
3. Document secret generation in README

**Acceptance Criteria:**
```bash
# Test 1: Startup fails without password
unset POSTGRES_PASSWORD
make up
# Should error: "POSTGRES_PASSWORD not set"

# Test 2: Strong password works
export POSTGRES_PASSWORD=$(openssl rand -base64 32)
make up
# Should succeed
```

**Estimated Effort:** 2 hours

---

#### C3: Kratos Hardcoded Secrets (NEW - Critical Discovery)
**Severity:** 🔴 CRITICAL  
**Category:** Security  
**Status:** ❌ NEW ISSUE

**Current State:**
Kratos configuration file contains **hardcoded, insecure secrets** committed to the repository:

```yaml
# plugins/security/identity/kratos/kratos.yml (lines 59-63)
secrets:
  cookie:
    - PLEASE-CHANGE-ME-I-AM-VERY-INSECURE     # 🔴 Hardcoded in repo
  cipher:
    - 32-LONG-SECRET-NOT-SECURE-AT-ALL        # 🔴 Hardcoded in repo
```

**Impact:**
- 🔴 **AUTHENTICATION SYSTEM COMPROMISED** - Anyone with repo access has secrets
- ❌ Session cookies can be forged
- ❌ User data can be decrypted
- ❌ Complete identity system bypass possible
- ❌ Violates every security best practice
- ❌ Cannot pass security audit

**Files Affected:**
- `plugins/security/identity/kratos/kratos.yml`

**Solution Approach:**
```yaml
# kratos.yml - Use environment variables
secrets:
  cookie:
    - ${KRATOS_COOKIE_SECRET}
  cipher:
    - ${KRATOS_CIPHER_SECRET}

# In .env (not committed)
KRATOS_COOKIE_SECRET=$(openssl rand -hex 32)
KRATOS_CIPHER_SECRET=$(openssl rand -hex 32)
```

**Additional Actions:**
1. Rotate secrets immediately (current secrets are public)
2. Audit git history for secret exposure
3. Add to `.gitignore` if not already
4. Update docker-compose.security.yml to inject env vars

**Acceptance Criteria:**
```bash
# Test 1: No hardcoded secrets in config
grep -i "PLEASE-CHANGE-ME" plugins/security/identity/kratos/kratos.yml
# Should return no results

# Test 2: Kratos loads secrets from environment
docker exec arc_kratos kratos serve --config /etc/config/kratos/kratos.yml
# Should start without errors
```

**Estimated Effort:** 1 hour

---

#### C4: Infisical Weak Default Secrets (UNRESOLVED from 0811)
**Severity:** 🔴 CRITICAL  
**Category:** Security  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
Infisical (the secrets management service!) has weak default encryption keys:

```yaml
# docker-compose.core.yml
arc_infisical:
  environment:
    ENCRYPTION_KEY: ${INFISICAL_ENCRYPTION_KEY:-change-this-in-production}  # 🔴
    AUTH_SECRET: ${INFISICAL_AUTH_SECRET:-change-this-in-production}        # 🔴
```

**Impact:**
- 🔴 **SECRETS VAULT COMPROMISED** - The system meant to protect secrets is insecure
- ❌ All stored secrets (API keys, passwords, tokens) can be decrypted
- ❌ Ironic: The security service has the worst security
- ❌ Cannot trust the secrets management system

**Files Affected:**
- `deployments/docker/docker-compose.core.yml`

**Solution Approach:**
```yaml
# Remove defaults
arc_infisical:
  environment:
    ENCRYPTION_KEY: ${INFISICAL_ENCRYPTION_KEY}  # Required
    AUTH_SECRET: ${INFISICAL_AUTH_SECRET}        # Required

# Generate strong secrets
openssl rand -hex 32  # For ENCRYPTION_KEY
openssl rand -hex 32  # For AUTH_SECRET
```

**Acceptance Criteria:**
```bash
# Test: Startup fails without secrets
unset INFISICAL_ENCRYPTION_KEY
make up
# Should error
```

**Estimated Effort:** 1 hour

---

#### C5: No Resource Limits Defined (UNRESOLVED from 0811)
**Severity:** 🔴 CRITICAL  
**Category:** Operations / Reliability  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
**Zero services** have resource limits or reservations defined. Containers can consume unlimited CPU and memory.

```yaml
# Example: Pulsar can consume unbounded memory
arc_pulsar:
  image: apachepulsar/pulsar:3.3.0
  # No deploy.resources block!
  # No memory limit!
  # No CPU limit!
  # Java heap can grow until OOM kills entire host
```

**Impact:**
- 🔴 **OUT-OF-MEMORY (OOM) CRASHES** - Services will OOM and crash host
- ❌ Resource contention unpredictable
- ❌ No capacity planning possible
- ❌ System instability under load
- ❌ Cannot guarantee service quality
- ❌ Kubernetes deployment blocked (limits required)

**Risk Matrix:**

| Service | Risk Level | Memory Usage | Severity |
|---------|-----------|--------------|----------|
| Pulsar (Java) | 🔴 EXTREME | Unbounded heap growth | CRITICAL |
| Postgres | 🔴 HIGH | Query memory, cache | CRITICAL |
| Prometheus | 🔴 HIGH | Metrics storage grows | CRITICAL |
| Grafana | 🟡 MEDIUM | Dashboard rendering | HIGH |
| Jaeger | 🟡 MEDIUM | In-memory spans | HIGH |
| All others | 🟢 LOW | Generally bounded | MEDIUM |

**Files Affected:**
- `deployments/docker/docker-compose.core.yml` (8 services)
- `deployments/docker/docker-compose.observability.yml` (4 services)
- `deployments/docker/docker-compose.security.yml` (1 service)
- `deployments/docker/docker-compose.services.yml` (1 service)

**Solution Approach:**
```yaml
# Add resource limits to all services
arc_pulsar:
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
      reservations:
        cpus: '1.0'
        memory: 1G

arc_postgres:
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M

arc_prometheus:
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M

# Repeat for all 14 services
```

**Recommended Resource Allocation (Development Profile):**

```yaml
# Core Services
arc_postgres:       2 CPU / 2GB RAM
arc_redis:          0.5 CPU / 512MB RAM
arc_nats:           0.5 CPU / 256MB RAM
arc_pulsar:         2 CPU / 2GB RAM
arc_traefik:        0.5 CPU / 256MB RAM
arc_infisical:      0.5 CPU / 512MB RAM
arc_unleash:        0.5 CPU / 512MB RAM
arc_otel_collector: 1 CPU / 512MB RAM

# Observability Services
arc_prometheus:     1 CPU / 2GB RAM
arc_loki:           1 CPU / 1GB RAM
arc_jaeger:         1 CPU / 1GB RAM
arc_grafana:        0.5 CPU / 512MB RAM

# Application Services
arc_swiss_army:     0.5 CPU / 256MB RAM

# Total: ~10 CPUs / 13GB RAM (conservative limits)
```

**Acceptance Criteria:**
```bash
# Test 1: Limits enforced
docker stats --no-stream
# All services should show memory limits

# Test 2: Services respect limits
docker inspect arc_pulsar | grep -A5 Resources
# Should show Memory and NanoCpus limits
```

**Estimated Effort:** 3 hours

---

#### C6: Traefik Dashboard Insecure (UNRESOLVED from 0811)
**Severity:** 🔴 CRITICAL  
**Category:** Security  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
Traefik API dashboard is exposed without authentication:

```yaml
# docker-compose.core.yml
arc_traefik:
  command:
    - "--api.insecure=true"  # 🔴 CRITICAL: No auth required
  ports:
    - "8080:8080"  # Dashboard exposed to host
```

**Impact:**
- 🔴 **GATEWAY COMPROMISE** - Anyone can access management interface
- ❌ View all routing configuration
- ❌ Modify routes in real-time
- ❌ Expose backend service URLs
- ❌ Potential service disruption or data exfiltration

**Files Affected:**
- `deployments/docker/docker-compose.core.yml`
- `core/gateway/traefik/traefik.yml`

**Solution Approach:**
```yaml
# docker-compose.core.yml
arc_traefik:
  command:
    - "--api.insecure=${TRAEFIK_API_INSECURE:-false}"  # Default to secure
    - "--api.dashboard=true"
  environment:
    - TRAEFIK_DASHBOARD_AUTH=${TRAEFIK_DASHBOARD_AUTH}  # htpasswd format
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.dashboard.rule=Host(`traefik.localhost`)"
    - "traefik.http.routers.dashboard.service=api@internal"
    - "traefik.http.routers.dashboard.middlewares=auth"
    - "traefik.http.middlewares.auth.basicauth.users=${TRAEFIK_DASHBOARD_AUTH}"

# Generate password
htpasswd -nb admin $(openssl rand -base64 16)
# Store in .env as TRAEFIK_DASHBOARD_AUTH
```

**Acceptance Criteria:**
```bash
# Test 1: Dashboard requires auth
curl -I http://localhost:8080
# Should return 401 Unauthorized

# Test 2: Auth works
curl -u admin:password http://localhost:8080
# Should return 200 OK
```

**Estimated Effort:** 1 hour

---

#### C7: No Container Log Rotation (UNRESOLVED from 0811)
**Severity:** 🔴 CRITICAL  
**Category:** Operations  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
**No logging configuration** defined for any service. Logs use default `json-file` driver with **no rotation**.

```yaml
# ALL services missing logging config:
arc_postgres:
  # No logging: block!
  # Logs grow unbounded
  # Will fill disk eventually
```

**Impact:**
- 🔴 **DISK SPACE EXHAUSTION** - Long-running deployments will fill disk
- ❌ System crash when disk full
- ❌ No log rotation strategy
- ❌ No log aggregation outside Loki
- ❌ Operational burden to manually clean logs

**Files Affected:**
- All compose files (14 services total)

**Solution Approach:**
```yaml
# Add to all services
x-logging: &default-logging
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
      labels: "arc.service"

services:
  arc_postgres:
    <<: *default-logging
    # ... rest of config

  arc_redis:
    <<: *default-logging
    # ... rest of config
```

**Acceptance Criteria:**
```bash
# Test: Log rotation configured
docker inspect arc_postgres | jq '.[0].HostConfig.LogConfig'
# Should show: "max-size": "10m", "max-file": "3"

# Test: Old logs cleaned up
docker logs arc_postgres | wc -l
# Should not exceed ~1000 lines after weeks of running
```

**Estimated Effort:** 2 hours

---

### 🟡 HIGH-PRIORITY CONCERNS (Recommended Before Staging)

---

#### C8: Makefile ENV_FILE Variable Not Used (UNRESOLVED from 0811)
**Severity:** 🟡 HIGH  
**Category:** Configuration Management  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
Makefile defines `ENV_FILE` variable but **never passes it to docker-compose**:

```makefile
# Makefile line 28
ENV_FILE ?= .env  # Variable defined

# But all compose commands ignore it:
up-full: .env
	$(COMPOSE_FULL) up -d --build  # Should use --env-file $(ENV_FILE)
```

**Impact:**
- ❌ Cannot switch environments via `ENV_FILE=.env.prod make up`
- ❌ Multi-environment workflow documented but broken
- ❌ Staging/production deployments require manual .env swapping
- ❌ Risk of deploying wrong environment config

**Files Affected:**
- `Makefile` (all compose invocations)

**Solution Approach:**
```makefile
# Update all compose commands
ENV_FILE ?= .env

up-full: .env
	$(COMPOSE_FULL) --env-file $(ENV_FILE) up -d --build

down-full:
	$(COMPOSE_FULL) --env-file $(ENV_FILE) down

# Repeat for all targets that invoke compose
```

**Acceptance Criteria:**
```bash
# Test 1: Environment switching works
cp .env.example .env.staging
ENV_FILE=.env.staging make up
docker exec arc_postgres env | grep POSTGRES_PASSWORD
# Should show staging password

# Test 2: Default still works
make up
# Should use .env
```

**Estimated Effort:** 1 hour

---

#### C9: Health Checks Missing start_period (UNRESOLVED from 0811)
**Severity:** 🟡 HIGH  
**Category:** Reliability  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
Health checks start immediately without grace period, causing false failures during startup:

```yaml
# docker-compose.observability.yml
arc_loki:
  healthcheck:
    test: ["CMD", "wget", "--spider", "http://localhost:3100/ready"]
    interval: 10s
    timeout: 5s
    retries: 5
    # Missing: start_period
```

**Impact:**
- ⚠️ Services marked unhealthy during normal startup
- ⚠️ `depends_on: condition: service_healthy` can timeout unnecessarily
- ⚠️ Misleading health check failures in logs
- ⚠️ Race conditions in service startup order

**Files Affected:**
- `deployments/docker/docker-compose.core.yml` (8 services)
- `deployments/docker/docker-compose.observability.yml` (4 services)
- `deployments/docker/docker-compose.security.yml` (1 service)
- `deployments/docker/docker-compose.services.yml` (1 service)

**Solution Approach:**
```yaml
# Standard health check template
healthcheck:
  test: [health check command]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 15s  # Wait 15s before first check
```

**Recommended start_period by service:**
```yaml
arc_postgres:      start_period: 10s
arc_redis:         start_period: 5s
arc_nats:          start_period: 5s
arc_pulsar:        start_period: 30s  # Slow to start
arc_loki:          start_period: 10s
arc_prometheus:    start_period: 10s
arc_jaeger:        start_period: 10s
arc_grafana:       start_period: 15s
arc_kratos:        start_period: 15s
arc_infisical:     start_period: 20s
arc_unleash:       start_period: 15s
arc_traefik:       start_period: 10s
arc_otel_collector: start_period: 15s
arc_swiss_army:    start_period: 10s
```

**Acceptance Criteria:**
```bash
# Test: Services don't report unhealthy during startup
make up
make health-all
# All services should become healthy without false failures
```

**Estimated Effort:** 1 hour

---

#### C10: Debug OTEL Exporter Enabled (UNRESOLVED from 0811)
**Severity:** 🟡 HIGH  
**Category:** Performance / Security  
**Status:** ❌ NO PROGRESS since 0811

**Current State:**
OTEL Collector has debug exporter with verbose output enabled:

```yaml
# core/telemetry/otel-collector-config.yml
exporters:
  debug:
    verbosity: detailed  # 🟡 Outputs ALL telemetry to console

service:
  pipelines:
    traces:
      exporters: [otlp/jaeger, debug, spanmetrics]  # Debug in production pipeline
    logs:
      exporters: [otlphttp/loki, debug]             # Debug in production pipeline
```

**Impact:**
- ⚠️ **Performance degradation** from excessive console output
- ⚠️ Logs become unreadable (flooded with telemetry)
- ⚠️ Sensitive data exposure in container logs
- ⚠️ Increased disk usage
- ⚠️ CPU overhead from formatting debug output

**Files Affected:**
- `core/telemetry/otel-collector-config.yml`

**Solution Approach:**
```yaml
# Option 1: Remove debug exporter entirely (recommended for production)
exporters:
  # debug: removed

service:
  pipelines:
    traces:
      exporters: [otlp/jaeger, spanmetrics]  # No debug
    logs:
      exporters: [otlphttp/loki]             # No debug

# Option 2: Create separate dev config (keep for troubleshooting)
# otel-collector-config.dev.yml (with debug)
# otel-collector-config.yml (without debug)
```

**Acceptance Criteria:**
```bash
# Test: Debug output not present
docker logs arc_otel_collector 2>&1 | grep "Span" | wc -l
# Should be 0 (no debug span output)
```

**Estimated Effort:** 0.5 hours

---

#### C11: Infisical Image Uses :latest Tag (NEW)
**Severity:** 🟡 HIGH  
**Category:** Stability / Reproducibility  
**Status:** ❌ REGRESSION (was better in previous analysis)

**Current State:**
Infisical uses `:latest-postgres` tag, not a specific version:

```yaml
# docker-compose.core.yml
arc_infisical:
  image: infisical/infisical:latest-postgres  # 🟡 Uses :latest variant
```

**Impact:**
- ⚠️ Non-deterministic deployments
- ⚠️ Breaking changes can slip in
- ⚠️ Cannot reproduce exact environment
- ⚠️ Different staging/production versions possible

**Files Affected:**
- `deployments/docker/docker-compose.core.yml`

**Solution Approach:**
```yaml
# Pin to specific version
arc_infisical:
  image: infisical/infisical:${INFISICAL_VERSION:-v0.50.0}-postgres

# In .env.example
INFISICAL_VERSION=v0.50.0
```

**Acceptance Criteria:**
```bash
# Test: Specific version used
docker compose config | grep "infisical:v"
# Should show: infisical/infisical:v0.50.0-postgres
```

**Estimated Effort:** 0.5 hours

---

#### C12: No Secrets Validation Script
**Severity:** 🟡 HIGH  
**Category:** Developer Experience / Security  
**Status:** ❌ NEW CONCERN

**Current State:**
No validation of required environment variables before deployment:

```bash
# Missing: scripts/validate-env.sh
# Missing: Makefile pre-flight checks
```

**Impact:**
- ⚠️ Deployments fail with cryptic errors
- ⚠️ Time wasted debugging missing variables
- ⚠️ Weak passwords not detected
- ⚠️ No enforcement of security policies

**Files Affected:**
- `scripts/` (validation script missing)
- `Makefile` (no validation target)

**Solution Approach:**
```bash
#!/bin/bash
# scripts/validate-env.sh

set -e

# Check required variables
required_vars=(
  "POSTGRES_PASSWORD"
  "INFISICAL_ENCRYPTION_KEY"
  "INFISICAL_AUTH_SECRET"
  "KRATOS_COOKIE_SECRET"
  "KRATOS_CIPHER_SECRET"
)

for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "ERROR: Required variable $var not set"
    exit 1
  fi
done

# Validate password strength
if [ ${#POSTGRES_PASSWORD} -lt 16 ]; then
  echo "ERROR: POSTGRES_PASSWORD must be at least 16 characters"
  exit 1
fi

# Validate Kratos secrets are hex strings
if ! [[ "$KRATOS_COOKIE_SECRET" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "ERROR: KRATOS_COOKIE_SECRET must be 64 character hex string"
  exit 1
fi

echo "✓ All environment variables validated"
```

**Acceptance Criteria:**
```bash
# Test 1: Detects missing variables
unset POSTGRES_PASSWORD
./scripts/validate-env.sh
# Should error with helpful message

# Test 2: Detects weak passwords
export POSTGRES_PASSWORD="weak"
./scripts/validate-env.sh
# Should error: "must be at least 16 characters"
```

**Estimated Effort:** 2 hours

---

#### C13: No TLS/SSL Configuration
**Severity:** 🟡 HIGH  
**Category:** Security  
**Status:** ❌ Expected for dev, blocks production

**Current State:**
All services communicate over unencrypted HTTP:

```yaml
# All endpoints are HTTP
GRAFANA: http://localhost:3000
JAEGER: http://localhost:16686
TRAEFIK: http://localhost:80
# No HTTPS configuration anywhere
```

**Impact:**
- ⚠️ Data in transit exposed (credentials, telemetry, queries)
- ⚠️ Man-in-the-middle attacks possible
- ⚠️ Compliance violations (HIPAA, PCI-DSS require TLS)
- ⚠️ Cannot pass security audit
- ✅ Acceptable for local development only

**Files Affected:**
- `deployments/docker/docker-compose.core.yml` (Traefik)
- `core/gateway/traefik/traefik.yml`

**Solution Approach:**
```yaml
# traefik.yml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: ops@example.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

**Acceptance Criteria:**
```bash
# Test: HTTPS works
curl -I https://localhost
# Should return 200 with valid certificate
```

**Estimated Effort:** 3 hours

---

### 🟢 MEDIUM-PRIORITY CONCERNS (Operational Improvements)

---

#### C14: No Automated Backup Strategy
**Severity:** 🟢 MEDIUM  
**Category:** Disaster Recovery  
**Status:** Basic manual backup only

**Current State:**
Makefile has basic backup target but no automation:

```makefile
backup-db:
    docker exec arc_postgres pg_dump -U arc arc_db > ./backups/arc_db_$(date).sql
```

**Issues:**
- ❌ No scheduled backups (cron, systemd timer)
- ❌ No backup verification
- ❌ No retention policy
- ❌ No off-site storage
- ❌ No restoration testing

**Solution Approach:**
```bash
#!/bin/bash
# scripts/backup-automated.sh

# Backup all critical data
backup_postgres() {
  timestamp=$(date +%Y%m%d_%H%M%S)
  docker exec arc_postgres pg_dump -U arc arc_db > ./backups/postgres_$timestamp.sql
  gzip ./backups/postgres_$timestamp.sql
}

backup_redis() {
  docker exec arc_redis redis-cli SAVE
  docker cp arc_redis:/data/dump.rdb ./backups/redis_$timestamp.rdb
}

# Cleanup old backups (keep last 30 days)
find ./backups -name "*.sql.gz" -mtime +30 -delete

# Verify backup integrity
verify_backup() {
  # Test restoration to temporary database
}
```

**Estimated Effort:** 2 hours

---

#### C15: No Prometheus Alerting Rules
**Severity:** 🟢 MEDIUM  
**Category:** Monitoring  
**Status:** Metrics collected but no alerts

**Current State:**
Prometheus scrapes metrics but has no alerting rules configured.

**Solution Approach:**
```yaml
# prometheus-alerts.yml (create new file)
groups:
  - name: arc_platform_critical
    rules:
      - alert: PostgresDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Postgres database is down"
          
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} using >90% memory"
```

**Estimated Effort:** 3 hours

---

#### C16: Network Segmentation Missing
**Severity:** 🟢 MEDIUM  
**Category:** Security  
**Status:** Single flat network

**Current State:**
All services on one bridge network:

```yaml
networks:
  arc_net:  # All 14 services here
```

**Solution Approach:**
```yaml
# Create separate networks for defense in depth
networks:
  frontend:    # Public-facing (Traefik, Grafana, Jaeger)
  backend:     # Application tier (Swiss Army)
  data:        # Data tier (Postgres, Redis)
  observability: # Observability (Loki, Prometheus)
  internal:    # Internal only (OTEL Collector)
```

**Estimated Effort:** 2 hours

---

#### C17: Unnecessary Port Exposures
**Severity:** 🟢 MEDIUM  
**Category:** Security  
**Status:** All ports exposed for dev convenience

**Current State:**
Many internal services exposed to host:

```yaml
# Should be internal only in production:
arc_prometheus:
  ports:
    - "9090:9090"  # Should use Traefik ingress

arc_loki:
  ports:
    - "3100:3100"  # Should be internal

arc_postgres:
  ports:
    - "5432:5432"  # High risk if exposed remotely
```

**Solution Approach:**
Create production compose overlay without port mappings for internal services.

**Estimated Effort:** 1 hour

---

#### C18: No CI/CD Pipeline
**Severity:** 🟢 MEDIUM  
**Category:** DevOps  
**Status:** Manual deployment only

**Current State:**
- No `.github/workflows/` directory
- No automated testing
- No automated validation
- Manual deployment process

**Solution Approach:**
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate compose files
        run: make validate-compose
      - name: Build images
        run: make build
      - name: Run health checks
        run: |
          make up
          sleep 30
          make health-all
```

**Estimated Effort:** 4 hours

---

## SOLUTION PLAN

### PHASE 1: CRITICAL SECURITY FIXES (REQUIRED for ANY deployment)
**Estimated Time:** 10.5 hours  
**Blocking:** Production, Staging, ANY public deployment

#### Priority Order:
1. **C2: Remove weak default passwords** (2h) - Highest impact
2. **C3: Fix Kratos hardcoded secrets** (1h) - Critical vulnerability
3. **C4: Fix Infisical weak defaults** (1h) - Ironically urgent
4. **C6: Secure Traefik dashboard** (1h) - Gateway compromise
5. **C5: Add resource limits** (3h) - OOM protection
6. **C7: Configure log rotation** (2h) - Disk protection
7. **C10: Remove debug OTEL exporter** (0.5h) - Quick win

#### Deliverables:
- [ ] All services require explicit passwords (no defaults)
- [ ] Kratos secrets from environment variables only
- [ ] Infisical secrets required and validated
- [ ] Traefik dashboard protected with BasicAuth
- [ ] Resource limits on all 14 services
- [ ] Log rotation configured (10MB max, 3 files)
- [ ] Debug exporter removed from OTEL collector

#### Acceptance Criteria:
```bash
# Security validated
./scripts/validate-env.sh  # All secrets validated
make up  # Fails if secrets missing
curl http://localhost:8080  # Returns 401 (Traefik auth)

# Resources controlled
docker stats  # All services show memory limits
docker logs arc_postgres | wc -l  # Limited log size

# Performance optimized
docker logs arc_otel_collector | grep "Span" | wc -l  # Should be 0
```

---

### PHASE 2: HIGH-PRIORITY FIXES (Before Staging)
**Estimated Time:** 8 hours  
**Blocking:** Staging deployment

#### Priority Order:
1. **C1: Fix environment file integration** (4h) - Enables multi-env
2. **C8: Fix Makefile ENV_FILE usage** (1h) - Enables multi-env
3. **C9: Add health check start_period** (1h) - Reduces false failures
4. **C12: Add secrets validation script** (2h) - Fail fast on bad config

#### Deliverables:
- [ ] Service `.env` files loaded via `env_file:` directive
- [ ] Makefile passes `--env-file` to all compose commands
- [ ] All health checks have appropriate `start_period`
- [ ] `scripts/validate-env.sh` validates all required variables
- [ ] `scripts/generate-secrets.sh` generates strong secrets
- [ ] Documentation updated with correct multi-env workflow

#### Acceptance Criteria:
```bash
# Multi-environment works
ENV_FILE=.env.staging make up
docker exec arc_postgres env | grep POSTGRES_PASSWORD
# Should show staging-specific password

# Health checks stable
make up && sleep 30 && make health-all
# All services healthy without false failures

# Validation works
./scripts/validate-env.sh
# Detects missing/weak secrets
```

---

### PHASE 3: MEDIUM-PRIORITY IMPROVEMENTS (Before Production)
**Estimated Time:** 15 hours  
**Blocking:** Production deployment

#### Priority Order:
1. **C13: Configure TLS/SSL** (3h) - Data security
2. **C15: Add Prometheus alerting** (3h) - Operational visibility
3. **C14: Automated backups** (2h) - Data protection
4. **C11: Pin Infisical version** (0.5h) - Quick fix
5. **C16: Network segmentation** (2h) - Defense in depth
6. **C17: Remove unnecessary ports** (1h) - Attack surface
7. **C18: CI/CD pipeline** (4h) - Automation

#### Deliverables:
- [ ] Traefik TLS termination with Let's Encrypt
- [ ] Prometheus alerting rules for critical services
- [ ] Automated daily backups with retention policy
- [ ] Infisical pinned to specific version
- [ ] Network segmentation (frontend/backend/data)
- [ ] Production compose overlay without unnecessary ports
- [ ] GitHub Actions CI/CD workflow

---

## IMPLEMENTATION ROADMAP

```
Week 1: Critical Security Hardening
├── Day 1-2: Remove weak passwords, fix secrets (C2, C3, C4)
├── Day 3: Secure Traefik, add resource limits (C6, C5)
└── Day 4-5: Log rotation, remove debug exporter (C7, C10)
    └── ✅ Checkpoint: Security audit ready

Week 2: Configuration & Multi-Environment
├── Day 1-2: Fix env file integration (C1, C8)
├── Day 3: Health check improvements (C9)
└── Day 4-5: Validation scripts, documentation (C12)
    └── ✅ Checkpoint: Staging deployment ready

Week 3-4: Production Hardening
├── Week 3 Days 1-2: TLS configuration (C13)
├── Week 3 Days 3-5: Monitoring/alerting (C15)
├── Week 4 Days 1-2: Backups & DR (C14)
└── Week 4 Days 3-5: Network hardening, CI/CD (C16, C17, C18)
    └── ✅ Checkpoint: Production deployment ready
```

---

## SUCCESS CRITERIA

### Minimum Viable Security (Phase 1 Complete)
- [ ] No weak default passwords exist
- [ ] No hardcoded secrets in repository
- [ ] Traefik dashboard requires authentication
- [ ] All services have resource limits
- [ ] Container logs rotate automatically
- [ ] No debug output in production pipelines

### Staging Ready (Phase 2 Complete)
- [ ] Multi-environment deployment works
- [ ] Health checks stable (no false failures)
- [ ] Secrets validation prevents bad configs
- [ ] Documentation accurate and complete

### Production Ready (Phase 3 Complete)
- [ ] TLS/SSL enabled on all public endpoints
- [ ] Alerting configured and tested
- [ ] Automated backups with verified restoration
- [ ] Network segmentation implemented
- [ ] CI/CD pipeline functional
- [ ] Security audit passed
- [ ] Load testing completed
- [ ] Disaster recovery tested

---

## ESTIMATED EFFORT SUMMARY

| Phase | Hours | Priority | Blocking |
|-------|-------|----------|----------|
| **Phase 1: Critical Security** | 10.5 | 🔴 CRITICAL | Any deployment |
| **Phase 2: Configuration & Multi-Env** | 8 | 🟡 HIGH | Staging |
| **Phase 3: Production Hardening** | 15 | 🟢 MEDIUM | Production |
| **Total** | **33.5 hours** | | |

**Timeline:**
- Phase 1: 1 week (full-time) or 2 weeks (part-time)
- Phase 2: 1 week
- Phase 3: 2 weeks
- **Total: 3-4 weeks** to production-ready

---

## RISK ASSESSMENT

### If Phase 1 Not Completed:
- 🔴 **SEVERE RISK** - Data breach likely
- 🔴 System crashes probable (OOM)
- 🔴 Cannot pass security audit
- ❌ **DO NOT DEPLOY**

### If Phase 2 Not Completed:
- 🟡 **MEDIUM RISK** - Can deploy to staging with manual config management
- ⚠️ Multi-environment workflow broken
- ⚠️ Higher operational burden

### If Phase 3 Not Completed:
- 🟢 **LOW RISK** - Can deploy to production but with manual processes
- ⚠️ No TLS (acceptable on private networks)
- ⚠️ No automated alerting (manual monitoring required)
- ⚠️ Manual backups required

---

## CONCLUSION

The A.R.C. Platform Spike **has not progressed** since the 0811 analysis. The majority of critical concerns remain unresolved. However, the platform remains an **excellent technical reference** and is **suitable for local development**.

**Immediate Actions Required:**
1. ✅ Begin Phase 1 immediately (10.5 hours)
2. ✅ Complete security hardening before ANY deployment
3. ✅ Do NOT deploy to staging/production until Phase 1 complete
4. ✅ Allocate 3-4 weeks for full production readiness

**With focused effort, this platform CAN be production-ready.**

---

**Report Generated:** November 9, 2025  
**Next Review:** November 16, 2025 (weekly cadence)  
**Status:** Awaiting approval to begin Phase 1 implementation

---

*This concerns report is based on the Repository Analysis Framework v1.0*

