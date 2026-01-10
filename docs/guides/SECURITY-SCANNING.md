# Security Scanning Guide

**Task:** T032
**Last Updated:** January 2026

This guide explains how to run security scans on A.R.C. Docker images and Dockerfiles.

---

## Overview

A.R.C. uses two primary security scanning tools:

| Tool | Purpose | Scans |
|------|---------|-------|
| **hadolint** | Dockerfile linting | Best practices, security patterns |
| **trivy** | Vulnerability scanning | CVEs, misconfigurations |

---

## Quick Start

```bash
# Lint all Dockerfiles
./scripts/validate/check-dockerfiles.sh

# Scan images for vulnerabilities
./scripts/validate/check-security.sh

# Generate full compliance report
python scripts/validate/generate-security-report.py
```

---

## Dockerfile Linting (hadolint)

### Run Locally

```bash
# Lint all Dockerfiles
./scripts/validate/check-dockerfiles.sh

# JSON output for CI/CD
./scripts/validate/check-dockerfiles.sh --json

# Lint single file
hadolint --config .hadolint.yaml services/arc-sherlock-brain/Dockerfile
```

### Configuration

Hadolint is configured in `.hadolint.yaml`:

```yaml
trustedRegistries:
  - ghcr.io/arc
  - docker.io/library

ignored:
  - DL3008  # We use Alpine, not Debian
  - DL3018  # We pin Alpine version in base image
```

### Common Violations

| Code | Issue | Fix |
|------|-------|-----|
| DL3002 | Last USER is root | Add `USER arcuser` at end |
| DL3003 | Use WORKDIR instead of cd | Replace `RUN cd /app` with `WORKDIR /app` |
| DL3006 | Always tag image | Use `FROM python:3.11-alpine3.19` not `FROM python` |
| DL3013 | Pin pip versions | Use `pip install package==1.0.0` |
| DL3025 | Use JSON for CMD | Use `CMD ["python", "app.py"]` not `CMD python app.py` |

---

## Vulnerability Scanning (trivy)

### Run Locally

```bash
# Scan all arc-* images
./scripts/validate/check-security.sh

# Scan with specific severity
./scripts/validate/check-security.sh --severity CRITICAL

# JSON output
./scripts/validate/check-security.sh --json

# Scan filesystem (Dockerfiles and dependencies)
./scripts/validate/check-security.sh --filesystem
```

### Scan Single Image

```bash
# Quick scan
trivy image arc-sherlock-brain:latest

# Detailed with fixes
trivy image --severity HIGH,CRITICAL arc-sherlock-brain:latest

# JSON output
trivy image --format json arc-sherlock-brain:latest
```

### Interpreting Results

Trivy output shows:

```
arc-sherlock-brain (alpine 3.19.0)
==================================
Total: 2 (HIGH: 1, CRITICAL: 1)

+---------+---------------+----------+---------------+-------+
| LIBRARY | VULNERABILITY | SEVERITY | INSTALLED VER | FIXED |
+---------+---------------+----------+---------------+-------+
| libssl  | CVE-2024-XXXX | CRITICAL | 3.0.10        | 3.0.12|
+---------+---------------+----------+---------------+-------+
```

**Columns:**
- **Library**: Affected package
- **Vulnerability**: CVE identifier
- **Severity**: CRITICAL, HIGH, MEDIUM, LOW
- **Installed**: Current version in image
- **Fixed**: Version that fixes the CVE

---

## Fixing Vulnerabilities

### 1. Update Base Image

Most vulnerabilities come from outdated base images:

```dockerfile
# Before
FROM python:3.11-alpine3.18

# After - use latest patch version
FROM python:3.11-alpine3.19
```

### 2. Rebuild Images

```bash
# Rebuild base images
make build-base-images

# Rebuild services
make build-services

# Re-scan
./scripts/validate/check-security.sh
```

### 3. Update Dependencies

For application dependencies:

```bash
# Python
pip install --upgrade package-name
pip freeze > requirements.txt

# Go
go get -u ./...
go mod tidy
```

---

## CVE Response Process

### Severity Levels

| Severity | Response Time | Action |
|----------|--------------|--------|
| CRITICAL | 24 hours | Immediate patch, rebuild, deploy |
| HIGH | 7 days | Scheduled patch in next sprint |
| MEDIUM | 30 days | Add to backlog |
| LOW | 90 days | Review in quarterly audit |

### Response Steps

1. **Identify**: Run `./scripts/validate/check-security.sh`
2. **Assess**: Check if vulnerability is exploitable in our context
3. **Patch**: Update affected package/base image
4. **Test**: Run integration tests
5. **Deploy**: Push updated images
6. **Verify**: Re-run security scan

---

## CI/CD Integration

### GitHub Actions

Security scans run automatically:

- **On PR**: Dockerfile linting (hadolint)
- **On Push to main**: Full vulnerability scan
- **Daily at 6 AM UTC**: Scheduled security scan

### Workflows

- `.github/workflows/validate-docker.yml` - Dockerfile linting
- `.github/workflows/security-scan.yml` - Vulnerability scanning

### Viewing Results

1. Go to **Actions** tab in GitHub
2. Click on the workflow run
3. View **trivy-results.sarif** in Security tab

---

## Generating Reports

### Full Compliance Report

```bash
# Markdown output (terminal)
python scripts/validate/generate-security-report.py

# JSON output (file)
python scripts/validate/generate-security-report.py --output reports/security-report.json

# JSON to stdout
python scripts/validate/generate-security-report.py --json
```

### Report Contents

The report includes:

1. **Summary**: Pass/fail counts for each check
2. **Hadolint Results**: Dockerfile linting violations
3. **Trivy Results**: CVE counts and details
4. **Standards Check**: A.R.C. constitution compliance
5. **Recommendations**: Actionable fix suggestions

---

## A.R.C. Dockerfile Standards

All Dockerfiles must include:

| Requirement | Constitution | Check |
|-------------|--------------|-------|
| Non-root USER | Principle VIII | `USER arcuser` at end |
| HEALTHCHECK | Principle VII | `HEALTHCHECK CMD ...` |
| Pinned base image | Best Practice | `FROM image:version` (no `:latest`) |
| OCI Labels | Principle X | `LABEL org.opencontainers.*` |
| Multi-stage build | Principle IX | `FROM ... AS builder` |

### Example Compliant Dockerfile

```dockerfile
FROM python:3.11-alpine3.19 AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.11-alpine3.19
COPY --from=builder /root/.local /home/arcuser/.local
WORKDIR /app
COPY src/ ./src/

RUN adduser -D -u 1000 arcuser
USER arcuser

HEALTHCHECK --interval=30s --timeout=5s \
    CMD wget -q --spider http://localhost:8000/health || exit 1

LABEL org.opencontainers.image.title="arc-my-service" \
      arc.service.codename="myservice"

CMD ["python", "-m", "src.main"]
```

---

## Troubleshooting

### hadolint Not Found

```bash
# macOS
brew install hadolint

# Linux
wget -O /usr/local/bin/hadolint \
  https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
chmod +x /usr/local/bin/hadolint
```

### trivy Not Found

```bash
# macOS
brew install trivy

# Linux
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

### No Images to Scan

Build images first:

```bash
make build-base-images
make build-services
```

---

## Related Documentation

- [Docker Standards](../standards/DOCKER-STANDARDS.md) - Dockerfile requirements
- [Dockerfile Templates](../../.templates/) - Copy-paste templates
- [Base Images](../../.docker/base/) - Shared base images
