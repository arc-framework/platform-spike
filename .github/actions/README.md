# A.R.C. Composite Actions

Reusable composite actions for the A.R.C. Platform CI/CD pipeline.

## Purpose

Composite actions encapsulate repeated setup and utility steps, providing:
- **Consistency**: Same setup across all workflows
- **Maintainability**: Single source of truth for tool versions
- **Efficiency**: Cached dependencies and tools

## Available Actions

| Action | Purpose | Used By |
|--------|---------|---------|
| `setup-arc-python/` | Python 3.11 + pip cache + tools (ruff, black, mypy) | pr-checks, main-deploy |
| `setup-arc-docker/` | GHCR login + BuildKit + cache config | build, publish workflows |
| `setup-arc-validation/` | Install hadolint, trivy, shellcheck | pr-checks, security workflows |
| `arc-job-summary/` | Generate markdown job summaries | ALL workflows |
| `arc-notify/` | Send notifications (Slack, GitHub Issues) | deploy, security workflows |

## Usage Example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: ./.github/actions/setup-arc-python
        with:
          python-version: '3.11'

      - name: Setup Docker
        uses: ./.github/actions/setup-arc-docker
        with:
          registry: ghcr.io
```

## Action Structure

Each action follows this structure:

```
action-name/
├── action.yml    # Action definition
└── README.md     # Usage documentation
```

## Creating New Actions

1. Create directory: `.github/actions/{action-name}/`
2. Create `action.yml` with inputs, outputs, runs
3. Create `README.md` with usage examples
4. Test with minimal workflow before integrating

## Version Pinning

All external actions are pinned to SHA for security:

```yaml
# Good - pinned to SHA
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1

# Acceptable - pinned to major version
uses: actions/checkout@v4
```

## References

- [GitHub Composite Actions Documentation](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [A.R.C. CI/CD Architecture](../../docs/architecture/CICD-ARCHITECTURE.md)
