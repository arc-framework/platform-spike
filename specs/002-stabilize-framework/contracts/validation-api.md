# Validation Script Interface Specification

**Feature:** 002-stabilize-framework
**Date:** January 10, 2026
**Status:** Approved

---

## Overview

This document defines the contract for all validation scripts in `scripts/validate/`. Consistent interfaces enable CI/CD integration, composability, and predictable behavior.

---

## Exit Codes

All validation scripts MUST use these exit codes:

| Code | Status | Meaning |
|------|--------|---------|
| `0` | PASS | All validations passed |
| `1` | FAIL | One or more validations failed (fixable issues) |
| `2` | ERROR | Script encountered an error (configuration, missing files, etc.) |

**Example Usage:**
```bash
./scripts/validate/check-structure.py
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "All checks passed"
elif [ $EXIT_CODE -eq 1 ]; then
    echo "Validation failures found - see report"
elif [ $EXIT_CODE -eq 2 ]; then
    echo "Script error - check configuration"
fi
```

---

## Output Formats

### JSON Output (Python Scripts)

All Python validation scripts MUST output JSON to stdout when `--format json` is specified (or by default for CI/CD).

**Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["status", "timestamp", "script", "checks", "summary"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["passed", "failed", "error"]
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp"
    },
    "script": {
      "type": "string",
      "description": "Name of the validation script"
    },
    "duration_seconds": {
      "type": "number",
      "description": "Time taken to run validation"
    },
    "checks": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "status"],
        "properties": {
          "name": {
            "type": "string",
            "description": "Check identifier"
          },
          "status": {
            "type": "string",
            "enum": ["passed", "failed", "skipped", "warning"]
          },
          "details": {
            "type": "string",
            "description": "Human-readable details"
          },
          "file": {
            "type": "string",
            "description": "Related file path (if applicable)"
          },
          "line": {
            "type": "integer",
            "description": "Line number (if applicable)"
          },
          "fix": {
            "type": "string",
            "description": "Suggested fix (if applicable)"
          }
        }
      }
    },
    "summary": {
      "type": "object",
      "required": ["total", "passed", "failed"],
      "properties": {
        "total": { "type": "integer" },
        "passed": { "type": "integer" },
        "failed": { "type": "integer" },
        "skipped": { "type": "integer" },
        "warnings": { "type": "integer" }
      }
    },
    "metadata": {
      "type": "object",
      "description": "Script-specific metadata",
      "additionalProperties": true
    }
  }
}
```

**Example Output:**
```json
{
  "status": "failed",
  "timestamp": "2026-01-10T15:30:00Z",
  "script": "check-structure.py",
  "duration_seconds": 1.23,
  "checks": [
    {
      "name": "service_directory_exists",
      "status": "passed",
      "details": "arc-sherlock-brain found at services/arc-sherlock-brain/"
    },
    {
      "name": "service_directory_exists",
      "status": "failed",
      "details": "arc-ghost-agent not found",
      "fix": "Create directory: mkdir -p services/arc-ghost-agent/"
    },
    {
      "name": "dockerfile_exists",
      "status": "passed",
      "file": "services/arc-sherlock-brain/Dockerfile"
    }
  ],
  "summary": {
    "total": 3,
    "passed": 2,
    "failed": 1,
    "skipped": 0,
    "warnings": 0
  },
  "metadata": {
    "services_checked": ["arc-sherlock-brain", "arc-ghost-agent"],
    "source": "SERVICE.MD"
  }
}
```

### Human-Readable Output (Shell Scripts)

Shell scripts SHOULD output human-readable text with clear pass/fail indicators:

```
=== A.R.C. Dockerfile Validation ===
Checking: services/arc-sherlock-brain/Dockerfile
  ✓ hadolint passed (0 errors, 0 warnings)
Checking: services/arc-scarlett-voice/Dockerfile
  ✗ hadolint failed
    DL3006: Always pin image version
    Line 1: FROM python:latest

Summary: 1 passed, 1 failed
```

---

## Command-Line Interface

### Required Arguments

All scripts MUST support:

| Argument | Description |
|----------|-------------|
| `--help` | Display usage information |
| `--version` | Display script version |

### Optional Arguments

Scripts SHOULD support where applicable:

| Argument | Description | Default |
|----------|-------------|---------|
| `--format` | Output format: `json`, `text`, `github` | `text` |
| `--verbose` | Enable verbose output | `false` |
| `--quiet` | Suppress non-essential output | `false` |
| `--path` | Root path to validate | Current directory |
| `--config` | Path to configuration file | Auto-detect |

**Example:**
```bash
# JSON output for CI/CD
python scripts/validate/check-structure.py --format json

# Verbose text output for debugging
python scripts/validate/check-structure.py --verbose

# GitHub Actions annotations format
python scripts/validate/check-structure.py --format github
```

### GitHub Actions Format

When `--format github` is specified, output GitHub Actions workflow commands:

```
::error file=services/arc-ghost-agent/Dockerfile,line=1::DL3006: Always pin image version
::warning file=services/arc-sherlock-brain/Dockerfile,line=15::DL4006: Set SHELL option -o pipefail
```

---

## Logging (Constitution Principle VI)

All Python validation scripts MUST include structured logging:

```python
import structlog

logger = structlog.get_logger()

# Log validation start
logger.info("validation.start",
    script="check-structure.py",
    target="SERVICE.MD")

# Log individual check results
logger.debug("check.result",
    check="service_directory_exists",
    service="arc-sherlock-brain",
    status="passed")

# Log validation complete
logger.info("validation.complete",
    status="passed",
    total_checks=10,
    passed=10,
    failed=0,
    duration_seconds=1.23)
```

**Log Levels:**
- `INFO`: Start/complete events, summary results
- `DEBUG`: Individual check results
- `WARNING`: Non-blocking issues
- `ERROR`: Blocking failures

---

## Configuration

Scripts MAY read configuration from:

1. **Command-line arguments** (highest priority)
2. **Environment variables** (prefixed with `ARC_VALIDATE_`)
3. **Configuration file** (`.arc-validate.yaml` or script-specific)
4. **Defaults** (lowest priority)

**Example Environment Variables:**
```bash
export ARC_VALIDATE_FORMAT=json
export ARC_VALIDATE_VERBOSE=true
export ARC_VALIDATE_PATH=/path/to/repo
```

---

## Error Handling

Scripts MUST:

1. **Catch all exceptions** and exit with code 2
2. **Provide actionable error messages**
3. **Never crash silently**

```python
import sys

def main():
    try:
        run_validation()
    except FileNotFoundError as e:
        print(f"Error: Required file not found: {e}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"Error: Unexpected error: {e}", file=sys.stderr)
        sys.exit(2)
```

---

## Script Catalog

### check-structure.py

**Purpose:** Validate directory structure follows constitution patterns.

**Input:** Repository root directory
**Checks:**
- Service directories exist in correct tier (core/plugins/services)
- Naming follows convention (`arc-{codename}-{function}`)
- No orphaned directories (not in SERVICE.MD)

### check-service-registry.py

**Purpose:** Validate SERVICE.MD against actual implementation.

**Input:** SERVICE.MD file, repository root
**Checks:**
- All services in SERVICE.MD have directories
- All services have Dockerfiles
- Codenames are unique
- Types are valid (INFRA, CORE, WORKER, SIDECAR)

### check-dockerfiles.sh

**Purpose:** Run hadolint on all Dockerfiles.

**Input:** Repository root directory
**Checks:**
- hadolint passes with no errors
- Uses configuration from `.hadolint.yaml`

### check-dockerfile-standards.py

**Purpose:** Validate Dockerfiles against A.R.C. security requirements.

**Input:** Dockerfile paths
**Checks:**
- Non-root user (USER instruction, not root)
- No `:latest` tags in FROM
- Multi-stage build (where applicable)
- HEALTHCHECK present
- OCI labels present

### check-security.sh

**Purpose:** Run security scans on built images.

**Input:** Docker image names/tags
**Checks:**
- trivy scan passes (no HIGH/CRITICAL)
- Base images are up-to-date

### check-image-sizes.py

**Purpose:** Validate image sizes against targets.

**Input:** Docker image names/tags
**Checks:**
- Go services <50MB
- Python services <500MB
- Infrastructure <100MB

### validate-all.sh

**Purpose:** Orchestrate all validation scripts.

**Input:** Repository root directory
**Behavior:**
- Runs all validation scripts in sequence
- Stops on first failure (unless `--continue-on-error`)
- Aggregates results into summary report

---

## Testing Validation Scripts

Each validation script MUST have corresponding tests:

```
scripts/validate/
├── check-structure.py
├── check-structure_test.py    # Tests for check-structure.py
├── check-dockerfiles.sh
├── check-dockerfiles_test.sh  # Tests for check-dockerfiles.sh
└── ...
```

**Test Requirements:**
- Test exit codes for pass/fail/error scenarios
- Test JSON output schema compliance
- Test edge cases (empty dirs, missing files)
- Mock external dependencies (Docker, hadolint)

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Validate Structure
on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install -r scripts/validate/requirements.txt

      - name: Run structure validation
        run: python scripts/validate/check-structure.py --format github

      - name: Run Dockerfile validation
        run: ./scripts/validate/check-dockerfiles.sh
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: validate-structure
        name: Validate directory structure
        entry: python scripts/validate/check-structure.py
        language: python
        pass_filenames: false
        always_run: true
```

---

## Metrics (Constitution Principle VI)

Scripts SHOULD track these metrics:

| Metric | Type | Description |
|--------|------|-------------|
| `validation.duration_seconds` | Histogram | Time to complete validation |
| `validation.checks_total` | Counter | Total checks executed |
| `validation.checks_passed` | Counter | Checks that passed |
| `validation.checks_failed` | Counter | Checks that failed |
| `validation.errors_total` | Counter | Script errors encountered |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-10 | Initial specification |

---

**Status:** ✅ Approved for Implementation

**Next Steps:**
1. Implement scripts following this specification
2. Add tests for each script
3. Integrate into CI/CD workflow
