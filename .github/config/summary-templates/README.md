# Job Summary Templates

This directory contains Jinja2 templates for generating GitHub Actions job summaries.

## Templates

| Template | Purpose | Used By |
|----------|---------|---------|
| `build-summary.md.j2` | Build results with timing and cache stats | `_reusable-build.yml` |
| `security-summary.md.j2` | CVE scan results with severity breakdown | `_reusable-security.yml` |
| `validation-summary.md.j2` | Linting and validation results | `_reusable-validate.yml` |
| `deployment-summary.md.j2` | Deployment status with URLs | `main-deploy.yml` |

## JSON Schema

Templates expect JSON input with the following structure:

### Build Results
```json
{
  "builds": [
    {
      "service": "arc-sherlock-brain",
      "status": "success",
      "duration": "2m 15s",
      "duration_seconds": 135,
      "size": "256MB",
      "cache_hit": "92%"
    }
  ],
  "timing": [
    {"phase": "Setup", "duration": "15s"},
    {"phase": "Build", "duration": "1m 45s"},
    {"phase": "Push", "duration": "15s"}
  ],
  "errors": []
}
```

### Security Results
```json
{
  "vulnerabilities": {
    "CRITICAL": 0,
    "HIGH": 2,
    "MEDIUM": 5,
    "LOW": 10
  },
  "cves": [
    {
      "id": "CVE-2024-1234",
      "severity": "HIGH",
      "package": "requests",
      "version": "2.25.0",
      "fixed": "2.31.0"
    }
  ]
}
```

### Validation Results
```json
{
  "checks": [
    {
      "name": "Dockerfile Lint",
      "passed": false,
      "warning": false,
      "file": "services/brain/Dockerfile",
      "details": "DL3008: Pin versions in apt-get install"
    }
  ],
  "errors": [
    {
      "type": "Dockerfile Lint Error",
      "message": "DL3008 warning: Pin versions in apt-get install",
      "file": "services/brain/Dockerfile",
      "line": 12,
      "fix": "Change `apt-get install package` to `apt-get install package=1.2.3`",
      "doc_title": "Hadolint Rules",
      "doc_url": "https://github.com/hadolint/hadolint#rules"
    }
  ]
}
```

### Deployment Results
```json
{
  "deployments": [
    {
      "service": "arc-sherlock-brain",
      "env": "dev",
      "status": "success",
      "image": "ghcr.io/arc/brain:dev-abc1234",
      "url": "https://dev.arc.example.com"
    }
  ]
}
```

## Error Diagnostics

The `errors` array supports intelligent failure diagnostics:

```json
{
  "errors": [
    {
      "type": "Build Error",
      "message": "The specific error message",
      "file": "path/to/file",
      "line": 42,
      "fix": "Suggested fix steps",
      "doc_title": "Link text",
      "doc_url": "https://docs.example.com/troubleshooting"
    }
  ]
}
```

## Usage

Templates are rendered by the `arc-job-summary` composite action:

```yaml
- uses: ./.github/actions/arc-job-summary
  with:
    title: 'Build Results'
    status: 'success'
    summary-type: 'build'
    results-json: 'results.json'
    show-diagnostics: 'true'
    show-timing: 'true'
```
