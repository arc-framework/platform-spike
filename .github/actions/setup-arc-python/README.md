# Setup A.R.C. Python Environment

Composite action to setup Python with pip caching and common development tools.

## Purpose

Provides consistent Python environment setup across all A.R.C. workflows:
- Python 3.11 with pip caching
- Common development tools (ruff, black, mypy, pytest)
- Environment variables for reproducible builds

## Usage

### Basic Usage

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Python
    uses: ./.github/actions/setup-arc-python
```

### With Custom Version

```yaml
steps:
  - name: Setup Python 3.12
    uses: ./.github/actions/setup-arc-python
    with:
      python-version: '3.12'
```

### Without Development Tools

```yaml
steps:
  - name: Setup Python (minimal)
    uses: ./.github/actions/setup-arc-python
    with:
      install-tools: 'false'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `python-version` | Python version to install | No | `3.11` |
| `install-tools` | Install dev tools (ruff, black, mypy, pytest) | No | `true` |
| `working-directory` | Working directory for pip install | No | `.` |

## Outputs

| Output | Description |
|--------|-------------|
| `python-version` | The installed Python version |
| `cache-hit` | Whether the pip cache was hit (`true`/`false`) |

## Installed Tools

When `install-tools: true`:

| Tool | Purpose |
|------|---------|
| `ruff` | Fast Python linter and formatter |
| `black` | Code formatter |
| `mypy` | Static type checker |
| `pytest` | Testing framework |
| `pytest-asyncio` | Async test support |

## Environment Variables

Sets the following environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `PYTHONUNBUFFERED` | `1` | Unbuffered stdout/stderr |
| `PYTHONDONTWRITEBYTECODE` | `1` | Don't create .pyc files |
| `PIP_DISABLE_PIP_VERSION_CHECK` | `1` | Suppress pip upgrade warnings |

## Cache Strategy

- Cache key based on `requirements*.txt` and `pyproject.toml` files
- Automatic cache invalidation on dependency changes
- Shared cache across workflow runs

## Example: Full Workflow

```yaml
name: Python CI

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        id: python
        uses: ./.github/actions/setup-arc-python

      - name: Lint with ruff
        run: ruff check src/

      - name: Type check with mypy
        run: mypy src/

      - name: Report cache status
        run: |
          echo "Cache hit: ${{ steps.python.outputs.cache-hit }}"
```
