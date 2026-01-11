# A.R.C. Validation Scripts

Automated validation tools for enforcing A.R.C. framework standards.

## Overview

These scripts validate that the platform adheres to:
- Directory structure conventions (SERVICE.MD alignment)
- Dockerfile security standards (non-root, pinned versions)
- Image size targets (Python <500MB, Go <50MB)
- Documentation synchronization

## Scripts

| Script | Purpose | Exit Codes |
|--------|---------|------------|
| `check-structure.py` | Validates SERVICE.MD vs actual directories | 0=pass, 1=fail, 2=error |
| `check-service-registry.py` | Validates SERVICE.MD schema and references | 0=pass, 1=fail, 2=error |
| `check-dockerfiles.sh` | Runs hadolint on all Dockerfiles | 0=pass, 1=fail |
| `check-dockerfile-standards.py` | Validates Dockerfile security requirements | 0=pass, 1=fail, 2=error |
| `check-security.sh` | Runs trivy security scans | 0=pass, 1=fail |
| `check-image-sizes.py` | Validates image sizes against targets | 0=pass, 1=fail, 2=error |
| `validate-all.sh` | Orchestrates all validation scripts | 0=pass, 1=fail |

## Usage

### Run All Validations

```bash
./scripts/validate/validate-all.sh
```

### Run Individual Validations

```bash
# Structure validation
python scripts/validate/check-structure.py

# Dockerfile linting
./scripts/validate/check-dockerfiles.sh

# Security scanning (requires built images)
./scripts/validate/check-security.sh
```

### CI/CD Integration

These scripts are automatically run via GitHub Actions on:
- Pull requests (`.github/workflows/pr-checks.yml`)
- Push to main (`.github/workflows/main-deploy.yml`)
- Daily schedule (`.github/workflows/scheduled-maintenance.yml`)

## Output Format

All Python validators output JSON for CI/CD parsing:

```json
{
  "status": "passed|failed|error",
  "timestamp": "2026-01-10T12:00:00Z",
  "checks": [
    {
      "name": "service_directory_exists",
      "status": "passed",
      "details": "arc-sherlock-brain: services/arc-sherlock-brain/"
    }
  ],
  "summary": {
    "total": 10,
    "passed": 9,
    "failed": 1
  }
}
```

## Requirements

Install validation dependencies:

```bash
pip install -r scripts/validate/requirements.txt
```

## Adding New Validations

1. Create script following naming convention: `check-{what}.{py|sh}`
2. Implement standard exit codes (0=pass, 1=fail, 2=error)
3. Output JSON for Python scripts, plain text for shell scripts
4. Add script to `validate-all.sh` orchestrator
5. Update this README with script documentation
