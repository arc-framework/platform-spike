# A.R.C. Platform Spike - Concerns & Action Plan

**Created:** December 14, 2025  
**Status:** Ready for Implementation  
**Total Issues:** 16 | **Critical:** 2 | **High:** 6 | **Medium:** 8

---

## CONCERNS INVENTORY

### 🔴 CRITICAL CONCERNS (Blocking Production) - 2 Issues

---

#### C-CRIT-1: Image Versions Using `:latest` Tag

**Category:** Configuration Stability  
**Severity:** 🔴 CRITICAL  
**Priority:** P0 - Must fix before production  
**Effort:** 2 hours

**Current State:**

```yaml
# deployments/docker/docker-compose.core.yml
services:
  arc-heimdall:
    image: ghcr.io/arc-framework/arc-heimdall-gateway:latest # ❌ Unpinned

  arc-oracle:
    image: ghcr.io/arc-framework/arc-oracle-sql:latest # ❌ Unpinned

  arc-sonic:
    image: ghcr.io/arc-framework/arc-sonic-cache:latest # ❌ Unpinned

# Same issue across ALL 17 services
```

**Impact Assessment:**

- **Deployment Risk:** Breaking changes pulled automatically without notice
- **Rollback Difficulty:** Cannot revert to known-good versions
- **Reproducibility:** Different environments may run different versions
- **Compliance:** Fails change management requirements (CAB approvals)
- **Debugging:** Cannot correlate issues with specific versions

**Real-World Scenario:**

```bash
# Developer builds on Monday
docker compose up  # Pulls postgres:latest (v16.0)

# Production deploys on Friday
docker compose up  # Pulls postgres:latest (v16.1) - NEW VERSION
# Breaking schema change causes outage
# Rollback requires identifying correct version manually
```

**Files Affected:**

- `deployments/docker/docker-compose.core.yml` (8 services)
- `deployments/docker/docker-compose.observability.yml` (5 services)
- `deployments/docker/docker-compose.security.yml` (1 service)
- `deployments/docker/docker-compose.services.yml` (4 services)

**Solution Approach:**

**Step 1:** Inventory current versions

```bash
# Get current running versions
docker compose images | awk '{print $1, $2}' > versions.txt

# Example output:
# arc-heimdall-gateway    v3.1.4
# arc-oracle-sql          pg16-v1.2.0
# arc-sonic-cache         7.2.4-alpine
```

**Step 2:** Pin versions in compose files

```yaml
# Before
image: ghcr.io/arc-framework/arc-heimdall-gateway:latest

# After
image: ghcr.io/arc-framework/arc-heimdall-gateway:v3.1.4
```

**Step 3:** Document version matrix

```markdown
# docs/VERSION_MATRIX.md

| Service  | Image                | Current Version | Update Policy            |
| -------- | -------------------- | --------------- | ------------------------ |
| Traefik  | arc-heimdall-gateway | v3.1.4          | Monthly security patches |
| Postgres | arc-oracle-sql       | pg16-v1.2.0     | Quarterly minor releases |
| Redis    | arc-sonic-cache      | 7.2.4-alpine    | Bi-annual major releases |
```

**Step 4:** Create update procedure

```bash
# scripts/update-version.sh
#!/bin/bash
SERVICE=$1
NEW_VERSION=$2

# Update compose file
sed -i "s|${SERVICE}:.*|${SERVICE}:${NEW_VERSION}|g" deployments/docker/*.yml

# Test in dev environment
make up-dev
make health-all

# Document change
echo "$(date): Updated ${SERVICE} to ${NEW_VERSION}" >> CHANGELOG.md
```

**Acceptance Criteria:**

- [ ] All 17 services use pinned versions (no `:latest`)
- [ ] Version matrix documented in `docs/VERSION_MATRIX.md`
- [ ] Update procedure script created (`scripts/update-version.sh`)
- [ ] CHANGELOG.md tracks version changes
- [ ] CI/CD validates no `:latest` tags present

**Testing:**

```bash
# Verify no latest tags
grep -r "image:.*:latest" deployments/docker/*.yml
# Should return no results

# Test pinned deployment
docker compose pull  # Should show specific versions
docker compose up -d
make health-all      # Should pass
```

---

#### C-CRIT-2: No TLS/SSL Configuration

**Category:** Security  
**Severity:** 🔴 CRITICAL  
**Priority:** P0 - Must fix before production  
**Effort:** 4 hours

**Current State:**

```yaml
# deployments/docker/docker-compose.core.yml
arc-heimdall:
  command:
    - '--entrypoints.web.address=:80' # ❌ Plaintext HTTP
    - '--entrypoints.websecure.address=:443' # ✅ Port open, but no certificates
  # NO certificate resolver configured
  # NO TLS certificates mounted
```

**Impact Assessment:**

- **Security:** All traffic (including credentials) transmitted in plaintext
- **Session Hijacking:** Cookies/tokens can be intercepted
- **Compliance:** Fails PCI-DSS, HIPAA, SOC2, ISO27001 requirements
- **Trust:** Browser warnings for insecure connections
- **MITM Attacks:** No protection against man-in-the-middle

**Attack Vector Example:**

```
User Login Flow (Current - INSECURE):
1. Browser → http://grafana.arc.local/login
2. User enters password "SuperSecret123!"
3. POST /login HTTP/1.1
   Content-Type: application/json
   {"username":"admin","password":"SuperSecret123!"}  # ❌ PLAINTEXT

Attacker on same network captures packet and obtains password.
```

**Files Affected:**

- `core/gateway/traefik/traefik.yml`
- `deployments/docker/docker-compose.core.yml`
- `.env.example` (add ACME email)

**Solution Approach:**

**Option A: Let's Encrypt (Production)**

```yaml
# deployments/docker/docker-compose.core.yml
arc-heimdall:
  command:
    - '--certificatesresolvers.letsencrypt.acme.httpchallenge=true'
    - '--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web'
    - '--certificatesresolvers.letsencrypt.acme.email=admin@arc.local'
    - '--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json'
    - '--entrypoints.web.http.redirections.entryPoint.to=websecure'
    - '--entrypoints.web.http.redirections.entryPoint.scheme=https'
  volumes:
    - letsencrypt_data:/letsencrypt

volumes:
  letsencrypt_data:
    name: arc_letsencrypt_data
```

**Option B: Self-Signed Certificates (Development)**

```bash
# scripts/setup/generate-certs.sh
#!/bin/bash
mkdir -p config/certs
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout config/certs/traefik.key \
  -out config/certs/traefik.crt \
  -days 365 \
  -subj "/CN=*.arc.local"

# Update compose
volumes:
  - ./config/certs:/certs:ro

command:
  - "--providers.file.filename=/certs/dynamic.yml"
```

**Option C: External Certificate Provider (Enterprise)**

```yaml
# For AWS ACM, Azure Key Vault, etc.
environment:
  AWS_REGION: us-east-1
  AWS_HOSTED_ZONE_ID: Z1234567890ABC
command:
  - '--certificatesresolvers.route53.acme.dnschallenge=true'
  - '--certificatesresolvers.route53.acme.dnschallenge.provider=route53'
```

**Step-by-Step Implementation (Let's Encrypt):**

**1. Update Traefik Configuration**

```yaml
# core/gateway/traefik/traefik.yml
entryPoints:
  web:
    address: ':80'
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ':443'
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

**2. Update Environment Variables**

```bash
# .env.example
ACME_EMAIL=admin@arc.local  # For Let's Encrypt notifications
DOMAIN=arc.local            # Your domain
```

**3. Add Service Labels**

```yaml
# Example: Grafana with TLS
arc-friday:
  labels:
    - 'traefik.enable=true'
    - 'traefik.http.routers.grafana.rule=Host(`grafana.arc.local`)'
    - 'traefik.http.routers.grafana.entrypoints=websecure'
    - 'traefik.http.routers.grafana.tls.certresolver=letsencrypt'
```

**4. DNS Configuration**

```bash
# Required DNS records
grafana.arc.local     A     <your-server-ip>
prometheus.arc.local  A     <your-server-ip>
jaeger.arc.local      A     <your-server-ip>
```

**Acceptance Criteria:**

- [ ] HTTPS enabled for all public endpoints
- [ ] Automatic HTTP → HTTPS redirect configured
- [ ] Certificate auto-renewal working (test with staging Let's Encrypt)
- [ ] Certificate expiry alerts configured (30 days warning)
- [ ] Documentation updated with DNS requirements
- [ ] Browser shows green padlock (no certificate warnings)

**Testing:**

```bash
# Test HTTP redirect
curl -I http://grafana.arc.local
# Should return 301/302 redirect to https://

# Test HTTPS
curl -k https://grafana.arc.local
# Should return 200 OK

# Validate certificate
openssl s_client -connect grafana.arc.local:443 -servername grafana.arc.local
# Should show valid certificate chain

# Check auto-renewal
docker exec arc-heimdall-gateway cat /letsencrypt/acme.json
# Should contain certificate data
```

**Rollback Plan:**

```bash
# If certificates fail to issue, temporarily disable redirect
docker compose exec arc-heimdall-gateway \
  sed -i 's/redirections/#redirections/' /etc/traefik/traefik.yml

docker compose restart arc-heimdall
```

---

### 🟡 HIGH-PRIORITY CONCERNS - 6 Issues

---

#### C-HIGH-1: Missing .dockerignore Files

**Category:** Build Efficiency  
**Severity:** 🟡 HIGH  
**Priority:** P1  
**Effort:** 2 hours

**Current State:**

```bash
# Only 1 service has .dockerignore
$ find . -name .dockerignore
./services/utilities/raymond/.dockerignore

# All other services include unnecessary files in build context
```

**Impact Assessment:**

- **Build Speed:** 2-5x slower builds (large .git, .venv, node_modules included)
- **Network Bandwidth:** Wasted uploading unnecessary files to Docker daemon
- **Cache Efficiency:** Changes to docs/tests invalidate Docker layer cache
- **Security:** Risk of including .env files or secrets in images

**Example Build Context Bloat:**

```bash
# Without .dockerignore
$ docker build services/arc-sherlock-brain
Sending build context to Docker daemon: 458.2MB  # ❌ Includes .venv, .git, tests

# With .dockerignore
Sending build context to Docker daemon: 12.5MB   # ✅ Only src/, requirements.txt
```

**Files Affected:**

- `services/arc-piper-tts/`
- `services/arc-scarlett-voice/`
- `services/arc-sherlock-brain/`
- `services/utilities/raymond/` (has one, but may need updates)
- `core/persistence/postgres/`
- `core/telemetry/otel-collector/`
- `plugins/security/identity/kratos/`

**Solution Approach:**

**Step 1: Create Root .dockerignore**

```dockerignore
# /Users/dgtalbug/Workspace/arc/platform-spike/.dockerignore
# Global patterns for ALL Docker builds

# Version Control
.git
.github
.gitignore

# Python
__pycache__/
*.py[cod]
*$py.class
.Python
.venv/
venv/
env/
ENV/
.pytest_cache/
.mypy_cache/
.ruff_cache/
*.egg-info/
dist/
build/

# Node.js
node_modules/
npm-debug.log*
yarn-error.log*
.npm/
package-lock.json
yarn.lock

# Go
vendor/
*.o
*.a
*.so

# Environment & Secrets
.env*
!.env.example
.secrets/
*.key
*.pem

# IDE
.vscode/
.idea/
*.swp
*.swo
.DS_Store

# Documentation & Reports
docs/
reports/
*.md
!README.md

# Tests
tests/
test_*.py
*_test.go
*.test

# Logs
*.log
logs/

# Temporary files
*.tmp
*.bak
*.swp
*~

# Docker
.dockerignore
Dockerfile*
docker-compose*.yml
```

**Step 2: Service-Specific .dockerignore**

```dockerignore
# services/arc-sherlock-brain/.dockerignore
# Inherits from root, adds service-specific patterns

# Large model files (download at runtime instead)
models/*.pt
models/*.onnx
models/*.safetensors

# Generated embeddings
data/embeddings/
data/vectors/

# Config examples
config/*.example.yml
```

**Step 3: Validation Script**

```bash
# scripts/validate-dockerignore.sh
#!/bin/bash

echo "Validating .dockerignore coverage..."

# Find all Dockerfiles
find . -name Dockerfile -o -name Dockerfile.* | while read dockerfile; do
    dir=$(dirname "$dockerfile")

    if [ ! -f "$dir/.dockerignore" ] && [ ! -f ".dockerignore" ]; then
        echo "❌ Missing .dockerignore for $dockerfile"
    fi

    # Test build context size
    size=$(docker build --no-cache -f "$dockerfile" "$dir" 2>&1 | grep "Sending build context" | awk '{print $5}')
    echo "Build context: $dockerfile -> $size"
done
```

**Acceptance Criteria:**

- [ ] Root `.dockerignore` created with common patterns
- [ ] All 7 services have service-specific `.dockerignore`
- [ ] Build context sizes reduced by >50%
- [ ] Build times improved by >30%
- [ ] Validation script added to CI/CD
- [ ] Documentation updated

**Testing:**

```bash
# Before
time docker build services/arc-sherlock-brain
# Sending build context: 458.2MB
# real    2m14.523s

# After
time docker build services/arc-sherlock-brain
# Sending build context: 12.5MB
# real    0m38.142s  # ✅ 3x faster
```

---

#### C-HIGH-2: No Container Security Hardening

**Category:** Security  
**Severity:** 🟡 HIGH  
**Priority:** P1  
**Effort:** 8 hours

**Current State:**

```yaml
# No security hardening options applied
services:
  arc-oracle:
    image: postgres:16
    # No read_only
    # No cap_drop
    # No security_opt
    # Runs with default capabilities
```

**Impact Assessment:**

- **Attack Surface:** Containers run with unnecessary privileges
- **Escape Risk:** Writable filesystems allow attacker persistence
- **Lateral Movement:** Compromised container can escalate privileges
- **Compliance:** Fails CIS Docker Benchmark recommendations

**CIS Docker Benchmark Failures:**

- 5.12: Ensure that the host's process namespace is not shared (PASS)
- 5.15: Ensure that the host's UTS namespace is not shared (PASS)
- 5.25: Ensure that the container is restricted from acquiring new privileges (❌ FAIL)
- 5.26: Ensure that container health is checked at runtime (PASS)

**Files Affected:**

- All service definitions in `deployments/docker/*.yml`

**Solution Approach:**

**Phase 1: Read-Only Filesystems (4 hours)**

```yaml
# Template for stateless services
arc-raymond:
  read_only: true
  tmpfs:
    - /tmp
    - /var/run
```

**Per-Service Analysis Required:**

```bash
# Test read-only compatibility
docker run --rm --read-only \
  --tmpfs /tmp \
  --tmpfs /var/run \
  arc/raymond:latest

# If fails, identify writable paths
docker run --rm arc/raymond:latest \
  find / -type d -writable 2>/dev/null
```

**Known Writable Paths by Service:**

```yaml
# Postgres
arc-oracle:
  read_only: true
  tmpfs:
    - /tmp
    - /var/run/postgresql
  volumes:
    - postgres_data:/var/lib/postgresql/data # Persistent data

# Redis
arc-sonic:
  read_only: true
  tmpfs:
    - /tmp
  volumes:
    - redis_data:/data # Persistent data

# Python Services (Sherlock, Scarlett, Piper)
arc-sherlock-brain:
  read_only: true
  tmpfs:
    - /tmp
    - /app/.cache # pip/model cache
```

**Phase 2: Capability Dropping (2 hours)**

```yaml
# Minimal capabilities template
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - CHOWN # For chown operations
  - SETUID # For user switching
  - SETGID # For group switching
  - DAC_OVERRIDE # For file permission overrides
```

**Per-Service Capabilities:**

```yaml
# Postgres (needs CHOWN, SETUID, SETGID, DAC_OVERRIDE)
arc-oracle:
  cap_drop: [ALL]
  cap_add: [CHOWN, SETUID, SETGID, DAC_OVERRIDE]

# Redis (minimal capabilities)
arc-sonic:
  cap_drop: [ALL]
  cap_add: [SETGID, SETUID]

# Application services (no special capabilities)
arc-raymond:
  cap_drop: [ALL]
  # No cap_add needed
```

**Phase 3: Security Options (2 hours)**

```yaml
# Apply to all services
security_opt:
  - no-new-privileges:true # Prevent privilege escalation
  - seccomp:unconfined # Or custom seccomp profile
```

**Custom Seccomp Profile (Advanced):**

```json
// config/seccomp/default.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["read", "write", "open", "close", "stat"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

**Acceptance Criteria:**

- [ ] All stateless services use `read_only: true`
- [ ] All services have `cap_drop: [ALL]` with minimal `cap_add`
- [ ] All services have `security_opt: no-new-privileges:true`
- [ ] Testing confirms services still functional
- [ ] CIS Docker Benchmark score improved to 95%+
- [ ] Documentation of per-service security requirements

**Testing:**

```bash
# Run CIS Docker Benchmark
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  docker/docker-bench-security

# Test individual service
docker compose up arc-oracle
docker exec arc-oracle-sql id
# Should show uid=999(postgres) with limited capabilities
```

---

#### C-HIGH-3: No Backup Automation

**Category:** Data Protection  
**Severity:** 🟡 HIGH  
**Priority:** P1  
**Effort:** 6 hours

**Current State:**

```bash
# Manual backup script exists
scripts/setup/migrate-postgres.sh

# But no automated scheduling
# No backup verification
# No retention policy enforcement
```

**Impact Assessment:**

- **Data Loss Risk:** Manual backups often forgotten
- **RTO Violation:** No tested restore procedure
- **Compliance:** Fails data protection requirements
- **Recovery Confidence:** Unknown if backups are valid

**Files Affected:**

- New file: `deployments/docker/docker-compose.backup.yml`
- New file: `scripts/backup/postgres-backup.sh`
- New file: `scripts/backup/postgres-restore.sh`
- New file: `scripts/backup/verify-backup.sh`

**Solution Approach:**

**Step 1: Automated Backup Service**

```yaml
# deployments/docker/docker-compose.backup.yml
services:
  arc-backup:
    image: postgres:16-alpine
    container_name: arc-backup-cron
    restart: unless-stopped
    environment:
      POSTGRES_HOST: arc-oracle
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      BACKUP_SCHEDULE: '${BACKUP_SCHEDULE:-0 2 * * *}' # 2 AM daily
      BACKUP_RETENTION_DAYS: ${BACKUP_RETENTION_DAYS:-7}
      BACKUP_S3_BUCKET: ${BACKUP_S3_BUCKET:-} # Optional S3 upload
    volumes:
      - ./scripts/backup:/scripts:ro
      - backups:/backups
      - /var/run/docker.sock:/var/run/docker.sock:ro # For exec
    networks:
      - arc_net
    entrypoint: ['/scripts/backup-entrypoint.sh']

volumes:
  backups:
    name: arc_backups
```

**Step 2: Backup Script**

```bash
# scripts/backup/postgres-backup.sh
#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/postgres"
BACKUP_FILE="$BACKUP_DIR/arc_db_$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup..."

# Dump all databases
docker exec arc-oracle-sql pg_dumpall -U arc | gzip > "$BACKUP_FILE"

# Verify backup
if [ -f "$BACKUP_FILE" ]; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "[$(date)] Backup created: $BACKUP_FILE ($SIZE)"

    # Test backup validity
    gunzip -t "$BACKUP_FILE"
    echo "[$(date)] Backup verified: OK"
else
    echo "[$(date)] ERROR: Backup failed!"
    exit 1
fi

# Cleanup old backups (retain last N days)
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +${BACKUP_RETENTION_DAYS} -delete
echo "[$(date)] Old backups cleaned (retention: ${BACKUP_RETENTION_DAYS} days)"

# Optional: Upload to S3
if [ -n "${BACKUP_S3_BUCKET:-}" ]; then
    aws s3 cp "$BACKUP_FILE" "s3://$BACKUP_S3_BUCKET/arc-platform/postgres/"
    echo "[$(date)] Backup uploaded to S3"
fi

echo "[$(date)] Backup complete!"
```

**Step 3: Restore Script**

```bash
# scripts/backup/postgres-restore.sh
#!/bin/bash
set -euo pipefail

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "WARNING: This will REPLACE the current database!"
read -p "Are you sure? (yes/no): " -r
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Restore cancelled"
    exit 0
fi

echo "[$(date)] Stopping dependent services..."
docker compose stop arc-sherlock-brain arc-jarvis arc-fury arc-mystique

echo "[$(date)] Restoring from: $BACKUP_FILE"
gunzip -c "$BACKUP_FILE" | docker exec -i arc-oracle-sql psql -U arc

echo "[$(date)] Restore complete!"
echo "[$(date)] Restarting services..."
docker compose up -d

echo "[$(date)] Verifying database..."
docker exec arc-oracle-sql psql -U arc -c "SELECT version();"

echo "[$(date)] Restore successful!"
```

**Step 4: Backup Verification**

```bash
# scripts/backup/verify-backup.sh
#!/bin/bash
set -euo pipefail

BACKUP_FILE="$1"
TEST_CONTAINER="arc-backup-test"

echo "[$(date)] Testing backup: $BACKUP_FILE"

# Start test Postgres instance
docker run -d --name "$TEST_CONTAINER" \
    -e POSTGRES_PASSWORD=test \
    postgres:16-alpine

sleep 5

# Restore backup to test instance
gunzip -c "$BACKUP_FILE" | docker exec -i "$TEST_CONTAINER" psql -U postgres

# Verify tables exist
TABLES=$(docker exec "$TEST_CONTAINER" psql -U postgres -c "\dt" | wc -l)

# Cleanup
docker rm -f "$TEST_CONTAINER"

if [ "$TABLES" -gt 0 ]; then
    echo "[$(date)] Backup valid: $TABLES tables found"
    exit 0
else
    echo "[$(date)] Backup INVALID: No tables found!"
    exit 1
fi
```

**Step 5: Cron Integration**

```bash
# scripts/backup/backup-entrypoint.sh
#!/bin/sh

# Install cron
apk add --no-cache dcron

# Create crontab
echo "${BACKUP_SCHEDULE} /scripts/postgres-backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

echo "Backup cron scheduled: $BACKUP_SCHEDULE"
crond -f -l 2
```

**Acceptance Criteria:**

- [ ] Daily automated backups running
- [ ] 7-day retention policy enforced
- [ ] Backup verification tests passing
- [ ] Restore procedure tested successfully
- [ ] S3 upload optional but working
- [ ] Monitoring alerts for backup failures
- [ ] Documentation for restore procedure

**Testing:**

```bash
# Test manual backup
./scripts/backup/postgres-backup.sh
# Should create backup in backups/postgres/

# Test restore
./scripts/backup/postgres-restore.sh backups/postgres/arc_db_20251214_020000.sql.gz
# Should restore database

# Test verification
./scripts/backup/verify-backup.sh backups/postgres/arc_db_20251214_020000.sql.gz
# Should return exit 0

# Test cron schedule
docker logs -f arc-backup-cron
# Should show backup running at scheduled time
```

---

#### C-HIGH-4: No Prometheus AlertManager

**Category:** Operational Visibility  
**Severity:** 🟡 HIGH  
**Priority:** P1  
**Effort:** 2 hours

**Current State:**

```yaml
# Prometheus collects metrics
arc-house:
  image: prometheus:latest
  # But no AlertManager configured
  # No alert rules defined
  # No notification channels
```

**Impact Assessment:**

- **Incident Detection:** Manual monitoring required
- **Response Time:** Delays in detecting outages
- **SLA Risk:** Cannot meet uptime commitments
- **On-Call:** No automated alerting for escalation

**Solution Approach:**

**Step 1: Add AlertManager Service**

```yaml
# deployments/docker/docker-compose.observability.yml
services:
  arc-alertmanager:
    image: prom/alertmanager:v0.27.0
    container_name: arc-alertmanager
    hostname: arc-alertmanager
    restart: unless-stopped
    command:
      - '--config.file=/etc/alertmanager/config.yml'
      - '--storage.path=/alertmanager'
    volumes:
      - ./config/alertmanager.yml:/etc/alertmanager/config.yml:ro
      - alertmanager_data:/alertmanager
    ports:
      - '9093:9093'
    networks:
      - arc_net
    healthcheck:
      test: ['CMD', 'wget', '--spider', 'http://localhost:9093/-/healthy']
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  alertmanager_data:
    name: arc_alertmanager_data
```

**Step 2: AlertManager Configuration**

```yaml
# config/alertmanager.yml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack-critical'
  routes:
    - match:
        severity: critical
      receiver: 'slack-critical'
      continue: true
    - match:
        severity: warning
      receiver: 'slack-warnings'

receivers:
  - name: 'slack-critical'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#arc-platform-alerts'
        title: '🔴 [CRITICAL] {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'slack-warnings'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#arc-platform-warnings'
        title: '🟡 [WARNING] {{ .GroupLabels.alertname }}'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: '${PAGERDUTY_SERVICE_KEY}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
```

**Step 3: Prometheus Alert Rules**

```yaml
# config/prometheus/alerts.yml
groups:
  - name: arc_platform_alerts
    interval: 30s
    rules:
      # Service Availability
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: 'Service {{ $labels.job }} is down'
          description: '{{ $labels.instance }} has been down for more than 1 minute'
          runbook_url: 'https://wiki.arc.local/runbooks/service-down'

      # High CPU Usage
      - alert: HighCPUUsage
        expr: (100 - (avg by (instance) (rate(process_cpu_seconds_total[5m])) * 100)) < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: 'High CPU usage on {{ $labels.instance }}'
          description: 'CPU usage is above 90% for 5 minutes'

      # High Memory Usage
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: 'High memory usage on {{ $labels.instance }}'

      # Database Connection Pool Exhaustion
      - alert: PostgresConnectionPoolExhausted
        expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.8
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: 'Postgres connection pool near limit'
          description: '{{ $value | humanizePercentage }} connections in use'

      # Disk Space Low
      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: 'Disk space low on {{ $labels.instance }}'
          description: 'Only {{ $value | humanizePercentage }} disk space remaining'

      # Container Restarts
      - alert: ContainerRestarting
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: 'Container {{ $labels.container }} restarting'
          description: 'Container has restarted {{ $value }} times in 15 minutes'
```

**Step 4: Update Prometheus Config**

```yaml
# config/prometheus/prometheus.yml
global:
  evaluation_interval: 30s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['arc-alertmanager:9093']

rule_files:
  - '/etc/prometheus/alerts.yml'
```

**Acceptance Criteria:**

- [ ] AlertManager deployed and healthy
- [ ] 6+ alert rules configured (service down, CPU, memory, disk, connections, restarts)
- [ ] Slack integration working
- [ ] Test alerts firing and resolving correctly
- [ ] Runbook links in all alerts
- [ ] On-call rotation documented

**Testing:**

```bash
# Test alert firing
docker compose stop arc-oracle

# Check Prometheus UI
open http://localhost:9090/alerts
# Should show "ServiceDown" alert pending → firing

# Check AlertManager UI
open http://localhost:9093
# Should show active alert

# Check Slack
# Should receive notification in #arc-platform-alerts

# Resolve alert
docker compose start arc-oracle

# Verify resolution notification sent
```

---

#### C-HIGH-5: Missing CI/CD Validation Pipeline

**Category:** Quality Assurance  
**Severity:** 🟡 HIGH  
**Priority:** P1  
**Effort:** 6 hours

**Current State:**

```bash
# No automated validation
# No GitHub Actions workflows
# No pre-commit hooks
# Manual testing only
```

**Impact Assessment:**

- **Quality Risk:** Broken configs deployed to production
- **Security Risk:** Secrets accidentally committed
- **Consistency:** YAML syntax errors not caught
- **Regression:** No automated testing of changes

**Solution Approach:**

**Step 1: GitHub Actions Workflow**

```yaml
# .github/workflows/validate.yml
name: Platform Validation

on:
  push:
    branches: [main, develop, 001-realtime-media]
  pull_request:
    branches: [main, develop]

jobs:
  validate-compose:
    name: Validate Docker Compose
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate all compose files
        run: |
          for file in deployments/docker/*.yml; do
            echo "Validating $file..."
            docker compose -f "$file" config --quiet
          done

      - name: Check for latest tags
        run: |
          if grep -r "image:.*:latest" deployments/docker/*.yml; then
            echo "ERROR: Found :latest tags in compose files"
            exit 1
          fi

  lint-yaml:
    name: Lint YAML Files
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install yamllint
        run: pip install yamllint

      - name: Lint all YAML
        run: yamllint -c .yamllint deployments/ config/

  validate-secrets:
    name: Validate Secrets Configuration
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check for hardcoded secrets
        run: |
          if grep -r "password.*:" deployments/docker/*.yml | grep -v "POSTGRES_PASSWORD:"; then
            echo "ERROR: Found hardcoded passwords"
            exit 1
          fi

      - name: Validate .env.example
        run: |
          if grep "CHANGE_ME" .env.example; then
            echo "✅ .env.example contains placeholders (expected)"
          else
            echo "ERROR: .env.example missing placeholders"
            exit 1
          fi

  scan-secrets:
    name: Scan for Leaked Secrets
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: TruffleHog Secret Scanning
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD

  security-scan:
    name: Vulnerability Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build custom images
        run: docker compose -f deployments/docker/docker-compose.services.yml build

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  test-deployment:
    name: Test Deployment
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create test .env
        run: |
          cp .env.example .env
          ./scripts/setup/generate-secrets.sh

      - name: Start minimal profile
        run: make up-minimal

      - name: Wait for services
        run: sleep 30

      - name: Health check
        run: make health-all

      - name: Cleanup
        run: make down
```

**Step 2: YAML Linting Configuration**

```yaml
# .yamllint
---
extends: default

rules:
  line-length:
    max: 120
    level: warning
  indentation:
    spaces: 2
  comments:
    min-spaces-from-content: 1
  truthy:
    allowed-values: ['true', 'false', 'yes', 'no']
```

**Step 3: Pre-Commit Hooks**

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: detect-private-key

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.33.0
    hooks:
      - id: yamllint

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
```

**Step 4: Makefile CI Targets**

```makefile
# Makefile additions
ci-validate:
	@echo "Running CI validation..."
	@docker compose config --quiet
	@./scripts/setup/validate-secrets.sh || true
	@yamllint -c .yamllint deployments/

ci-test:
	@echo "Running integration tests..."
	@make up-minimal
	@sleep 30
	@make health-all
	@make down
```

**Acceptance Criteria:**

- [ ] GitHub Actions workflow configured
- [ ] All validations passing on main branch
- [ ] PR checks enforced (no merge without green CI)
- [ ] Pre-commit hooks installed
- [ ] YAML linting passing
- [ ] Secret scanning integrated
- [ ] Vulnerability scanning in place

---

#### C-HIGH-6: No Network Segmentation

**Category:** Security  
**Severity:** 🟡 HIGH  
**Priority:** P2  
**Effort:** 4 hours

**Current State:**

```yaml
# Single flat network
networks:
  arc_net:
    external: true
# All services can talk to all services
```

**Impact Assessment:**

- **Blast Radius:** Compromised container can access entire infrastructure
- **Lateral Movement:** No network-level isolation
- **Compliance:** Fails zero-trust architecture requirements
- **Data Protection:** Databases exposed to frontend services

**Solution Approach:**

**Multi-Tier Network Architecture:**

```yaml
# deployments/docker/docker-compose.base.yml
networks:
  arc_frontend:
    name: arc_frontend
    driver: bridge
    internal: false # Internet-facing

  arc_application:
    name: arc_application
    driver: bridge
    internal: true # No direct internet access

  arc_data:
    name: arc_data
    driver: bridge
    internal: true # Isolated data layer

  arc_monitoring:
    name: arc_monitoring
    driver: bridge
    internal: true # Observability isolation
```

**Service Network Assignment:**

```yaml
# deployments/docker/docker-compose.core.yml
services:
  # Gateway: Frontend + Application networks
  arc-heimdall:
    networks:
      - arc_frontend
      - arc_application

  # Databases: Data network only
  arc-oracle:
    networks:
      - arc_data

  arc-sonic:
    networks:
      - arc_data

  # Application services: Application + Data
  arc-sherlock-brain:
    networks:
      - arc_application
      - arc_data

  # Observability: Monitoring network + access to all
  arc-widow:
    networks:
      - arc_application
      - arc_data
      - arc_monitoring

  arc-house: # Prometheus
    networks:
      - arc_monitoring
      - arc_application # To scrape metrics
```

**Network Policies (Kubernetes equivalent):**

```yaml
# For future Kubernetes migration
# config/network-policies/database-isolation.yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-isolation
spec:
  podSelector:
    matchLabels:
      arc.service.codename: oracle
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              arc.service.layer: application # Only app layer can access
      ports:
        - protocol: TCP
          port: 5432
```

**Acceptance Criteria:**

- [ ] 4-tier network architecture implemented
- [ ] Data layer isolated from frontend
- [ ] Connectivity matrix documented
- [ ] Network policies ready for K8s migration
- [ ] Security audit validates segmentation

**Testing:**

```bash
# Test isolation
docker exec arc-sherlock-brain ping arc-oracle
# Should succeed (same data network)

docker exec arc-heimdall-gateway ping arc-oracle
# Should fail (different networks)

docker exec arc-oracle ping 8.8.8.8
# Should fail (internal network, no internet)
```

---

### 🟢 MEDIUM-PRIORITY CONCERNS - 8 Issues

_(Summarized for brevity - full details available on request)_

#### C-MED-1: Missing Disaster Recovery Testing

**Effort:** 4h | Restore procedures untested

#### C-MED-2: No Database Replication

**Effort:** 6h | Single Postgres instance (no HA)

#### C-MED-3: No Connection Pooling (PgBouncer)

**Effort:** 3h | Direct Postgres connections (performance)

#### C-MED-4: No mTLS Between Services

**Effort:** 3h | Internal traffic unencrypted

#### C-MED-5: No Integration Test Suite

**Effort:** 2h | Only manual testing

#### C-MED-6: Missing Service-Specific .env Examples

**Effort:** 2h | Distributed config templates incomplete

#### C-MED-7: No Monitoring Dashboard Templates

**Effort:** 3h | Grafana dashboards not pre-configured

#### C-MED-8: No Rate Limiting / DDoS Protection

**Effort:** 2h | Traefik rate limiting not configured

---

## SOLUTION PLAN

### PHASE 1: CRITICAL FIXES (Production Blockers)

**Duration:** 1 week  
**Effort:** 16 hours  
**Deliverables:** Production-ready platform

#### Tasks

**Day 1-2: Configuration Stability**

- [ ] C-CRIT-1: Pin all Docker image versions (2h)
  - Files: All docker-compose.yml files
  - Output: `docs/VERSION_MATRIX.md`, `scripts/update-version.sh`
  - Test: No `:latest` tags remain

**Day 2-3: Security Foundation**

- [ ] C-CRIT-2: Configure TLS/SSL (4h)
  - Files: `traefik.yml`, docker-compose.core.yml
  - Output: Let's Encrypt integration, HTTPS enforced
  - Test: All endpoints use HTTPS

**Day 3-4: Build & Backup**

- [ ] C-HIGH-1: Create .dockerignore files (2h)
  - Files: 7 service directories + root
  - Output: Build contexts reduced by >50%
  - Test: Build time improvements measured
- [ ] C-HIGH-3: Implement backup automation (6h)
  - Files: `docker-compose.backup.yml`, backup scripts
  - Output: Daily backups, 7-day retention, tested restore
  - Test: Full restore cycle completed

**Day 5: Monitoring**

- [ ] C-HIGH-4: Deploy Prometheus AlertManager (2h)
  - Files: `docker-compose.observability.yml`, alert rules
  - Output: 6+ alerts configured, Slack integration
  - Test: Alert firing and resolution verified

#### Success Criteria (Phase 1)

- [ ] All CRITICAL concerns resolved
- [ ] Platform passes security checklist
- [ ] Deployment reproducibility verified
- [ ] Backup/restore tested successfully
- [ ] Monitoring alerts functional

---

### PHASE 2: HIGH-PRIORITY FIXES (Security & Quality)

**Duration:** 1 week  
**Effort:** 20 hours  
**Deliverables:** Hardened, validated platform

#### Tasks

**Day 1-3: Security Hardening**

- [ ] C-HIGH-2: Container security hardening (8h)
  - Read-only filesystems
  - Capability dropping
  - Security options
  - CIS Benchmark compliance

**Day 3-4: Network Isolation**

- [ ] C-HIGH-6: Network segmentation (4h)
  - 4-tier network architecture
  - Data layer isolation
  - Connectivity matrix documentation

**Day 4-5: CI/CD Pipeline**

- [ ] C-HIGH-5: CI/CD validation pipeline (6h)
  - GitHub Actions workflows
  - YAML linting
  - Secret scanning
  - Vulnerability scanning

**Day 5: Testing**

- [ ] C-MED-5: Integration test suite (2h)
  - Service health tests
  - API integration tests
  - Performance benchmarks

#### Success Criteria (Phase 2)

- [ ] CIS Docker Benchmark score >95%
- [ ] All CI/CD checks passing
- [ ] Network isolation verified
- [ ] Security audit passed

---

### PHASE 3: MEDIUM-PRIORITY ENHANCEMENTS (Operational Maturity)

**Duration:** 1 week  
**Effort:** 25 hours  
**Deliverables:** Production-grade operations

#### Tasks

**Day 1-2: High Availability**

- [ ] C-MED-2: Database replication (6h)
  - Postgres primary-replica setup
  - Automatic failover
  - Read scaling
- [ ] C-MED-3: Connection pooling (3h)
  - PgBouncer deployment
  - Connection limit tuning

**Day 3: Security**

- [ ] C-MED-4: mTLS between services (3h)
  - Service certificates
  - Mutual TLS validation

**Day 4: Disaster Recovery**

- [ ] C-MED-1: DR testing (4h)
  - Disaster scenarios
  - Recovery procedures
  - RTO/RPO validation

**Day 5: Observability**

- [ ] C-MED-7: Grafana dashboards (3h)

  - Service health dashboard
  - Resource utilization
  - Business metrics

- [ ] C-MED-8: Rate limiting (2h)

  - Traefik rate limiting
  - DDoS protection

- [ ] C-MED-6: Service .env examples (2h)
  - Complete config templates
  - Migration guides

#### Success Criteria (Phase 3)

- [ ] 99.9% uptime capability
- [ ] Disaster recovery validated
- [ ] Complete observability coverage
- [ ] Production deployment checklist complete

---

## IMPLEMENTATION ROADMAP

```
WEEK 1: Production Blockers (CRITICAL)
│
├─ Day 1-2: Pin image versions, start TLS config
├─ Day 3: Complete TLS, create .dockerignore files
├─ Day 4: Backup automation
└─ Day 5: AlertManager deployment
   ├─ Deliverable: Production-ready platform (85% → 95% ready)
   └─ Gate: Security & deployment checklist passed

WEEK 2: Security & Quality (HIGH PRIORITY)
│
├─ Day 1-3: Container security hardening
├─ Day 3-4: Network segmentation
├─ Day 4-5: CI/CD pipeline + integration tests
   ├─ Deliverable: Hardened, validated platform
   └─ Gate: CIS Benchmark >95%, CI green

WEEK 3: Operational Maturity (MEDIUM PRIORITY)
│
├─ Day 1-2: Database replication + connection pooling
├─ Day 3: mTLS implementation
├─ Day 4: Disaster recovery testing
└─ Day 5: Observability enhancements
   ├─ Deliverable: Production-grade operations
   └─ Gate: HA validated, 99.9% uptime capable
```

---

## SUCCESS CRITERIA

### Definition of Done

**Phase 1 (Production Blockers):**

- [ ] All services use pinned image versions
- [ ] HTTPS enforced on all endpoints (valid certificates)
- [ ] Automated daily backups with tested restore
- [ ] AlertManager sending notifications
- [ ] Build contexts optimized (>50% reduction)

**Phase 2 (Security & Quality):**

- [ ] CIS Docker Benchmark score >95%
- [ ] All containers with read-only filesystems where possible
- [ ] Network segmentation implemented (4 tiers)
- [ ] CI/CD pipeline passing all checks
- [ ] Secret scanning in place (no leaks)

**Phase 3 (Operational Maturity):**

- [ ] Database replication active
- [ ] Connection pooling configured
- [ ] mTLS between services
- [ ] Disaster recovery tested (RTO <1h, RPO <15min)
- [ ] Grafana dashboards deployed
- [ ] Rate limiting configured

### Platform Readiness Scorecard

| Dimension   | Before     | After Phase 1 | After Phase 2 | After Phase 3 | Target   |
| ----------- | ---------- | ------------- | ------------- | ------------- | -------- |
| Security    | 7.0/10     | 8.5/10        | 9.5/10        | 10/10         | 9.5+     |
| Stability   | 7.5/10     | 9.0/10        | 9.5/10        | 10/10         | 9.0+     |
| Operations  | 9.0/10     | 9.5/10        | 10/10         | 10/10         | 9.5+     |
| Quality     | 6.5/10     | 7.5/10        | 9.5/10        | 10/10         | 9.0+     |
| **Overall** | **8.1/10** | **9.0/10**    | **9.5/10**    | **10/10**     | **9.5+** |

### Production Deployment Checklist

**Pre-Deployment:**

- [ ] All CRITICAL and HIGH concerns resolved
- [ ] Security audit passed (external)
- [ ] Load testing completed (1000 req/s sustained)
- [ ] Disaster recovery tested
- [ ] Runbook completed
- [ ] On-call rotation trained

**Deployment:**

- [ ] Blue-green deployment strategy
- [ ] Database migration tested
- [ ] Rollback plan documented
- [ ] Monitoring alerts active
- [ ] Backup verified

**Post-Deployment:**

- [ ] Health checks passing
- [ ] Performance metrics baseline
- [ ] User acceptance testing
- [ ] Incident response drill
- [ ] Post-mortem template ready

---

## ESTIMATED EFFORT

### Breakdown by Phase

| Phase       | Duration | Effort (hours) | Team Size   | Cost (at $100/hr) |
| ----------- | -------- | -------------- | ----------- | ----------------- |
| **Phase 1** | 1 week   | 16             | 2 engineers | $1,600            |
| **Phase 2** | 1 week   | 20             | 2 engineers | $2,000            |
| **Phase 3** | 1 week   | 25             | 2 engineers | $2,500            |
| **TOTAL**   | 3 weeks  | **61 hours**   | 2 engineers | **$6,100**        |

### Breakdown by Concern Severity

| Severity        | Count  | Total Effort | Priority       |
| --------------- | ------ | ------------ | -------------- |
| 🔴 **Critical** | 2      | 6 hours      | P0 (Week 1)    |
| 🟡 **High**     | 6      | 30 hours     | P1 (Weeks 1-2) |
| 🟢 **Medium**   | 8      | 25 hours     | P2 (Week 3)    |
| **TOTAL**       | **16** | **61 hours** | 3 weeks        |

### Resource Requirements

**Team Composition:**

- 1x Senior DevOps Engineer (security, infrastructure)
- 1x Platform Engineer (automation, monitoring)
- 0.5x Security Specialist (audit, validation) - Phase 2 only

**Infrastructure Costs:**

- Development environment: $0 (local Docker)
- Staging environment: ~$200/month (cloud hosting)
- CI/CD minutes: ~$50/month (GitHub Actions)
- Monitoring/alerting: $0 (self-hosted)

**Total Investment:**

- **Labor:** $6,100 (61 hours × $100/hr)
- **Infrastructure:** $250/month
- **One-time setup:** $6,350

**ROI Justification:**

- Prevents data loss incidents ($50K+ per incident)
- Reduces MTTR by 80% (alerts vs manual monitoring)
- Enables compliance certifications (SOC2, ISO27001)
- Improves developer productivity (faster builds, CI/CD)

---

## ROLLBACK STRATEGY

### Phase 1 Rollback

**If TLS configuration fails:**

```bash
# Disable HTTPS redirect, revert to HTTP-only
git revert <commit>
docker compose down
docker compose up -d
```

**If backup automation fails:**

```bash
# Remove backup service, continue manual backups
docker compose -f docker-compose.backup.yml down
# Revert to manual backup script
```

### Phase 2 Rollback

**If container hardening breaks services:**

```bash
# Remove security options incrementally
# Test each service individually
docker compose up -d arc-oracle  # Without read_only
# Once working, add back: read_only: true
```

**If network segmentation causes connectivity issues:**

```bash
# Revert to single network
# Update all services back to arc_net
git revert <network-changes>
docker compose down
docker compose up -d
```

### General Rollback Principles

1. **Git-based:** All changes in version control
2. **Incremental:** Roll back one service at a time
3. **Data safety:** Never roll back database migrations
4. **Monitoring:** Watch metrics during rollback
5. **Communication:** Notify team immediately

---

## RISK ASSESSMENT

### High Risks

| Risk                                     | Probability | Impact   | Mitigation                                       |
| ---------------------------------------- | ----------- | -------- | ------------------------------------------------ |
| TLS misconfiguration breaks services     | Medium      | High     | Test in staging first, have HTTP fallback        |
| Backup restore fails in production       | Low         | Critical | Test restores weekly, maintain multiple backups  |
| Container hardening breaks functionality | Medium      | Medium   | Test each service independently, staged rollout  |
| Network segmentation causes outages      | Low         | High     | Detailed connectivity testing, gradual migration |

### Medium Risks

| Risk                               | Probability | Impact | Mitigation                                   |
| ---------------------------------- | ----------- | ------ | -------------------------------------------- |
| CI/CD pipeline slows development   | Medium      | Medium | Optimize build caching, parallelize jobs     |
| AlertManager creates alert fatigue | Medium      | Low    | Tune thresholds carefully, use grouping      |
| Image pinning breaks auto-updates  | High        | Low    | Document update procedure, quarterly reviews |

### Mitigation Strategies

1. **Staging Environment:** Test all changes in staging first
2. **Incremental Rollout:** Deploy one phase at a time
3. **Monitoring:** Watch metrics during changes
4. **Rollback Plan:** Have revert commits ready
5. **Communication:** Daily standups during implementation

---

## APPENDIX: QUICK REFERENCE

### Command Cheatsheet

```bash
# Phase 1 Commands
./scripts/update-version.sh arc-heimdall v3.1.4  # Pin version
make up-tls                                      # Test HTTPS
./scripts/backup/postgres-backup.sh              # Manual backup
docker logs arc-alertmanager                      # Check alerts

# Phase 2 Commands
docker run --rm docker/docker-bench-security     # CIS audit
make ci-validate                                  # Run CI checks
docker network inspect arc_data                   # Verify isolation

# Phase 3 Commands
./scripts/disaster-recovery/test-restore.sh      # DR drill
docker exec arc-oracle-sql pg_isready             # Check replication
```

### Contact & Escalation

**Primary:** A.R.C. Platform Team  
**Escalation:** Senior DevOps Engineer  
**Security:** Security Team (for audit failures)  
**Emergency:** On-call rotation (PagerDuty)

### Documentation References

- Main Analysis: `reports/1412-ANALYSIS.md`
- Architecture: `docs/architecture/README.md`
- Operations: `docs/OPERATIONS.md`
- Security Fixes: `docs/guides/SECURITY-FIXES.md`
- Version Matrix: `docs/VERSION_MATRIX.md` (to be created)

---

**Report Generated:** December 14, 2025  
**Next Review:** January 15, 2026  
**Status:** Ready for Implementation  
**Approval Required:** Platform Lead, Security Team

---

**END OF CONCERNS & ACTION PLAN**
