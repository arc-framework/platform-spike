# A.R.C. CI/CD Helper Scripts

Python and Bash scripts for CI/CD automation.

## Purpose

Helper scripts provide reusable logic for:
- Parsing SERVICE.MD to generate build matrices
- Consolidating SBOM reports
- Calculating CI/CD costs
- Validating workflows locally

## Available Scripts

### Python Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `parse-services.py` | Parse SERVICE.MD for service matrix | `python parse-services.py > services.json` |
| `generate-matrix.py` | Generate GitHub Actions matrix from config | `python generate-matrix.py --config publish-gateway.json` |
| `consolidate-sbom.py` | Merge multiple SBOM files | `python consolidate-sbom.py --input sbom/ --output report.csv` |
| `check-licenses.py` | Check SBOM for license violations | `python check-licenses.py --sbom report.json` |
| `generate-cost-report.py` | Generate CI/CD cost report | `python generate-cost-report.py --input costs.json` |
| `create-cve-issue.py` | Create GitHub Issue for CVEs | `python create-cve-issue.py --trivy-report results.json` |
| `post-pr-comment.py` | Post/update PR comment | `python post-pr-comment.py --results results.json --pr 123` |

### Bash Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `validate-workflows.sh` | Run actionlint on all workflows | `./validate-workflows.sh` |
| `detect-changed-services.sh` | Detect services changed in PR | `./detect-changed-services.sh $BASE $HEAD` |
| `calculate-costs.sh` | Calculate CI/CD minute usage | `./calculate-costs.sh --days 30` |
| `run-smoke-tests.sh` | Run health checks on deployed services | `./run-smoke-tests.sh --env staging` |
| `rollback-deployment.sh` | Rollback to previous deployment | `./rollback-deployment.sh --service name` |

## Requirements

Install Python dependencies:

```bash
pip install -r .github/scripts/ci/requirements.txt
```

## Coding Standards

### Bash Scripts

```bash
#!/bin/bash
set -euo pipefail

# Logging functions
log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

log_info "Starting script"
```

### Python Scripts

```python
#!/usr/bin/env python3
"""Script description."""
import argparse
import json
import logging
import sys

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    # Add arguments
    args = parser.parse_args()
    # Logic here

if __name__ == '__main__':
    main()
```

## Testing Locally

```bash
# Test Python scripts
python .github/scripts/ci/parse-services.py

# Test Bash scripts
bash -x .github/scripts/ci/validate-workflows.sh

# Validate syntax
shellcheck .github/scripts/ci/*.sh
ruff check .github/scripts/ci/*.py
```

## Output Formats

All scripts output JSON for easy parsing in workflows:

```json
{
  "status": "success",
  "data": [...],
  "errors": []
}
```

## References

- [A.R.C. Polyglot Standards](../../../.specify/meta/polyglot-standards.md)
- [GitHub Actions Expressions](https://docs.github.com/en/actions/learn-github-actions/expressions)
