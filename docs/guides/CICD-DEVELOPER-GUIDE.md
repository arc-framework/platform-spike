# CI/CD Developer Guide

This guide explains how the A.R.C. CI/CD system is organized, how to work with it, and how to extend it for new services.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Workflow Organization](#workflow-organization)
- [Adding a New Service](#adding-a-new-service)
- [Working with Workflows](#working-with-workflows)
- [Caching Strategy](#caching-strategy)
- [Security Scanning](#security-scanning)
- [Cost Management](#cost-management)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

The CI/CD system follows a **3-tier layered architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATION LAYER                       │
│  pr-checks.yml │ main-deploy.yml │ release.yml │ scheduled  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     REUSABLE LAYER                           │
│  _reusable-validate.yml │ _reusable-build.yml │ _reusable-* │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    COMPOSITE ACTIONS                         │
│     arc-setup │ arc-docker-build │ arc-security-scan │ ...  │
└─────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Purpose | Examples |
|-------|---------|----------|
| **Orchestration** | Entry points, trigger handling, job coordination | `pr-checks.yml`, `release.yml` |
| **Reusable** | Shared workflow logic, consistent job patterns | `_reusable-build.yml` |
| **Composite Actions** | Atomic operations, tool setup, common steps | `arc-setup`, `arc-docker-build` |

---

## Workflow Organization

### Directory Structure

```
.github/
├── actions/                    # Composite actions
│   ├── arc-setup/             # Environment setup
│   ├── arc-docker-build/      # Docker build with caching
│   ├── arc-security-scan/     # Security scanning
│   └── arc-job-summary/       # Job summary generation
├── workflows/                  # GitHub Actions workflows
│   ├── pr-checks.yml          # PR validation (fast feedback)
│   ├── main-deploy.yml        # Main branch deployment
│   ├── release.yml            # Release pipeline
│   ├── _reusable-*.yml        # Reusable workflows (prefixed with _)
│   └── *.yml                  # Other orchestration workflows
├── config/                     # Configuration files
│   ├── services.json          # Service definitions
│   ├── cache-config.json      # Caching strategies
│   └── publish-*.json         # Image publishing configs
└── scripts/ci/                 # CI/CD scripts
    ├── generate-matrix.py     # Dynamic matrix generation
    ├── calculate-costs.py     # Cost tracking
    └── *.py, *.sh             # Other utilities
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Reusable workflows | `_reusable-{name}.yml` | `_reusable-build.yml` |
| Composite actions | `arc-{name}/action.yml` | `arc-setup/action.yml` |
| Config files | `{purpose}.json` | `services.json` |
| CI scripts | `{verb}-{noun}.py` | `generate-matrix.py` |

---

## Adding a New Service

### Step 1: Define the Service

Add your service to `SERVICE.MD` in the repository root:

```markdown
## arc-your-service-name

**Codename**: your-service-name
**Category**: core | vendor | tool
**Port**: 8080
**Health Check**: /health

### Description
Brief description of what the service does.

### Dependencies
- arc-oracle-postgres
- arc-quicksilver-cache
```

### Step 2: Create Dockerfile

Create `services/arc-your-service-name/Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1.4
ARG BASE_IMAGE=ghcr.io/arc-framework/arc-base-go:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="A.R.C. Your Service"
LABEL org.opencontainers.image.description="Description here"

WORKDIR /app
COPY . .

RUN go build -o /app/server ./cmd/server

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/app/server"]
```

### Step 3: Update Service Matrix

The service will be automatically picked up by the matrix generator. To verify:

```bash
python .github/scripts/ci/generate-matrix.py --services SERVICE.MD
```

### Step 4: Test Locally

```bash
# Build the image
docker build -t arc-your-service-name:local services/arc-your-service-name/

# Run tests
docker run --rm arc-your-service-name:local go test ./...

# Test health check
docker run -d -p 8080:8080 arc-your-service-name:local
curl http://localhost:8080/health
```

### Step 5: Create PR

The PR will automatically trigger:
1. **Validation**: Dockerfile lint, structure check
2. **Build**: Multi-arch build (linux/amd64, linux/arm64)
3. **Security**: Trivy vulnerability scan
4. **Summary**: Build metrics and status

---

## Working with Workflows

### Triggering Workflows

| Trigger | Workflow | What Happens |
|---------|----------|--------------|
| PR opened/updated | `pr-checks.yml` | Fast validation, build, security scan |
| Merge to main | `main-deploy.yml` | Full build, publish to GHCR |
| Tag `v*` | `release.yml` | Staged deployment with approval |
| Daily (midnight) | `scheduled-maintenance.yml` | Security scans, cost reports |
| Weekly (Sunday) | `publish-vendor-images.yml` | Vendor image updates |

### Manual Triggers

Most workflows support manual triggering via `workflow_dispatch`:

```bash
# Trigger via GitHub CLI
gh workflow run pr-checks.yml --ref your-branch

# Trigger with inputs
gh workflow run release.yml -f version=v1.2.3 -f environment=staging
```

### Viewing Results

1. **Job Summaries**: Every workflow generates a summary in the Actions tab
2. **Artifacts**: Build outputs, reports, and logs are uploaded as artifacts
3. **PR Comments**: Key results are posted as PR comments

---

## Caching Strategy

### Cache Types

| Cache | Key Pattern | Hit Rate Target |
|-------|-------------|-----------------|
| Go modules | `go-mod-{os}-{hash(go.sum)}` | 90% |
| Go build | `go-build-{os}-{hash}-{sha}` | 75% |
| Docker layers | `buildx-{os}-{branch}-{sha}` | 70% |
| golangci-lint | `golangci-lint-{os}-{hash}` | 95% |

### Cache Configuration

Cache settings are defined in `.github/config/cache-config.json`:

```json
{
  "caches": {
    "go-modules": {
      "path": "~/go/pkg/mod",
      "key_template": "go-mod-${{ runner.os }}-${{ hashFiles('**/go.sum') }}",
      "restore_keys": ["go-mod-${{ runner.os }}-"],
      "expected_hit_rate": 90
    }
  }
}
```

### Cache Best Practices

1. **Use hash-based keys** for dependency caches
2. **Include restore keys** with progressively shorter prefixes
3. **Separate build and dependency caches** for better hit rates
4. **Monitor hit rates** via the cache management workflow

### Clearing Caches

```bash
# List all caches
gh api /repos/{owner}/{repo}/actions/caches --paginate

# Delete specific cache
gh api --method DELETE /repos/{owner}/{repo}/actions/caches/{cache_id}

# Or use the cache management workflow
gh workflow run cache-management.yml -f action=cleanup-branch -f branch=feature-xyz
```

---

## Security Scanning

### Scan Types

| Scan | Tool | Trigger | Blocking |
|------|------|---------|----------|
| Image vulnerabilities | Trivy | Every build | Critical/High |
| Secret detection | Gitleaks | PR, push | Any secret |
| SBOM generation | Syft | Main branch | No |
| License compliance | Custom | Main branch | Denied licenses |

### Vulnerability Thresholds

```yaml
# In _reusable-security.yml
severity: CRITICAL,HIGH
exit-code: 1  # Fail on findings
ignore-unfixed: true  # Only actionable CVEs
```

### Handling Security Findings

1. **Critical/High**: Build fails, must fix before merge
2. **Medium**: Warning in summary, should fix soon
3. **Low**: Informational, fix when convenient

### Suppressing False Positives

Create `.trivyignore` in your service directory:

```
# Ignore specific CVE (with justification)
CVE-2023-12345  # False positive: not using affected function
```

---

## Cost Management

### Free Tier Limits

GitHub Actions provides 2,000 minutes/month free (Linux equivalent):

| Runner | Multiplier | Effective Minutes |
|--------|------------|-------------------|
| Linux | 1x | 2,000 |
| Windows | 2x | 1,000 |
| macOS | 10x | 200 |

### Monitoring Costs

The `cost-monitoring.yml` workflow runs daily and:
- Calculates minutes used per workflow
- Projects monthly usage
- Alerts when approaching 70%/80% thresholds

View cost reports:
```bash
# Download latest cost report
gh run download --name cost-reports --dir ./reports

# Or trigger manual report
gh workflow run cost-monitoring.yml -f days=30
```

### Cost Optimization Tips

1. **Use caching aggressively** - Cache hits save ~30 seconds each
2. **Skip unnecessary runs** - Use path filters in workflow triggers
3. **Cancel redundant runs** - Enable concurrency groups
4. **Parallelize wisely** - More parallel jobs = faster but same total minutes
5. **Use Linux runners** - 10x cheaper than macOS

### Path Filters Example

```yaml
on:
  pull_request:
    paths:
      - 'services/arc-my-service/**'
      - '.github/workflows/pr-checks.yml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

---

## Troubleshooting

### Common Issues

#### Build Fails with "No space left on device"

**Cause**: Docker cache or build artifacts filling disk

**Solution**: Add cleanup step before build:
```yaml
- name: Free disk space
  run: |
    docker system prune -af
    rm -rf /tmp/*
```

#### Cache Miss Despite Same Dependencies

**Cause**: Key includes volatile values (timestamps, SHAs)

**Solution**: Check cache key pattern uses only stable hashes:
```yaml
key: go-mod-${{ runner.os }}-${{ hashFiles('**/go.sum') }}
# NOT: go-mod-${{ runner.os }}-${{ github.sha }}
```

#### Security Scan Timeout

**Cause**: Large image or slow Trivy DB download

**Solution**:
1. Use Trivy cache action
2. Increase timeout
3. Consider scanning specific paths

#### Matrix Job Generates Empty Array

**Cause**: `generate-matrix.py` found no matching services

**Solution**:
```bash
# Debug matrix generation
python .github/scripts/ci/generate-matrix.py --services SERVICE.MD --debug
```

### Debugging Workflows

#### Enable Debug Logging

Set repository secret `ACTIONS_STEP_DEBUG=true` for verbose output.

#### Run Locally with `act`

```bash
# Install act
brew install act

# Run PR checks locally
act pull_request -W .github/workflows/pr-checks.yml

# With specific event
act -e .github/events/pr-event.json
```

#### Check Workflow Syntax

```bash
# Install actionlint
brew install actionlint

# Validate all workflows
actionlint .github/workflows/*.yml
```

### Getting Help

1. Check workflow run logs in GitHub Actions tab
2. Review job summaries for error details
3. Search existing issues for similar problems
4. Open a new issue with:
   - Workflow name and run ID
   - Error message
   - Steps to reproduce

---

## Quick Reference

### Useful Commands

```bash
# List recent workflow runs
gh run list --limit 10

# View specific run
gh run view <run-id>

# Download artifacts
gh run download <run-id>

# Cancel running workflow
gh run cancel <run-id>

# Re-run failed jobs
gh run rerun <run-id> --failed

# View workflow usage
gh api /repos/{owner}/{repo}/actions/cache/usage
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_TOKEN` | Auto-provided auth token | - |
| `GITHUB_REPOSITORY` | Owner/repo format | `arc-framework/platform-spike` |
| `GITHUB_SHA` | Current commit SHA | `abc1234...` |
| `GITHUB_REF_NAME` | Branch or tag name | `main`, `v1.0.0` |

### Workflow Status Badges

Add to your README:
```markdown
![PR Checks](https://github.com/arc-framework/platform-spike/actions/workflows/pr-checks.yml/badge.svg)
![Main Deploy](https://github.com/arc-framework/platform-spike/actions/workflows/main-deploy.yml/badge.svg)
```

---

## Related Documentation

- [CI/CD Architecture](../architecture/CICD-ARCHITECTURE.md)
- [Docker Standards](../standards/DOCKER-STANDARDS.md)
- [Security Scanning Guide](./SECURITY-SCANNING.md)
- [GHCR Publishing Guide](./GHCR-PUBLISHING.md)
