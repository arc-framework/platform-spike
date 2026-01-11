# Setup A.R.C. Docker Environment

Composite action to setup Docker with GHCR login, BuildKit, and cache configuration.

## Purpose

Provides consistent Docker environment setup across all A.R.C. workflows:
- GHCR (GitHub Container Registry) authentication
- Docker Buildx for multi-platform builds
- BuildKit optimizations and caching

## Usage

### Basic Usage

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Docker
    uses: ./.github/actions/setup-arc-docker
    with:
      password: ${{ secrets.GITHUB_TOKEN }}
```

### Multi-Platform Build

```yaml
steps:
  - name: Setup Docker
    uses: ./.github/actions/setup-arc-docker
    with:
      password: ${{ secrets.GITHUB_TOKEN }}
      enable-buildx: 'true'

  - name: Build multi-arch image
    uses: docker/build-push-action@v5
    with:
      platforms: linux/amd64,linux/arm64
      push: true
      tags: ghcr.io/arc/my-service:latest
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `registry` | Container registry URL | No | `ghcr.io` |
| `username` | Registry username | No | `${{ github.actor }}` |
| `password` | Registry password/token | Yes | - |
| `enable-buildx` | Setup Docker Buildx | No | `true` |
| `cache-mode` | BuildKit cache mode | No | `max` |

## Outputs

| Output | Description |
|--------|-------------|
| `registry` | The configured registry |
| `buildx-version` | The installed Buildx version |

## Environment Variables

Sets the following environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `DOCKER_BUILDKIT` | `1` | Enable BuildKit |
| `BUILDKIT_INLINE_CACHE` | `1` | Enable inline cache metadata |

## Cache Strategy

Use with `docker/build-push-action` for optimal caching:

```yaml
- uses: docker/build-push-action@v5
  with:
    context: .
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

## Example: Full Build Workflow

```yaml
name: Build and Push

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - name: Setup Docker
        uses: ./.github/actions/setup-arc-docker
        with:
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: services/arc-sherlock-brain
          push: true
          tags: ghcr.io/arc/arc-sherlock-brain:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

## Permissions

Requires `packages: write` permission for pushing to GHCR:

```yaml
permissions:
  contents: read
  packages: write
```
