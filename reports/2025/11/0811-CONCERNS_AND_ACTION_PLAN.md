# A.R.C. Platform Spike - Concerns & Action Plan

**Created:** November 8, 2025  
**Status:** Ready for Implementation  
**Total Issues:** 16 | **High Priority:** 5 | **Medium Priority:** 5 | **Low Priority:** 6

---

## CONCERNS INVENTORY

### 🔴 CRITICAL CONCERNS (Blocking Production)

#### C1: Environment File Integration Broken
**Severity:** 🔴 CRITICAL  
**Category:** Configuration Management  
**Current State:**
- Service-level `.env` files exist but are **never loaded** by docker-compose
- Only root `.env` file is used
- Multi-environment deployments don't work as documented
- No way to isolate secrets per-service

**Impact:**
- Cannot deploy multiple environments (dev, staging, prod)
- Secrets cannot be separated by service
- OPERATIONS.md documentation is misleading

**Files Affected:**
- `docker-compose.yml`
- `docker-compose.stack.yml`
- `Makefile`
- All `config/*/env.example` files

**Solution Approach:** Add `env_file` directives to each service

---

#### C2: Weak Password Defaults
**Severity:** 🔴 CRITICAL  
**Category:** Security  
**Current State:**
```yaml
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}  # ⚠️ Defaults to 'postgres'
POSTGRES_USER: ${POSTGRES_USER:-arc}              # Weak default
```

**Impact:**
- Security vulnerability in any deployment using defaults
- Fails production security audit
- Database easily compromised in exposed deployments

**Files Affected:**
- `docker-compose.stack.yml` (postgres service)

**Solution Approach:** Remove fallback defaults, require explicit values

---

#### C3: Image Tags Not Pinned
**Severity:** 🔴 CRITICAL  
**Category:** Reproducibility & Stability  
**Current State:**
- All images use `latest` tag
- Non-deterministic deployments
- Breaking changes possible without warning

```yaml
loki: image: grafana/loki:latest
prometheus: image: prom/prometheus:latest
jaeger: image: jaegertracing/all-in-one:latest
grafana: image: grafana/grafana:latest
```

**Impact:**
- Different deployments may use different versions
- Security updates bypass change control
- Impossible to reproduce issues across environments
- Staging/prod may differ from dev unexpectedly

**Files Affected:**
- `docker-compose.yml` (6 services)
- `docker-compose.stack.yml` (9 services)

**Solution Approach:** Pin all image versions, make versions configurable via .env

---

#### C4: No Resource Limits Defined
**Severity:** 🔴 CRITICAL  
**Category:** Operations/Reliability  
**Current State:**
- No `deploy.resources.limits` or `deploy.resources.reservations`
- Services can consume unlimited memory/CPU
- Jaeger in-memory storage unbounded

**Impact:**
- Out-of-memory (OOM) crashes in production
- Resource contention unpredictable
- No graceful degradation
- System instability under load

**Files Affected:**
- `docker-compose.yml` (all services)
- `docker-compose.stack.yml` (all services)

**Solution Approach:** Define limits and reservations for each service

---

#### C5: ENV_FILE Makefile Variable Not Used
**Severity:** 🔴 CRITICAL  
**Category:** Configuration Management  
**Current State:**
```makefile
ENV_FILE ?= .env
# Variable defined but never used in commands
$(COMPOSE_BASE) up -d --build  # Doesn't use $ENV_FILE
```

**Impact:**
- Cannot switch between environments via `ENV_FILE=.env.dev make up`
- Multi-environment workflow broken
- Documentation claims feature that doesn't work

**Files Affected:**
- `Makefile`

**Solution Approach:** Update all docker-compose commands to use `--env-file` flag

---

### 🟡 HIGH-PRIORITY CONCERNS (Recommended Before Staging)

#### C6: Empty Service `.env` Files
**Severity:** 🟡 HIGH  
**Category:** Configuration Clarity  
**Current State:**
- 9 empty `.env.example` files in `config/*/`
- Creates confusion about configuration
- Not integrated anyway (C1)

**Files Affected:**
- `config/postgres/.env.example`
- `config/redis/.env.example`
- `config/nats/.env.example`
- `config/otel-collector/.env.example`
- `config/prometheus/.env.example`
- `config/jaeger/.env.example`
- `config/grafana/.env.example`
- `config/pulsar/.env.example`
- `config/unleash/.env.example`
- `config/loki/.env.example` (partially filled)
- `config/kratos/.env.example` (partially filled)
- `config/traefik/.env.example` (partially filled)

**Solution Approach:** Decide: populate or delete (recommend populate)

---

#### C7: Inconsistent Health Check Configuration
**Severity:** 🟡 HIGH  
**Category:** Reliability  
**Current State:**
- Health checks have inconsistent timing
- No `start_period` defined (checks start immediately)
- Some services fail health checks during startup

```yaml
loki:
  healthcheck:
    interval: 10s
    timeout: 5s
    retries: 5
    # Missing: start_period

otel-collector:
  healthcheck:
    interval: 5s
    timeout: 3s
    retries: 10
```

**Impact:**
- Services marked unhealthy during normal startup
- `depends_on` with `condition: service_healthy` may timeout
- Race conditions in service boot sequence

**Files Affected:**
- `docker-compose.yml` (all services)
- `docker-compose.stack.yml` (all services)

**Solution Approach:** Standardize health checks with `start_period: 10s`

---

#### C8: Debug OTEL Exporter Enabled
**Severity:** 🟡 HIGH  
**Category:** Performance/Noise  
**Current State:**
```yaml
exporters:
  debug:
    verbosity: detailed  # Outputs ALL telemetry to console
```

**Impact:**
- Massive console output in production
- Performance impact from verbose logging
- Logs become difficult to read
- Security risk (telemetry exposed in logs)

**Files Affected:**
- `config/otel-collector-config.yml`

**Solution Approach:** Move to development-only profile or remove

---

#### C9: Insecure Traefik Dashboard
**Severity:** 🟡 HIGH  
**Category:** Security  
**Current State:**
```yaml
traefik:
  command:
    - "--api.insecure=true"  # ⚠️ Exposes dashboard without auth
```

**Impact:**
- Dashboard accessible to anyone with network access
- Management API exposed
- Configuration changes possible without authentication

**Files Affected:**
- `docker-compose.stack.yml`

**Solution Approach:** Make configurable via environment variable

---

#### C10: No Container Logging Configuration
**Severity:** 🟡 HIGH  
**Category:** Operations  
**Current State:**
- No logging driver specified
- Logs use default `json-file` driver
- No rotation configured
- Can fill disk with logs

**Impact:**
- Disk space exhaustion from container logs
- No log aggregation setup
- Operational burden

**Files Affected:**
- `docker-compose.yml`
- `docker-compose.stack.yml`

**Solution Approach:** Add `logging` config to all services

---

### 🟢 MEDIUM-PRIORITY CONCERNS (Nice to Have, Improves DX)

#### C11: No Environment Variable Validation
**Severity:** 🟢 MEDIUM  
**Category:** Developer Experience  
**Current State:**
- No validation of required environment variables
- Bad configs silently pass
- Failures happen at runtime

**Impact:**
- Difficult to debug configuration errors
- Operators waste time troubleshooting bad configs

**Solution Approach:** Create validation script

---

#### C12: Single Bridge Network (No Segmentation)
**Severity:** 🟢 MEDIUM  
**Category:** Network Security  
**Current State:**
- All services on `arc_net` bridge network
- No network isolation between layers

**Impact:**
- Observability services can directly reach app services (and vice versa)
- No defense-in-depth for security

**Solution Approach:** Create separate networks for layers (optional for spike)

---

#### C13: All Ports Exposed for Local Development
**Severity:** 🟢 MEDIUM  
**Category:** Security  
**Current State:**
- All service ports mapped to localhost
- Internal services exposed unnecessarily
- Works fine for local dev, problematic for remote

**Impact:**
- Security misconfiguration for remote deployments
- Prometheus/Loki accessible from outside

**Solution Approach:** Document which ports are public vs. internal

---

#### C14: Jaeger In-Memory Storage
**Severity:** 🟢 MEDIUM  
**Category:** Data Persistence  
**Current State:**
```yaml
jaeger:
  environment:
    - SPAN_STORAGE_TYPE=memory  # Loses data on restart
```

**Impact:**
- Trace data lost when container stops
- Unacceptable for production
- OK for dev/staging

**Solution Approach:** Switch to persistent backend for production

---

#### C15: No .gitignore Protection for Secrets
**Severity:** 🟢 MEDIUM  
**Category:** Security  
**Current State:**
- `.env` files could be committed to git
- `.gitignore` may not exclude them

**Impact:**
- Accidental commit of secrets
- Credentials exposed in repository history

**Solution Approach:** Add/verify `.gitignore` entries

---

#### C16: Kratos Database Migrations Manual
**Severity:** 🟢 MEDIUM  
**Category:** Operational Complexity  
**Current State:**
- Kratos migrations not automated
- Manual intervention required

**Impact:**
- Operator must remember to run migrations
- Error-prone deployment procedure

**Solution Approach:** Add automatic migration in Makefile

---

## SOLUTION PLAN

### PHASE 1: CRITICAL FIXES (Required for Any Production Use)
**Estimated Time:** 6-8 hours  
**Blocking Issues:** All deployments until complete

#### Step 1.1: Fix Environment File Integration
**Concern:** C1  
**Task:** Add `env_file` directives to docker-compose services

**Deliverables:**
- [ ] Update `docker-compose.yml` with `env_file` for all services
- [ ] Update `docker-compose.stack.yml` with `env_file` for all services
- [ ] Update Makefile to use `--env-file` flag
- [ ] Create/populate all `config/*/env.example` files
- [ ] Update OPERATIONS.md with correct multi-env instructions
- [ ] Test: `ENV_FILE=.env.dev make up` works

**Files to Modify:**
1. `docker-compose.yml`
2. `docker-compose.stack.yml`
3. `Makefile`
4. `config/postgres/.env.example`
5. `config/redis/.env.example`
6. `config/nats/.env.example`
7. `config/otel-collector/.env.example`
8. `config/prometheus/.env.example`
9. `config/jaeger/.env.example`
10. `config/grafana/.env.example`
11. `config/pulsar/.env.example`
12. `config/unleash/.env.example`
13. `config/loki/.env.example`
14. `config/kratos/.env.example`
15. `config/traefik/.env.example`
16. `.env.example` (root)
17. `OPERATIONS.md`

**Acceptance Criteria:**
```bash
# Should work:
cp .env.example .env.prod
ENV_FILE=.env.prod make up
make health-all  # All services healthy

# Per-service config isolation:
grep -r "POSTGRES_PASSWORD" config/postgres/.env
```

---

#### Step 1.2: Remove Weak Password Defaults
**Concern:** C2  
**Task:** Make all credentials required (no fallbacks)

**Deliverables:**
- [ ] Remove `${VAR:-default}` fallbacks for secrets in compose
- [ ] Update `.env.example` with strong defaults or placeholders
- [ ] Document required credentials in README.md

**Files to Modify:**
1. `docker-compose.stack.yml` (postgres)

**Changes:**
```yaml
# BEFORE:
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}

# AFTER:
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}  # Required, no fallback
```

**Acceptance Criteria:**
```bash
# Should fail if .env is missing:
unset POSTGRES_PASSWORD
make up  # Should error or prompt for value
```

---

#### Step 1.3: Pin All Image Versions
**Concern:** C3  
**Task:** Replace `latest` tags with specific versions

**Deliverables:**
- [ ] Create list of current image versions
- [ ] Pin all images in compose files
- [ ] Make versions overridable via `.env`
- [ ] Document version pinning strategy

**Files to Modify:**
1. `docker-compose.yml` (loki, prometheus, jaeger, grafana, otel-collector, swiss-army-go)
2. `docker-compose.stack.yml` (postgres, redis, nats, pulsar, kratos, unleash, infisical, traefik)
3. `.env.example` (add version overrides)
4. `README.md` (document strategy)

**Example Changes:**
```yaml
# BEFORE:
loki:
  image: grafana/loki:latest

# AFTER:
loki:
  image: grafana/loki:${LOKI_VERSION:-2.9.0}

# In .env.example:
LOKI_VERSION=2.9.0
```

**Acceptance Criteria:**
```bash
# No 'latest' tags remain:
grep -r "latest" docker-compose*.yml | wc -l  # Should be 0

# Version override works:
LOKI_VERSION=2.8.0 docker compose config | grep loki
```

---

#### Step 1.4: Add Resource Limits
**Concern:** C4  
**Task:** Define CPU and memory limits for all services

**Deliverables:**
- [ ] Define resource limits for all services
- [ ] Make limits configurable via `.env`
- [ ] Document resource requirements

**Files to Modify:**
1. `docker-compose.yml`
2. `docker-compose.stack.yml`
3. `.env.example`

**Resource Allocation Plan:**
```
Observability Stack (dev):
  loki: 0.5 CPU, 512MB
  prometheus: 1 CPU, 1GB
  jaeger: 1 CPU, 512MB
  grafana: 0.5 CPU, 256MB
  otel-collector: 0.5 CPU, 256MB

Platform Stack (dev):
  postgres: 1 CPU, 1GB
  redis: 0.25 CPU, 256MB
  nats: 0.25 CPU, 128MB
  pulsar: 2 CPU, 1GB
  kratos: 0.25 CPU, 256MB
  unleash: 0.5 CPU, 256MB
  infisical: 0.5 CPU, 256MB
  traefik: 0.25 CPU, 128MB
```

**Acceptance Criteria:**
```bash
# Resource limits defined:
docker compose config | grep -A2 "resources:"

# Can customize via env:
MAX_MEMORY_POSTGRES=2G docker compose config | grep memory
```

---

#### Step 1.5: Fix Makefile ENV_FILE Integration
**Concern:** C5  
**Task:** Use `--env-file` flag in docker-compose commands

**Deliverables:**
- [ ] Update all `docker-compose` commands to use `--env-file`
- [ ] Support multi-environment via `ENV_FILE` variable
- [ ] Test multi-env workflow

**Files to Modify:**
1. `Makefile`

**Changes:**
```makefile
# BEFORE:
up: env-check
	$(COMPOSE_BASE) up -d --build

# AFTER:
up: env-check
	$(COMPOSE_BASE) --env-file $(ENV_FILE) up -d --build
```

**Acceptance Criteria:**
```bash
# Multi-env works:
ENV_FILE=.env.dev make up
ENV_FILE=.env.prod make restart

# Default .env still works:
make up
```

---

### PHASE 2: HIGH-PRIORITY FIXES (Before Staging Deployment)
**Estimated Time:** 4-5 hours  
**Blocking Staging:** Yes

#### Step 2.1: Standardize Health Checks
**Concern:** C7  
**Task:** Add consistent health check configuration with `start_period`

**Deliverables:**
- [ ] Add `start_period: 10s` to all health checks
- [ ] Standardize intervals and timeouts
- [ ] Document health check strategy

**Files to Modify:**
1. `docker-compose.yml`
2. `docker-compose.stack.yml`

**Standard Template:**
```yaml
healthcheck:
  test: ["CMD", "check_command"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 10s
```

**Acceptance Criteria:**
```bash
# All services become healthy:
make health-all  # All ✓
```

---

#### Step 2.2: Remove Debug OTEL Exporter
**Concern:** C8  
**Task:** Move debug exporter to development-only or remove

**Deliverables:**
- [ ] Create separate otel-collector-config.dev.yml (if keeping)
- [ ] Remove from production config
- [ ] Document debug mode enablement

**Files to Modify:**
1. `config/otel-collector-config.yml`
2. `docker-compose.yml` (optionally)

**Acceptance Criteria:**
```bash
# Debug exporter not in config:
grep -c "debug:" config/otel-collector-config.yml  # Should be 0 or in dev file
```

---

#### Step 2.3: Secure Traefik Dashboard
**Concern:** C9  
**Task:** Make dashboard security configurable

**Deliverables:**
- [ ] Make `--api.insecure` configurable via env
- [ ] Update `.env.example` with secure default

**Files to Modify:**
1. `docker-compose.stack.yml`
2. `.env.example`

**Changes:**
```yaml
# docker-compose.stack.yml
traefik:
  environment:
    - TRAEFIK_API_INSECURE=${TRAEFIK_API_INSECURE:-false}
  command:
    - "--api.insecure=${TRAEFIK_API_INSECURE}"

# .env.example
TRAEFIK_API_INSECURE=false  # Set to true only for local dev
```

**Acceptance Criteria:**
```bash
# Dashboard is secure by default:
grep "api.insecure" docker-compose.stack.yml | grep -v example
# Should show: ${TRAEFIK_API_INSECURE}
```

---

#### Step 2.4: Add Container Logging Configuration
**Concern:** C10  
**Task:** Configure logging drivers to prevent disk bloat

**Deliverables:**
- [ ] Add logging driver config to all services
- [ ] Set appropriate log rotation limits
- [ ] Make logging configurable

**Files to Modify:**
1. `docker-compose.yml`
2. `docker-compose.stack.yml`

**Standard Template:**
```yaml
services:
  loki:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Acceptance Criteria:**
```bash
# Logging configured:
docker compose config | grep -A3 "logging:"
```

---

#### Step 2.5: Create Environment Validation Script
**Concern:** C11  
**Task:** Add validation for required environment variables

**Deliverables:**
- [ ] Create `scripts/validate-env.sh`
- [ ] Integrate into Makefile
- [ ] Document required variables

**Files to Create:**
1. `scripts/validate-env.sh`

**Files to Modify:**
1. `Makefile` (call validation)

**Script Template:**
```bash
#!/bin/bash
REQUIRED_VARS=("POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_DB")
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "ERROR: Required variable $var not set"
    exit 1
  fi
done
echo "✓ Environment validation passed"
```

**Acceptance Criteria:**
```bash
# Validation runs before up:
make up  # Should validate first
```

---

### PHASE 3: MEDIUM-PRIORITY FIXES (Enhancement)
**Estimated Time:** 2-3 hours  
**Can Be Done:** Post-initial-launch

#### Step 3.1: Populate Service Configuration Files
**Concern:** C6  
**Task:** Populate or delete empty service `.env.example` files

**Deliverables:**
- [ ] Decide on strategy (populate or delete)
- [ ] Implement consistently

**Files to Modify:**
- All empty `config/*/.env.example` files

---

#### Step 3.2: Separate Network Layers
**Concern:** C12  
**Task:** Create separate networks for security layering (optional)

**Deliverables:**
- [ ] Create `observability` network
- [ ] Create `platform` network
- [ ] Document network boundaries

**Files to Modify:**
1. `docker-compose.yml` (add networks)
2. `docker-compose.stack.yml` (add networks)

---

#### Step 3.3: Document Port Exposure Strategy
**Concern:** C13  
**Task:** Clarify which ports are public vs. internal

**Deliverables:**
- [ ] Create `NETWORKING.md`
- [ ] Document port mapping strategy
- [ ] Provide production port recommendations

**Files to Create:**
1. `docs/NETWORKING.md`

---

#### Step 3.4: Add .gitignore Protection
**Concern:** C15  
**Task:** Ensure secrets are not committed

**Deliverables:**
- [ ] Verify/update `.gitignore`
- [ ] Document secret management

**Files to Modify:**
1. `.gitignore`

---

#### Step 3.5: Automate Kratos Migrations
**Concern:** C16  
**Task:** Add automatic Kratos DB migrations

**Deliverables:**
- [ ] Add migration target to Makefile
- [ ] Run automatically on deploy

**Files to Modify:**
1. `Makefile`

---

## IMPLEMENTATION ROADMAP

```
PHASE 1 (Days 1-2): CRITICAL FIXES
├─ 1.1: Fix Environment File Integration ⭐ BIGGEST
├─ 1.2: Remove Weak Password Defaults
├─ 1.3: Pin All Image Versions ⭐ BIGGEST
├─ 1.4: Add Resource Limits
└─ 1.5: Fix Makefile ENV_FILE Integration

↓ TESTING & VALIDATION

PHASE 2 (Day 3): HIGH-PRIORITY FIXES
├─ 2.1: Standardize Health Checks
├─ 2.2: Remove Debug OTEL Exporter
├─ 2.3: Secure Traefik Dashboard
├─ 2.4: Add Container Logging
└─ 2.5: Environment Validation Script

↓ STAGING DEPLOYMENT

PHASE 3 (Day 4+): MEDIUM-PRIORITY ENHANCEMENTS
├─ 3.1: Populate Service Configs
├─ 3.2: Separate Networks (Optional)
├─ 3.3: Document Port Strategy
├─ 3.4: Gitignore Protection
└─ 3.5: Automate Migrations
```

---

## SUCCESS CRITERIA

### After Phase 1 ✅
- [ ] Multi-environment deployments work
- [ ] All images have pinned versions
- [ ] Resource limits defined for all services
- [ ] No weak password defaults
- [ ] Makefile ENV_FILE variable works

### After Phase 2 ✅
- [ ] All health checks consistent
- [ ] No debug noise in production
- [ ] Traefik secure by default
- [ ] Logging won't fill disk
- [ ] Bad configs fail fast

### After Phase 3 ✅
- [ ] Complete configuration clarity
- [ ] Security layering (if implemented)
- [ ] Network documentation
- [ ] Secret protection verified
- [ ] Deployment fully automated

---

## ROLLBACK STRATEGY

Each change is **reversible**:
- Keep backup of original files: `git commit` before each change
- Use feature branches for PHASE 2+
- PHASE 1 changes are **safe** (backwards compatible with .env override)

---

## ESTIMATED EFFORT

| Phase | Hours | Priority |
|-------|-------|----------|
| Phase 1 | 6-8 | 🔴 MUST DO |
| Phase 2 | 4-5 | 🟡 SHOULD DO |
| Phase 3 | 2-3 | 🟢 NICE TO HAVE |
| **Total** | **12-16** | - |

---

## NEXT ACTION

**Ready to begin Phase 1 implementation?**

Approve one or more steps, and I'll:
1. Make all necessary code changes
2. Validate with dry-runs
3. Provide test instructions
4. Document changes

**Recommended Starting Order:**
1. ✅ Step 1.1 (Fix env file integration) - Foundation
2. ✅ Step 1.3 (Pin image versions) - Stability
3. ✅ Step 1.2 (Remove weak defaults) - Security
4. ✅ Step 1.4 (Resource limits) - Operations
5. ✅ Step 1.5 (Makefile fix) - Workflow

Would you like me to proceed with implementing Phase 1?

