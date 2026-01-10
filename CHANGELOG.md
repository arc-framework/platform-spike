# Changelog

All notable changes to the A.R.C. Platform will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Phase 1: Sherlock LLM Integration
- Phase 2: Voice Pipeline (Piper, Scarlett)
- Phase 3: Safety Layer (Guard, Ramsay)

---

## [002-stabilize-framework] - 2026-01-11

### Added

**Directory Structure**
- Three-tier directory organization: `core/`, `plugins/`, `services/`
- README.md files for all tier directories
- Service categorization decision tree

**Docker Infrastructure**
- Base image: `arc-base-python-ai` (Python 3.11 Alpine)
- Dockerfile templates for Python and Go services
- `.dockerignore` files for all services
- Docker standards documentation

**Validation Tooling**
- `check-structure.py` - Directory structure validator
- `check-service-registry.py` - SERVICE.MD validator
- `check-dockerfile-standards.py` - Dockerfile compliance checker
- `check-dockerfiles.sh` - Hadolint wrapper
- `check-security.sh` - Trivy security scanner
- `analyze-dependencies.py` - Image dependency analyzer
- `check-build-impact.sh` - Build impact analysis
- `check-image-sizes.py` - Image size validator
- `track-build-times.sh` - Build performance tracker
- `validate-all.sh` - Master validation orchestrator
- `verify-quickstart.sh` - Documentation verification
- `check-doc-links.py` - Documentation link checker

**CI/CD Workflows**
- `validate-structure.yml` - Structure validation on PR
- `validate-docker.yml` - Dockerfile linting
- `security-scan.yml` - Daily security scanning
- `build-base-images.yml` - Base image CI/CD
- `track-build-performance.yml` - Build metrics tracking

**Documentation**
- `DOCKER-STANDARDS.md` - Docker best practices
- `DIRECTORY-DESIGN.md` - Directory structure design
- `DIRECTORY-STRUCTURE.md` - Architecture diagram
- `DOCKER-IMAGE-HIERARCHY.md` - Image relationships
- `SERVICE-CATEGORIZATION.md` - Service placement guide
- `SERVICE-ROADMAP.md` - Development roadmap (34 services)
- `SCALING-STRATEGY.md` - Growth planning
- `METRICS-DASHBOARD-DESIGN.md` - Observability design
- `MIGRATION-GUIDE.md` - Service migration guide
- `SECURITY-SCANNING.md` - Security scanning guide
- `DOCKER-BUILD-OPTIMIZATION.md` - Build performance guide
- `VALIDATION-FAILURES.md` - Troubleshooting guide
- `IMAGE-TAGGING.md` - Versioning guide
- `GHCR-PUBLISHING.md` - Registry guide
- `BASE-IMAGE-MIGRATION.md` - Base image migration path

**Architecture Decision Records**
- `ADR-000` - Template
- `ADR-001` - Codename Convention
- `ADR-002` - Three-Tier Directory Structure

**Service Generator**
- `scripts/create-service.sh` - Scaffold new services

**Configuration**
- `.hadolint.yaml` - Dockerfile linting rules
- `.shellcheckrc` - Shell script linting
- `.pre-commit-config.yaml` - Pre-commit hooks
- Validation contracts and schemas

### Changed

**SERVICE.MD**
- Added directory location column
- Added capacity planning section
- Added service lifecycle states
- Added categorization decision tree

**Dockerfiles**
- Standardized OCI labels across all services
- Added HEALTHCHECK to all services
- Ensured non-root user for all services
- Optimized layer ordering for cache efficiency

**README.md**
- Added CI/CD status badges
- Updated directory structure description
- Added validation instructions

### Security

- All Dockerfiles pass hadolint validation
- No :latest tags in any Dockerfile
- All services run as non-root user
- Security scanning baseline documented
- No HIGH/CRITICAL CVEs in current images

---

## [001-realtime-media] - 2025-12-XX

### Added
- LiveKit integration for WebRTC
- arc-scarlett-voice agent (stub)
- arc-piper-tts service (stub)
- Voice pipeline architecture

---

## [000-initial-setup] - 2025-11-09

### Added
- Initial platform infrastructure
- Docker Compose configuration
- Core services (PostgreSQL, Redis, NATS, Pulsar)
- Plugin services (Grafana, Prometheus, Loki, Jaeger)
- Security services (Kratos, Infisical)
- raymond Go utility service
- arc-sherlock-brain Python service (stub)
- Option C naming convention
- Security fixes (Phase 1 complete)

### Security
- Removed weak default passwords
- Fixed hardcoded secrets
- Added resource limits
- Configured log rotation
- Secured admin interfaces

---

## Version History

| Version | Date | Summary |
|---------|------|---------|
| 002-stabilize-framework | 2026-01-11 | Framework stabilization, Docker excellence |
| 001-realtime-media | 2025-12-XX | Voice pipeline integration |
| 000-initial-setup | 2025-11-09 | Initial platform setup |

---

## Contributors

- A.R.C. Platform Team
