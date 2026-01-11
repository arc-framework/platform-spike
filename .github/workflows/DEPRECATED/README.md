# Deprecated Workflows

This directory contains workflows that have been replaced by the new CI/CD architecture.

## Deprecation Policy

- Workflows are moved here when replaced by new orchestration workflows
- **30-day grace period** before deletion
- After grace period, files are archived and removed

## Replaced Workflows

| Old Workflow | Replaced By | Deprecation Date | Delete After |
|--------------|-------------|------------------|--------------|
| `docker-publish.yml` | `publish-vendor-images.yml` | TBD | TBD |
| `publish-communication.yml` | `publish-vendor-images.yml` | TBD | TBD |
| `publish-data-services.yml` | `publish-vendor-images.yml` | TBD | TBD |
| `publish-gateway.yml` | `publish-vendor-images.yml` | TBD | TBD |
| `publish-observability.yml` | `publish-vendor-images.yml` | TBD | TBD |
| `publish-tools.yml` | `publish-vendor-images.yml` | TBD | TBD |
| `reusable-publish.yml` | `_reusable-publish-group.yml` | TBD | TBD |
| `security-scan.yml` | `scheduled-maintenance.yml` | TBD | TBD |
| `validate-docker.yml` | `pr-checks.yml` | TBD | TBD |
| `validate-structure.yml` | `pr-checks.yml` | TBD | TBD |

## Why Deprecate Instead of Delete?

1. **Reference**: Developers can see old implementation for comparison
2. **Rollback**: Emergency fallback if new workflows have issues
3. **Audit Trail**: Track what changed and when
4. **Gradual Migration**: Team can adapt to new workflows

## Re-enabling a Deprecated Workflow

In case of emergency:

1. Copy workflow from `DEPRECATED/` to `../`
2. Test with `workflow_dispatch`
3. Create issue documenting the rollback
4. Investigate root cause of new workflow failure

## Questions?

See [CI/CD Developer Guide](../../../docs/guides/CICD-DEVELOPER-GUIDE.md)
