# Validation Failures Guide

**Task:** T059
**Last Updated:** January 2026

This guide helps you understand and fix common validation failures in the A.R.C. platform.

---

## Quick Reference

| Error | Quick Fix |
|-------|-----------|
| Missing directory | Create the directory or remove from SERVICE.MD |
| Missing Dockerfile | Add Dockerfile or use template from `.templates/` |
| No non-root USER | Add `USER arcuser` after creating user |
| :latest tag | Pin to specific version (e.g., `python:3.11-alpine3.19`) |
| Missing HEALTHCHECK | Add HEALTHCHECK instruction |
| Invalid compose | Run `docker compose config` to see errors |

---

## Running Validations

### All Validations

```bash
# Run all checks
./scripts/validate/validate-all.sh

# Strict mode (warnings are errors)
./scripts/validate/validate-all.sh --strict

# Quick mode (skip slow checks)
./scripts/validate/validate-all.sh --quick

# JSON output for CI
./scripts/validate/validate-all.sh --json
```

### Individual Validators

```bash
# Directory structure
python scripts/validate/check-structure.py

# SERVICE.MD registry
python scripts/validate/check-service-registry.py

# Dockerfile standards
python scripts/validate/check-dockerfile-standards.py

# Dockerfile linting (hadolint)
./scripts/validate/check-dockerfiles.sh

# Image sizes
python scripts/validate/check-image-sizes.py
```

---

## Common Errors and Fixes

### 1. Missing Directory

**Error:**
```
[missing_directory] Directory not found for service
Service: Brain
Path: core/engine
```

**Cause:** SERVICE.MD references a directory that doesn't exist.

**Fix Options:**

1. Create the directory:
   ```bash
   mkdir -p core/engine
   touch core/engine/Dockerfile
   ```

2. Remove from SERVICE.MD if the service was deprecated

3. Update the path in SERVICE.MD if it moved

---

### 2. Missing Dockerfile

**Error:**
```
[missing_dockerfile] Service missing Dockerfile
Path: services/arc-sherlock-brain/Dockerfile
```

**Cause:** Service directory exists but has no Dockerfile.

**Fix:**

1. Create Dockerfile using template:
   ```bash
   cp .templates/Dockerfile.python.template services/arc-sherlock-brain/Dockerfile
   # Edit the template to customize
   ```

2. For Python services:
   ```dockerfile
   FROM ghcr.io/arc/base-python-ai:3.11-alpine3.19
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY src/ ./src/
   USER arcuser
   HEALTHCHECK --interval=30s CMD wget -q --spider http://localhost:8000/health
   CMD ["python", "-m", "src.main"]
   ```

---

### 3. Non-Root User Missing

**Error:**
```
[non_root_user] Dockerfile must have USER instruction with non-root user (Constitution VIII)
```

**Cause:** Dockerfile doesn't switch to a non-root user.

**Fix:**

Add user creation and USER instruction:

```dockerfile
# Create non-root user
RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser && \
    chown -R arcuser:arcuser /app

# Switch to non-root user
USER arcuser
```

**Important:** Place USER instruction after all operations requiring root (package installation, file ownership changes).

---

### 4. :latest Tag Used

**Error:**
```
[no_latest_tag] Avoid :latest tag or untagged images: python:latest
Line: 1
```

**Cause:** Using `:latest` or no tag makes builds non-reproducible.

**Fix:**

Pin to a specific version:

```dockerfile
# Instead of
FROM python:latest
FROM python

# Use
FROM python:3.11-alpine3.19
```

**Note:** Include both language version AND base OS version for full reproducibility.

---

### 5. Missing HEALTHCHECK

**Error:**
```
[healthcheck_required] HEALTHCHECK instruction recommended (Constitution VII)
```

**Cause:** No HEALTHCHECK in Dockerfile, making container health unknown.

**Fix:**

Add appropriate HEALTHCHECK:

```dockerfile
# For HTTP services
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://localhost:8000/health || exit 1

# For non-HTTP services
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD pgrep -f "python -m src.main" || exit 1
```

---

### 6. Invalid Docker Compose

**Error:**
```
compose: FAILED
deployments/docker/docker-compose.services.yml: Invalid
```

**Cause:** YAML syntax error or invalid configuration.

**Fix:**

1. Validate the specific file:
   ```bash
   docker compose -f deployments/docker/docker-compose.services.yml config
   ```

2. Common issues:
   - Missing quotes around special characters
   - Incorrect indentation
   - Invalid service dependencies
   - Missing required fields

3. Check for syntax:
   ```bash
   yamllint deployments/docker/docker-compose.services.yml
   ```

---

### 7. SERVICE.MD Out of Sync

**Error:**
```
[untracked_directory] Service directory not found in SERVICE.MD registry
Path: services/arc-new-service
```

**Cause:** A service directory exists but isn't listed in SERVICE.MD.

**Fix:**

Add the service to SERVICE.MD's Master Service Table:

```markdown
| **NewService** | `arc-new-service` | CORE | `./services/arc-new-service` | **Codename** | Role description |
```

---

### 8. Missing OCI Labels

**Error:**
```
[required_label] Missing required OCI label: org.opencontainers.image.title
```

**Cause:** Dockerfile missing standard OCI metadata labels.

**Fix:**

Add LABEL instruction:

```dockerfile
LABEL org.opencontainers.image.title="arc-sherlock-brain" \
      org.opencontainers.image.description="LangGraph reasoning engine" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      arc.service.tier="services"
```

---

## Hadolint-Specific Errors

### DL3008: Pin versions in apt-get

```
DL3008 warning: Pin versions in apt get install
```

**Fix:** We use Alpine (apk), so this is usually suppressed in `.hadolint.yaml`.

### DL3018: Pin versions in apk add

```
DL3018 warning: Pin versions in apk add
```

**Fix:** Alpine packages are version-pinned via the Alpine version. Suppress if needed:
```yaml
# .hadolint.yaml
ignored:
  - DL3018
```

### DL4006: Set SHELL option -o pipefail

```
DL4006 warning: Set the SHELL option -o pipefail
```

**Fix:** Add at top of Dockerfile:
```dockerfile
SHELL ["/bin/sh", "-o", "pipefail", "-c"]
```

---

## Pre-commit Hook Failures

If pre-commit hooks are blocking your commit:

### Skip Specific Hook (Emergency Only)

```bash
SKIP=check-structure git commit -m "message"
```

### Skip All Hooks (Emergency Only)

```bash
git commit --no-verify -m "message"
```

### Update Hooks

```bash
pre-commit autoupdate
pre-commit install
```

---

## CI/CD Failures

### GitHub Actions

1. Check the workflow run for specific failure messages
2. Click on the failed job to see detailed logs
3. Run the same validation locally to debug

### Adding Exceptions

If you need to add an exception (with justification):

1. For hadolint: Add to `.hadolint.yaml`
2. For structure: Document exception in SERVICE.MD
3. For security: Create issue and document in `reports/security-baseline.json`

---

## Getting Help

1. Check this guide first
2. Run validators locally with `--json` for detailed output
3. Review related documentation:
   - [Docker Standards](./DOCKER-STANDARDS.md)
   - [Docker Build Optimization](./DOCKER-BUILD-OPTIMIZATION.md)
   - [Security Scanning](./SECURITY-SCANNING.md)

---

## Related Documentation

- [Docker Standards](./DOCKER-STANDARDS.md) - Dockerfile requirements
- [Docker Build Optimization](./DOCKER-BUILD-OPTIMIZATION.md) - Build best practices
- [Directory Design](../architecture/DIRECTORY-DESIGN.md) - Structure requirements
