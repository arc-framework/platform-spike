# Setup A.R.C. Validation Tools

Composite action to install validation tools for Dockerfile linting, security scanning, and shell script checking.

## Purpose

Provides consistent validation tool setup across all A.R.C. workflows:
- **hadolint**: Dockerfile linter
- **trivy**: Security vulnerability scanner
- **shellcheck**: Shell script analyzer

## Usage

### Basic Usage

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Validation Tools
    uses: ./.github/actions/setup-arc-validation

  - name: Lint Dockerfiles
    run: hadolint services/*/Dockerfile
```

### With Custom Versions

```yaml
steps:
  - name: Setup Validation Tools
    uses: ./.github/actions/setup-arc-validation
    with:
      hadolint-version: '2.12.0'
      trivy-version: '0.48.0'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `hadolint-version` | Hadolint version | No | `2.12.0` |
| `trivy-version` | Trivy version | No | `0.48.0` |
| `install-shellcheck` | Install shellcheck | No | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `hadolint-version` | Installed hadolint version |
| `trivy-version` | Installed trivy version |
| `cache-hit` | Whether the tools cache was hit |

## Installed Tools

| Tool | Purpose | Documentation |
|------|---------|---------------|
| `hadolint` | Dockerfile best practices linter | [hadolint/hadolint](https://github.com/hadolint/hadolint) |
| `trivy` | Security vulnerability scanner | [aquasecurity/trivy](https://github.com/aquasecurity/trivy) |
| `shellcheck` | Shell script static analyzer | [koalaman/shellcheck](https://github.com/koalaman/shellcheck) |

## Cache Strategy

- Tools are cached to `~/bin/` directory
- Cache key includes tool versions for automatic invalidation
- Subsequent runs use cached binaries (cache hit)

## Example: Validation Workflow

```yaml
name: Validate

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Validation Tools
        id: tools
        uses: ./.github/actions/setup-arc-validation

      - name: Lint Dockerfiles
        run: |
          find . -name "Dockerfile" -exec hadolint {} \;

      - name: Security scan
        run: |
          trivy fs --severity CRITICAL,HIGH .

      - name: Check shell scripts
        run: |
          shellcheck scripts/**/*.sh

      - name: Report cache status
        run: |
          echo "Tools cache hit: ${{ steps.tools.outputs.cache-hit }}"
```

## Hadolint Configuration

Configure hadolint via `.hadolint.yaml`:

```yaml
ignored:
  - DL3008  # Pin versions in apt-get install
trustedRegistries:
  - ghcr.io
```

## Trivy Configuration

Configure trivy via `trivy.yaml`:

```yaml
severity:
  - CRITICAL
  - HIGH
ignore-unfixed: true
```
