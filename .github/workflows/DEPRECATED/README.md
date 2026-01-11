# Deprecated Workflows

This folder contains deprecated GitHub Actions workflows that have been replaced by the new CI/CD system.

## Deprecation Timeline

| Deprecated Workflow | Replacement | Deprecated On | Remove After |
|---------------------|-------------|---------------|--------------|
| `docker-publish.yml` | `publish-vendor-images.yml` | 2026-01-11 | 2026-02-11 |
| `validate-docker.yml` | `pr-checks.yml` | 2026-01-11 | 2026-02-11 |
| `validate-structure.yml` | `pr-checks.yml` | 2026-01-11 | 2026-02-11 |
| `security-scan.yml` | `scheduled-maintenance.yml` | 2026-01-11 | 2026-02-11 |
| `publish-gateway.yml` | `publish-vendor-images.yml` | 2026-01-11 | 2026-02-11 |
| `publish-data-services.yml` | `publish-vendor-images.yml` | 2026-01-11 | 2026-02-11 |
| `publish-communication.yml` | `publish-vendor-images.yml` | 2026-01-11 | 2026-02-11 |
| `publish-observability.yml` | `publish-vendor-images.yml` | 2026-01-11 | 2026-02-11 |
| `publish-tools.yml` | `publish-vendor-images.yml` | 2026-01-11 | 2026-02-11 |
| `reusable-publish.yml` | `_reusable-publish-group.yml` | 2026-01-11 | 2026-02-11 |

## Migration Guide

### For Image Publishing

**Before (deprecated):**
```bash
gh workflow run publish-gateway.yml
gh workflow run publish-data-services.yml
gh workflow run publish-observability.yml
```

**After (new):**
```bash
# Publish specific group
gh workflow run publish-vendor-images.yml -f groups=gateway
gh workflow run publish-vendor-images.yml -f groups=data

# Publish all groups
gh workflow run publish-vendor-images.yml -f groups=all
```

### For Validation

**Before (deprecated):**
- `validate-docker.yml` - Ran on PR for Dockerfile linting
- `validate-structure.yml` - Ran on PR for structure validation

**After (new):**
- `pr-checks.yml` - Runs automatically on all PRs
  - Includes Dockerfile linting
  - Includes structure validation
  - Includes security scanning
  - Generates comprehensive job summaries

### For Security Scanning

**Before (deprecated):**
```bash
gh workflow run security-scan.yml
```

**After (new):**
```bash
gh workflow run scheduled-maintenance.yml
```

The new workflow includes:
- Trivy vulnerability scanning
- SBOM generation (SPDX + CycloneDX)
- CVE tracking with GitHub Issues
- License compliance checking
- Dependency report generation

## Why These Workflows Were Deprecated

1. **Consolidation**: Multiple validation workflows consolidated into `pr-checks.yml`
2. **Configuration-Driven**: Image publishing now uses JSON configs instead of hardcoded values
3. **Rate Limiting**: New publish workflow includes delays to avoid GHCR throttling
4. **Better Observability**: New workflows generate comprehensive job summaries
5. **Cost Optimization**: Aggressive caching reduces build times by 50%+

## Documentation

- [CI/CD Developer Guide](../../../docs/guides/CICD-DEVELOPER-GUIDE.md)
- [CI/CD Architecture](../../../docs/architecture/CICD-ARCHITECTURE.md)

## Removal Process

After the grace period (2026-02-11):
1. Verify no active references to deprecated workflows
2. Archive this folder for historical reference
3. Delete deprecated workflow files
4. Update changelog
