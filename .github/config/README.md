# A.R.C. CI/CD Configuration Files

JSON configuration files for GitHub Actions workflows.

## Purpose

Configuration files externalize data from workflow YAML, providing:
- **Maintainability**: Easy to update image lists without touching workflow logic
- **Readability**: Structured JSON is easier to parse than YAML multiline strings
- **Validation**: JSON schema validation possible
- **Reusability**: Same config can be used by multiple workflows

## Configuration Files

### Publish Configurations

| File | Purpose | Image Count |
|------|---------|-------------|
| `publish-gateway.json` | Gateway & Identity images | 4 |
| `publish-data.json` | Data service images (postgres, redis) | 5 |
| `publish-observability.json` | Observability stack (prometheus, grafana) | 6 |
| `publish-communication.json` | Messaging images (nats, pulsar) | 3 |
| `publish-tools.json` | Development tools | 5 |

### Policy Configurations

| File | Purpose |
|------|---------|
| `license-policy.json` | Allowed/blocked licenses for SBOM compliance |

## Schema

### Publish Configuration Schema

```json
{
  "images": [
    {
      "source": "vendor/image:tag",
      "target": "arc-codename-function",
      "platforms": ["linux/amd64", "linux/arm64"],
      "description": "Brief description"
    }
  ],
  "rate_limit_delay_seconds": 30,
  "retry_attempts": 3,
  "timeout_minutes": 10
}
```

### License Policy Schema

```json
{
  "allowed": ["MIT", "Apache-2.0", "BSD-3-Clause"],
  "blocked": ["GPL-3.0", "AGPL-3.0"],
  "review_required": ["LGPL-2.1", "MPL-2.0"]
}
```

## Usage in Workflows

```yaml
- name: Load publish config
  id: config
  run: |
    CONFIG=$(cat .github/config/publish-gateway.json)
    echo "images=$(echo $CONFIG | jq -c '.images')" >> $GITHUB_OUTPUT

- name: Build images
  strategy:
    matrix:
      image: ${{ fromJSON(steps.config.outputs.images) }}
```

## Validation

Validate JSON files before committing:

```bash
# Check JSON syntax
for f in .github/config/*.json; do
  python -m json.tool "$f" > /dev/null || echo "Invalid: $f"
done
```

## References

- [GitHub Actions Matrix Strategy](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs)
- [jq Manual](https://stedolan.github.io/jq/manual/)
