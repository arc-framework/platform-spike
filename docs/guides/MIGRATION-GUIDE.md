# Migration Guide: Stabilizing A.R.C. Framework

**Feature:** 002-stabilize-framework  
**Date:** January 10, 2026  
**Status:** Step-by-Step Implementation Plan

---

## Overview

This guide walks you through migrating the A.R.C. platform to standardized Dockerfiles, shared base images, and automated validation.

**Key Principle:** Incremental migration, not "big bang" rewrite.

---

## Pre-Migration Checklist

Before you start:

- [ ] Read `docker-standards.md` (understand the standards)
- [ ] Read `directory-design.md` (understand the structure)
- [ ] Ensure Docker 24.0+ with BuildKit enabled
- [ ] Ensure CI/CD access (GitHub Actions)
- [ ] Back up current `.env` file
- [ ] Coordinate with team (no one else touching Dockerfiles)

---

## Phase 0: Audit Current State (Week 1)

### Step 0.1: Inventory Existing Dockerfiles

**Action:**
```bash
# Find all Dockerfiles
find . -name "Dockerfile" -not -path "*/node_modules/*" | tee dockerfiles.txt

# Current count: 7 Dockerfiles
# - services/arc-sherlock-brain/Dockerfile
# - services/arc-scarlett-voice/Dockerfile
# - services/arc-piper-tts/Dockerfile
# - services/utilities/raymond/Dockerfile
# - plugins/security/identity/kratos/Dockerfile
# - core/persistence/postgres/Dockerfile
# - core/telemetry/otel-collector/Dockerfile
```

**Deliverable:** `dockerfiles.txt` list

### Step 0.2: Run hadolint on All Dockerfiles

**Action:**
```bash
# Install hadolint (if not installed)
brew install hadolint  # macOS
# OR
docker pull hadolint/hadolint

# Lint all Dockerfiles
while read -r dockerfile; do
    echo "=== Linting: $dockerfile ==="
    hadolint "$dockerfile" || true
done < dockerfiles.txt > hadolint-report.txt
```

**Deliverable:** `hadolint-report.txt` with issues

### Step 0.3: Run Security Scans

**Action:**
```bash
# Install trivy (if not installed)
brew install trivy  # macOS

# Build all images (if not already built)
make build

# Scan all arc- images
docker images --format "{{.Repository}}:{{.Tag}}" | grep "^arc-" > images.txt

while read -r image; do
    echo "=== Scanning: $image ==="
    trivy image --severity HIGH,CRITICAL "$image" || true
done < images.txt > security-report.txt
```

**Deliverable:** `security-report.txt` with vulnerabilities

### Step 0.4: Measure Current Image Sizes

**Action:**
```bash
# Get image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "^arc-" > sizes-before.txt
```

**Deliverable:** `sizes-before.txt` baseline

### Step 0.5: Measure Current Build Times

**Action:**
```bash
# Clean build (no cache)
time docker build --no-cache -t arc-sherlock-brain:test services/arc-sherlock-brain/

# Incremental build (code change only)
touch services/arc-sherlock-brain/src/main.py
time docker build -t arc-sherlock-brain:test services/arc-sherlock-brain/

# Record both times
```

**Deliverable:** Build time baselines in `build-times-before.txt`

### Step 0.6: Create Audit Report

**Action:**
Create `specs/002-stabilize-framework/audit-report.md`:

```markdown
# Pre-Migration Audit Report

**Date:** [Today]

## Dockerfile Issues (hadolint)
[Paste hadolint-report.txt findings]

## Security Vulnerabilities (trivy)
[Paste security-report.txt findings]

## Image Sizes (Baseline)
[Paste sizes-before.txt]

## Build Times (Baseline)
[Paste build-times-before.txt]

## Risk Assessment

### HIGH Priority Fixes
- [List HIGH/CRITICAL vulnerabilities]
- [List major hadolint violations]

### MEDIUM Priority Improvements
- [List image size bloat >100MB over target]
- [List build time issues >5 minutes]

### LOW Priority Enhancements
- [List nice-to-have optimizations]
```

**Deliverable:** `audit-report.md` with prioritized issues

---

## Phase 1: Create Base Images (Week 2, Part 1)

### Step 1.1: Create .docker/base/ Directory

**Action:**
```bash
mkdir -p .docker/base/go-infra
mkdir -p .docker/base/python-ai
```

### Step 1.2: Create arc-base-go-infra

**Action:**
Create `.docker/base/go-infra/Dockerfile`:

```dockerfile
# ==============================================================================
# A.R.C. Base Image: Go Infrastructure
# ==============================================================================
FROM golang:1.21-alpine3.19 AS builder

LABEL org.opencontainers.image.title="arc-base-go-infra" \
      org.opencontainers.image.description="Base image for Go infrastructure services" \
      arc.base.language="go" \
      arc.base.version="1.21"

# Install common build dependencies
RUN apk add --no-cache \
    git \
    make \
    ca-certificates \
    tzdata

# ==============================================================================
# Runtime Stage
# ==============================================================================
FROM alpine:3.19

# Install common runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata

# Set timezone
ENV TZ=UTC

# Create standard non-root user (services can use this or create their own)
RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser

# Runtime stage ready for service binaries
WORKDIR /app
```

Create `.docker/base/go-infra/README.md`:

```markdown
# arc-base-go-infra

Base image for Go infrastructure services in A.R.C. platform.

## Usage

```dockerfile
FROM arc-base-go-infra:1.21-alpine3.19 AS builder
# ... your Go build ...

FROM arc-base-go-infra:1.21-alpine3.19
COPY --from=builder /build/app /app
USER arcuser
ENTRYPOINT ["/app"]
```

## Includes
- Go 1.21 (builder stage)
- Alpine 3.19 (runtime stage)
- ca-certificates, tzdata
- Non-root user (arcuser, UID 1000)
```

### Step 1.3: Create arc-base-python-ai

**Action:**
Create `.docker/base/python-ai/Dockerfile`:

```dockerfile
# ==============================================================================
# A.R.C. Base Image: Python AI Services
# ==============================================================================
FROM python:3.11-alpine3.19 AS builder

LABEL org.opencontainers.image.title="arc-base-python-ai" \
      org.opencontainers.image.description="Base image for Python AI/ML services" \
      arc.base.language="python" \
      arc.base.version="3.11"

# Install common build dependencies for AI packages
RUN apk add --no-cache \
    build-base \
    gcc \
    g++ \
    musl-dev \
    postgresql-dev \
    libffi-dev \
    openssl-dev

# ==============================================================================
# Runtime Stage
# ==============================================================================
FROM python:3.11-alpine3.19

# Install common runtime dependencies
RUN apk add --no-cache \
    curl \
    wget \
    ca-certificates \
    tzdata \
    libpq \
    libgomp \
    libstdc++

ENV PATH=/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TZ=UTC

# Create standard non-root user
RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser

WORKDIR /app
```

Create `.docker/base/python-ai/README.md`:

```markdown
# arc-base-python-ai

Base image for Python AI/ML services in A.R.C. platform.

## Usage

```dockerfile
FROM arc-base-python-ai:3.11-alpine3.19 AS builder
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user -r requirements.txt

FROM arc-base-python-ai:3.11-alpine3.19
COPY --from=builder /root/.local /root/.local
COPY src/ /app/src/
USER arcuser
CMD ["python", "-m", "src.main"]
```

## Includes
- Python 3.11, Alpine 3.19
- Build tools (builder stage): gcc, g++, postgresql-dev
- Runtime libs: libpq, libgomp, curl
- Non-root user (arcuser, UID 1000)
```

### Step 1.4: Build and Test Base Images

**Action:**
```bash
# Build base images
cd .docker/base/go-infra
docker build -t arc-base-go-infra:1.21-alpine3.19 .

cd ../python-ai
docker build -t arc-base-python-ai:3.11-alpine3.19 .

# Verify images
docker images | grep arc-base

# Test by using in a simple Dockerfile
```

### Step 1.5: Publish Base Images to GHCR (Optional for now)

**Action:**
```bash
# Tag for GHCR
docker tag arc-base-go-infra:1.21-alpine3.19 ghcr.io/arc/base-go-infra:1.21-alpine3.19
docker tag arc-base-python-ai:3.11-alpine3.19 ghcr.io/arc/base-python-ai:3.11-alpine3.19

# Push (requires authentication)
# docker push ghcr.io/arc/base-go-infra:1.21-alpine3.19
# docker push ghcr.io/arc/base-python-ai:3.11-alpine3.19

# For now, use locally until we're confident
```

---

## Phase 2: Implement Validation Scripts (Week 2, Part 2)

### Step 2.1: Create scripts/validate/ Directory

**Action:**
```bash
mkdir -p scripts/validate
```

### Step 2.2: Create check-dockerfiles.sh

**Action:**
Create `scripts/validate/check-dockerfiles.sh`:

```bash
#!/bin/bash
set -e

echo "🔍 Linting all Dockerfiles with hadolint..."

FAILED=0

find . -name "Dockerfile" -not -path "*/node_modules/*" -not -path "*/.git/*" | while read -r dockerfile; do
    echo "Checking: $dockerfile"
    if ! hadolint "$dockerfile"; then
        FAILED=1
    fi
done

if [ $FAILED -eq 1 ]; then
    echo "❌ Dockerfile linting failed"
    exit 1
fi

echo "✅ All Dockerfiles passed linting"
```

Make executable:
```bash
chmod +x scripts/validate/check-dockerfiles.sh
```

### Step 2.3: Create check-security.sh

**Action:**
Create `scripts/validate/check-security.sh`:

```bash
#!/bin/bash
set -e

echo "🔒 Scanning images for security vulnerabilities..."

FAILED=0

docker images --format "{{.Repository}}:{{.Tag}}" | grep "^arc-" | while read -r image; do
    echo "Scanning: $image"
    if ! trivy image --severity HIGH,CRITICAL --exit-code 1 "$image"; then
        FAILED=1
    fi
done

if [ $FAILED -eq 1 ]; then
    echo "❌ Security scan failed (HIGH/CRITICAL vulnerabilities found)"
    exit 1
fi

echo "✅ All images passed security scan"
```

Make executable:
```bash
chmod +x scripts/validate/check-security.sh
```

### Step 2.4: Create check-structure.py

**Action:**
Create `scripts/validate/check-structure.py`:

```python
#!/usr/bin/env python3
"""
Validate that SERVICE.MD entries have corresponding directories
"""
import re
import sys
from pathlib import Path

def parse_service_md():
    """Parse SERVICE.MD and extract service entries"""
    service_md = Path("SERVICE.MD")
    if not service_md.exists():
        print("❌ SERVICE.MD not found")
        sys.exit(1)
    
    services = []
    content = service_md.read_text()
    
    # Parse markdown table (skip header rows)
    for line in content.split('\n'):
        if '|' in line and 'arc-' in line:
            parts = [p.strip() for p in line.split('|')]
            if len(parts) > 2:
                # Extract service name from GHCR image column
                image = parts[2] if len(parts) > 2 else ''
                if image.startswith('`arc-'):
                    service_name = image.strip('`')
                    services.append(service_name)
    
    return services

def map_service_to_path(service_name):
    """Map service name to expected directory path"""
    # Simplified mapping - adjust based on your needs
    if service_name in ['arc-gateway', 'arc-db-sql', 'arc-db-cache', 'arc-pulse', 
                         'arc-stream', 'arc-vault', 'arc-flags', 'arc-voice-server',
                         'arc-otel']:
        # These map to core/ services (technology names)
        return None  # Skip for now, mapping is complex
    else:
        # Application services map to services/
        return Path(f"services/{service_name}")

def main():
    print("🔍 Validating directory structure consistency...")
    
    services = parse_service_md()
    print(f"Found {len(services)} services in SERVICE.MD")
    
    failed = []
    
    for service in services:
        path = map_service_to_path(service)
        if path is None:
            continue  # Skip infrastructure services for now
        
        if not path.exists():
            failed.append(f"{service} → {path} (missing)")
            continue
        
        dockerfile = path / "Dockerfile"
        if not dockerfile.exists():
            failed.append(f"{service} → {dockerfile} (missing Dockerfile)")
            continue
        
        readme = path / "README.md"
        if not readme.exists():
            failed.append(f"{service} → {readme} (missing README)")
    
    if failed:
        print("❌ Structure validation failed:")
        for issue in failed:
            print(f"  - {issue}")
        sys.exit(1)
    
    print("✅ All services have corresponding directories")

if __name__ == "__main__":
    main()
```

Make executable:
```bash
chmod +x scripts/validate/check-structure.py
```

### Step 2.5: Update Makefile

**Action:**
Add to `Makefile`:

```makefile
# ==============================================================================
# Validation Targets (NEW)
# ==============================================================================
.PHONY: validate-structure validate-dockerfiles validate-security validate-all

validate-structure:
	@echo "$(BLUE)Validating directory structure...$(NC)"
	@python3 scripts/validate/check-structure.py

validate-dockerfiles:
	@echo "$(BLUE)Linting Dockerfiles...$(NC)"
	@scripts/validate/check-dockerfiles.sh

validate-security:
	@echo "$(BLUE)Scanning for vulnerabilities...$(NC)"
	@scripts/validate/check-security.sh

validate-all: validate-structure validate-dockerfiles validate-security
	@echo "$(GREEN)✓ All validations passed$(NC)"

# ==============================================================================
# Audit Targets (NEW)
# ==============================================================================
.PHONY: audit-dockerfiles audit-security audit-all

audit-dockerfiles:
	@echo "$(BLUE)Auditing Dockerfiles...$(NC)"
	@find . -name "Dockerfile" -not -path "*/node_modules/*" -exec hadolint {} \; || true

audit-security:
	@echo "$(BLUE)Auditing security...$(NC)"
	@docker images --format "{{.Repository}}:{{.Tag}}" | grep "^arc-" | while read -r image; do \
		echo "Scanning: $$image"; \
		trivy image --severity HIGH,CRITICAL "$$image" || true; \
	done

audit-all: audit-dockerfiles audit-security
	@echo "$(GREEN)✓ Audit complete$(NC)"
```

Test:
```bash
make validate-all
```

---

## Phase 3: Migrate Services (Weeks 3-4)

### Migration Order (Lowest Risk First)

1. ✅ **arc-oracle-sql** (Postgres) - Already using pgvector base, minimal changes
2. **arc-widow-otel** (OTEL Collector) - Config-only, low risk
3. **arc-piper-tts** - Simple Python service
4. **arc-sherlock-brain** - Complex dependencies
5. **arc-scarlett-voice** - Depends on Sherlock
6. **utilities/raymond** - Utility service
7. **Kratos** - Plugin, minimal changes

### Migration Template (Apply to Each Service)

#### Step 3.X.1: Create Feature Branch

```bash
git checkout -b 002-migrate-{service-name}
```

#### Step 3.X.2: Backup Current Dockerfile

```bash
cp services/arc-{service}/Dockerfile services/arc-{service}/Dockerfile.backup
```

#### Step 3.X.3: Update Dockerfile

Follow patterns from `docker-standards.md`:

1. Use base image if applicable
2. Implement multi-stage build
3. Add non-root user
4. Pin versions
5. Add health check
6. Add OCI labels

#### Step 3.X.4: Test Build Locally

```bash
cd services/arc-{service}
docker build -t arc-{service}:test .

# Verify non-root user
docker inspect arc-{service}:test | jq '.[0].Config.User'  # Should be "arcuser" or "1000"

# Verify image size
docker images arc-{service}:test

# Run hadolint
hadolint Dockerfile

# Run security scan
trivy image arc-{service}:test
```

#### Step 3.X.5: Test Functionality

```bash
# Start service
docker-compose up -d arc-{service}

# Check health
docker-compose ps
docker-compose logs arc-{service}

# Run integration tests
make test-{service}  # If tests exist
```

#### Step 3.X.6: Measure Improvements

```bash
# Image size comparison
echo "Before:" $(cat sizes-before.txt | grep {service})
echo "After:" $(docker images arc-{service}:test --format "{{.Size}}")

# Build time comparison
time docker build --no-cache -t arc-{service}:test .
```

#### Step 3.X.7: Update Documentation

- Update service README.md with new Dockerfile structure
- Document any deviations from standards
- Update SERVICE.MD if needed

#### Step 3.X.8: Commit and Push

```bash
git add services/arc-{service}/Dockerfile
git add services/arc-{service}/README.md
git commit -m "feat(002): Migrate arc-{service} to standardized Dockerfile

- Multi-stage build (size: {before}MB → {after}MB)
- Non-root user (UID 1000)
- Pinned base image version
- Added health check
- Security scan: 0 HIGH/CRITICAL vulnerabilities"

git push origin 002-migrate-{service-name}
```

#### Step 3.X.9: Create Pull Request

PR Template:
```markdown
## Migration: arc-{service} to Standardized Dockerfile

**Feature:** 002-stabilize-framework

### Changes
- ✅ Multi-stage build implemented
- ✅ Non-root user (UID 1000)
- ✅ Pinned base image version
- ✅ Health check added
- ✅ OCI labels added

### Improvements
- **Image size:** {before}MB → {after}MB ({percent}% reduction)
- **Security:** 0 HIGH/CRITICAL vulnerabilities
- **Build time:** {before}s → {after}s

### Testing
- [x] Local build successful
- [x] Service starts and passes health check
- [x] Integration tests pass
- [x] hadolint passes
- [x] trivy scan passes

### Checklist
- [x] Dockerfile follows standards (docker-standards.md)
- [x] README.md updated
- [x] No breaking changes
- [x] Tested in staging
```

#### Step 3.X.10: Deploy to Staging

```bash
# After PR approved and merged
git checkout main
git pull

# Deploy to staging
make down
make up-dev

# Monitor for issues
make logs | grep arc-{service}
make health-all
```

#### Step 3.X.11: Monitor and Iterate

- Monitor for 24 hours in staging
- Check logs for errors
- Verify metrics in Grafana
- Fix issues if found
- Move to next service

---

## Phase 4: CI/CD Integration (Week 5)

### Step 4.1: Create GitHub Actions Workflow

Create `.github/workflows/validate-dockerfiles.yml`:

```yaml
name: Validate Dockerfiles

on:
  pull_request:
    paths:
      - '**/Dockerfile'
      - 'scripts/validate/**'
  push:
    branches:
      - main

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run hadolint
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: '**/Dockerfile'
          failure-threshold: error
      
      - name: Validate structure
        run: |
          python3 scripts/validate/check-structure.py
  
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build images
        run: make build
      
      - name: Run Trivy scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'image'
          image-ref: 'arc-*:latest'
          severity: 'HIGH,CRITICAL'
          exit-code: '1'
```

### Step 4.2: Test Workflow

- Create test PR with Dockerfile change
- Verify workflow runs
- Verify failures are caught
- Fix any issues

### Step 4.3: Enable Required Checks

In GitHub repo settings:
- Branch protection → Require status checks
- Select "Validate Dockerfiles" as required

---

## Phase 5: Documentation & Rollout (Week 6)

### Step 5.1: Update All Documentation

- [ ] Update `README.md` with new validation commands
- [ ] Update `docs/guides/` with Dockerfile standards
- [ ] Create ADR (Architecture Decision Record) for base images
- [ ] Update SERVICE.MD if paths changed
- [ ] Create team demo video

### Step 5.2: Team Training

- Schedule team meeting
- Demo new workflow
- Q&A session
- Share migration guide

### Step 5.3: Production Rollout

- Schedule maintenance window (if needed)
- Deploy new images to production
- Monitor for 48 hours
- Collect feedback
- Address issues

### Step 5.4: Post-Migration Audit

**Action:**
Create `specs/002-stabilize-framework/post-migration-report.md`:

```markdown
# Post-Migration Report

**Date:** [Date]

## Images Migrated
- [x] arc-oracle-sql
- [x] arc-widow-otel
- [x] arc-piper-tts
- [x] arc-sherlock-brain
- [x] arc-scarlett-voice
- [x] utilities/raymond
- [x] kratos

## Metrics

### Image Sizes (Before → After)
[Table showing improvements]

### Build Times (Before → After)
[Table showing improvements]

### Security Vulnerabilities
- Before: X HIGH/CRITICAL
- After: 0 HIGH/CRITICAL

### Developer Satisfaction
[Survey results]

## Lessons Learned

### What Went Well
- [List]

### What Could Improve
- [List]

### Next Steps
- [List]
```

---

## Rollback Procedure (If Needed)

### If a Single Service Breaks

1. **Immediate:** Use old image tag
   ```bash
   docker-compose stop arc-{service}
   # Update docker-compose.yml to use old tag
   docker-compose up -d arc-{service}
   ```

2. **Short-term:** Revert Dockerfile
   ```bash
   git revert {commit-hash}
   git push
   make build
   ```

3. **Long-term:** Fix issues, re-test, re-deploy

### If Multiple Services Break

1. **Emergency:** Full rollback
   ```bash
   git checkout {last-good-commit}
   make down
   make build
   make up-full
   ```

2. **Investigate:** What went wrong?
3. **Fix:** Address root cause
4. **Re-test:** In staging
5. **Re-deploy:** Incrementally

---

## Success Criteria Validation

After migration complete, verify:

- [ ] **SC-001:** New developers locate services in <2 min (survey)
- [ ] **SC-002:** Security audits complete in <5 min (`make audit-security`)
- [ ] **SC-003:** Incremental builds <60 sec (measure)
- [ ] **SC-004:** Image sizes meet targets (check `docker images`)
- [ ] **SC-005:** 100% Dockerfiles use standards (audit)
- [ ] **SC-006:** CI/CD validates structure (GitHub Actions)
- [ ] **SC-008:** 0 HIGH/CRITICAL vulnerabilities (trivy)
- [ ] **SC-009:** No service downtime (monitoring)
- [ ] **SC-011:** Developer satisfaction 80%+ (survey)
- [ ] **SC-012:** Cache hit rate 85%+ (BuildKit metrics)

---

## Timeline Summary

| Week | Phase | Deliverables |
|------|-------|--------------|
| 1 | Audit | Current state documented, issues prioritized |
| 2 | Base Images + Validation | Base images built, validation scripts working |
| 3-4 | Service Migration | All 7 services migrated incrementally |
| 5 | CI/CD | GitHub Actions integrated, required checks enabled |
| 6 | Rollout | Production deployment, team training, post-audit |

**Total:** 6 weeks

---

**Status:** ✅ Migration Guide Complete - Ready for Execution

**Last Updated:** January 10, 2026

**"Migration is not a sprint. It's a series of sprints with validation at each step."** - The A.R.C. Architect

