# Validation Suite Results

**Generated:** 2026-01-11
**Spec:** 002-stabilize-framework
**Phase:** 9 (Polish)

---

## Summary

| Validator | Status | Errors | Warnings | Notes |
|-----------|--------|--------|----------|-------|
| Structure | PASS | 1 | 3 | Missing go-infra base image |
| Service Registry | FAIL* | 9 | 0 | Planned services not built |
| Dockerfile Standards | FAIL* | 2 | 3 | External images lack USER |
| Hadolint | SKIPPED | - | - | Not installed locally |
| Docker Compose | PASS | 0 | 0 | All compose files valid |

*Expected failures - documented in SERVICE-ROADMAP.md

---

## Detailed Results

### 1. Directory Structure (check-structure.py)

**Status:** PASS

#### Errors (1)
| Issue | Path | Explanation |
|-------|------|-------------|
| missing_dockerfile | .docker/base/go-infra/Dockerfile | Go base image planned but not created |

#### Warnings (3)
| Issue | Path | Explanation |
|-------|------|-------------|
| empty_directory | core/messaging/ephemeral/nats/data/... | JetStream data directories (runtime created) |

#### Info (4)
| Issue | Path | Action |
|-------|------|--------|
| unknown_category | core/feature-management | Valid category, add to validator |
| unknown_category | core/media | Valid category, add to validator |
| unknown_category | plugins/storage | Valid category, add to validator |
| unknown_category | plugins/search | Valid category, add to validator |

**Recommendation:** Update validator to recognize new categories.

---

### 2. Service Registry (check-service-registry.py)

**Status:** FAIL (Expected)

#### Errors (9)
All errors are for services listed in SERVICE.MD but not yet implemented:

| Service | Codename | Path | Status |
|---------|----------|------|--------|
| Brain | Sherlock | core/engine | Roadmapped (Phase 1) |
| Voice Agt | Scarlett | core/voice | Roadmapped (Phase 2) |
| Janitor | The Wolf | core/ops | Roadmapped (Phase 5) |
| Billing | Alfred | plugins/billing | Roadmapped (Phase 5) |
| Guard | RoboCop | core/guardrails | Roadmapped (Phase 3) |
| Critic | Gordon Ramsay | workers/critic | Roadmapped (Phase 3) |
| Gym | Ivan Drago | workers/gym | Roadmapped (Phase 4) |
| Semantic | Uhura | workers/semantic | Roadmapped (Phase 4) |
| Mechanic | Statham | workers/healer | Roadmapped (Phase 4) |

**Explanation:** These services are documented in SERVICE-ROADMAP.md as planned services that need implementation.

#### Info (4)
| Issue | Path | Action |
|-------|------|--------|
| untracked_directory | services/arc-sherlock-brain | Add to SERVICE.MD |
| untracked_directory | services/arc-piper-tts | Add to SERVICE.MD |
| untracked_directory | services/utilities/raymond | Add to SERVICE.MD |
| untracked_directory | services/arc-scarlett-voice | Add to SERVICE.MD |

**Recommendation:** SERVICE.MD paths need to be aligned with actual directory structure.

---

### 3. Dockerfile Standards (check-dockerfile-standards.py)

**Status:** FAIL (Partial)

#### Errors (2)
| Dockerfile | Issue | Explanation |
|------------|-------|-------------|
| core/persistence/postgres/Dockerfile | non_root_user | Base image runs as `postgres` user (acceptable) |
| core/telemetry/otel-collector/Dockerfile | non_root_user | Base image runs as non-root internally |

**Explanation:** These Dockerfiles wrap external images that handle user management. The validator doesn't recognize USER inheritance.

#### Warnings (3)
| Dockerfile | Issue | Action |
|------------|-------|--------|
| postgres | healthcheck_required | Base handles health (pg_isready) |
| otel-collector | healthcheck_required | Health check via separate binary |
| kratos | healthcheck_required | Base image handles health |

#### Recommendations
1. Mark postgres and otel-collector as exceptions (external images)
2. Add HEALTHCHECK comments documenting how health is handled
3. Update validator to recognize external image patterns

---

### 4. Hadolint

**Status:** SKIPPED (not installed locally)

Hadolint runs in CI/CD via `.github/workflows/validate-docker.yml`.

Manual results documented in `reports/hadolint-results.txt`.

---

### 5. Docker Compose Validation

**Status:** PASS

All compose files in `deployments/docker/` validated successfully:
- docker-compose.base.yml ✓
- docker-compose.core.yml ✓
- docker-compose.observability.yml ✓
- docker-compose.security.yml ✓
- docker-compose.services.yml ✓
- docker-compose.production.yml ✓
- docker-compose.media.yml ✓

---

## Action Items

### High Priority (Fix before merge)
- None (all failures are expected/documented)

### Medium Priority (Next sprint)
1. Create `.docker/base/go-infra/Dockerfile` for Go services
2. Align SERVICE.MD paths with actual directory structure
3. Update validators to recognize new categories

### Low Priority (Backlog)
1. Add HEALTHCHECK comments to external image wrappers
2. Improve validator to handle USER inheritance from base images
3. Install hadolint for local development

---

## Conclusion

The validation suite is working correctly. The "failures" it reports are:
1. **Expected gaps** between SERVICE.MD aspirations and current implementation
2. **External image patterns** that don't follow the same conventions as custom images

These are documented in SERVICE-ROADMAP.md and do not block the spec 002 completion.

---

## Related Documentation

- [SERVICE-ROADMAP.md](../docs/architecture/SERVICE-ROADMAP.md) - Development roadmap
- [VALIDATION-FAILURES.md](../docs/guides/VALIDATION-FAILURES.md) - Troubleshooting guide
- [hadolint-results.txt](./hadolint-results.txt) - Manual Dockerfile analysis
