# Implementation Plan: A.R.C. Framework Stabilization & Docker Excellence

**Branch**: `002-stabilize-framework` | **Date**: January 10, 2026 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-stabilize-framework/spec.md`

---

## Summary

The A.R.C. Framework has grown organically with 25+ containerized services across infrastructure, core agents, workers, and sidecars. This feature stabilizes the platform by:

1. **Establishing production-grade directory structure** with clear categorization (core/plugins/services)
2. **Standardizing Dockerfiles** with shared base images, multi-stage builds, and security hardening
3. **Automating validation** to prevent drift between documentation (SERVICE.MD) and actual implementation

**Primary Goals:**
- Reduce developer onboarding time from days to hours through intuitive structure
- Eliminate security vulnerabilities through standardized base images and automated scanning
- Improve build efficiency from 5+ minute builds to <60 second incremental builds
- Prevent documentation drift through CI/CD validation

**Technical Approach:**
- Research best practices from Kubernetes, Istio, Docker, and CNCF projects
- Create language-specific base images (Go/Python/Node) following security hardening standards
- Implement validation scripts that enforce alignment between SERVICE.MD and directory structure
- Gradual rollout with backward compatibility maintained during migration

---

## Technical Context

**Primary Languages/Versions:**
- **Go**: 1.21+ (Infrastructure & CLI tooling - future use)
- **Python**: 3.11-3.12 (AI agents, reasoning engines - primary)
- **Shell**: Bash/Zsh (Scripts and Make targets)

**Primary Dependencies:**
- **Docker Engine**: 24.0+ with BuildKit support
- **Docker Compose**: v2.20+ for orchestration
- **Alpine Linux**: 3.19+ as base OS (minimal attack surface)
- **Makefile**: GNU Make for orchestration
- **GitHub Actions**: CI/CD automation

**Container Registry:**
- **GHCR** (GitHub Container Registry): `ghcr.io/arc/*`
- **Naming Convention**: Marvel/Hollywood codenames (e.g., `arc-sherlock-brain`, `arc-heimdall-gateway`)

**Storage:**
- **Git Repository**: Filesystem-based structure
- **Docker Volumes**: Persistent data storage
- **GHCR**: Image artifact storage

**Testing:**
- **Dockerfile Linting**: `hadolint` for Dockerfile best practices
- **Security Scanning**: `trivy` or `grype` for vulnerability detection
- **Structure Validation**: Custom Python/Go scripts for SERVICE.MD alignment
- **Integration Tests**: Docker Compose-based health checks

**Target Platform:**
- **Development**: macOS (Apple Silicon + Intel), Linux, Windows WSL2
- **Staging/Production**: Linux amd64 containers
- **Orchestration**: Docker Compose (current), Kubernetes-ready (future)

**Project Type**: Platform-in-a-Box (Multi-service polyglot infrastructure)

**Performance Goals:**
- **Build Times**: <60 seconds for incremental code changes (85%+ cache hit rate)
- **Image Sizes**: Go <50MB, Python <500MB, Infrastructure <100MB
- **Security Scans**: Complete platform audit in <5 minutes
- **Developer Onboarding**: Locate any service Dockerfile in <2 minutes

**Constraints:**
- **Zero Downtime**: Production services must remain available during migration
- **Backward Compatibility**: Old image names in GHCR remain available for 3+ months
- **Polyglot Support**: Must accommodate Go, Python, Node.js with language-specific optimizations
- **CI/CD Budget**: Total pipeline time must remain <15 minutes; validation adds <2 minutes
- **Security Compliance**: Zero HIGH/CRITICAL vulnerabilities before production deployment

**Scale/Scope:**
- **Current Services**: 25+ containerized services (INFRA, CORE, WORKER, SIDECAR types)
- **Dockerfiles to Audit**: 7 existing + templates for future services
- **Directory Categories**: 3 top-level (core/, plugins/, services/) + deployments/, docs/, libs/
- **Documentation Files**: 50+ markdown files requiring path updates
- **Team Size**: Small team (2-5 developers) - automation is critical

---

## Architecture Validation

✅ **Constitution Check Passed:** Three-tier structure (core/plugins/services), language-specific base images, and automated validation align with simplicity principles. No over-engineering detected. Multi-stage builds and SERVICE.MD centralization are justified by platform polyglot nature and scale (25+ services).

---

## Project Structure

### Documentation (this feature)

```text
specs/002-stabilize-framework/
├── plan.md              # This file (Implementation plan)
├── research.md          # Phase 0: Best practices research
├── docker-standards.md  # Phase 1: Dockerfile standards & patterns
├── directory-design.md  # Phase 1: Directory structure design
├── validation-spec.md   # Phase 1: Automated validation design
├── migration-guide.md   # Phase 1: Step-by-step migration instructions
├── quickstart.md        # Quick reference for developers
├── checklists/
│   └── requirements.md  # Quality validation checklist (already exists)
└── contracts/
    ├── base-images.md           # Base image specifications
    ├── dockerfile-template.md   # Dockerfile templates per language
    └── validation-api.md        # Validation script interfaces
```

### Source Code (repository root)

**Current Structure** (before refactoring):

```text
platform-spike/
├── core/                        # Essential infrastructure
│   ├── caching/redis/          # arc-sonic-cache (Redis)
│   ├── feature-management/     # arc-mystique-flags (Unleash)
│   ├── gateway/traefik/        # arc-heimdall-gateway (Traefik)
│   ├── media/livekit/          # arc-daredevil-voice (LiveKit)
│   ├── messaging/
│   │   ├── ephemeral/nats/    # arc-flash-pulse (NATS)
│   │   └── durable/pulsar/    # arc-strange-stream (Pulsar)
│   ├── persistence/postgres/   # arc-oracle-sql (Postgres+pgvector)
│   ├── secrets/infisical/      # arc-fury-vault (Infisical)
│   └── telemetry/otel-collector/ # arc-widow-otel (OTEL)
├── plugins/                     # Optional/swappable components
│   ├── observability/
│   │   ├── logging/loki/       # arc-watson-logs (Loki)
│   │   ├── metrics/prometheus/ # arc-house-metrics (Prometheus)
│   │   ├── tracing/jaeger/     # arc-columbo-traces (Jaeger)
│   │   └── visualization/grafana/ # arc-friday-viz (Grafana)
│   ├── search/                 # Future: arc-cerebro-vector (Qdrant)
│   ├── security/identity/kratos/ # arc-jarvis-identity (Kratos)
│   └── storage/                # Future: arc-tardis-storage (MinIO)
├── services/                    # Application logic
│   ├── arc-piper-tts/          # TTS service
│   ├── arc-scarlett-voice/     # Voice agent
│   ├── arc-sherlock-brain/     # LangGraph reasoning engine
│   └── utilities/raymond/      # Utility service
├── deployments/                 # Deployment configurations
│   ├── docker/                 # Docker Compose files
│   │   ├── docker-compose.base.yml
│   │   ├── docker-compose.core.yml
│   │   ├── docker-compose.observability.yml
│   │   ├── docker-compose.security.yml
│   │   └── docker-compose.services.yml
│   ├── kubernetes/             # Future K8s manifests
│   └── terraform/              # Future IaC
├── libs/                        # Shared libraries
│   └── python-sdk/             # arc_common Python SDK
├── docs/                        # Documentation
│   ├── architecture/           # ADRs and design docs
│   ├── guides/                 # How-to guides
│   └── reference/              # API reference
├── scripts/                     # Automation scripts
│   ├── setup/                  # Setup scripts
│   └── validate/               # Validation scripts (NEW)
├── tools/                       # Development tools
├── tests/                       # Integration tests
├── Makefile                    # Orchestration commands
├── SERVICE.MD                  # Service registry (source of truth)
└── .env.example                # Environment template
```

**Proposed Enhancements** (Phase 1 Design):

```text
# NEW: Base Docker images (shared across services)
.docker/
├── base/
│   ├── go-infra/
│   │   ├── Dockerfile
│   │   └── README.md
│   └── python-ai/
│       ├── Dockerfile
│       └── README.md
└── README.md

# NEW: Dockerfile templates
.templates/
├── Dockerfile.go.template
├── Dockerfile.python.template
└── README.md

# NEW: Validation scripts
scripts/validate/
├── check-structure.py          # Validates SERVICE.MD vs directories
├── check-dockerfiles.sh        # Runs hadolint on all Dockerfiles
├── check-security.sh           # Runs trivy/grype security scans
├── check-image-sizes.py        # Validates image size targets
└── README.md

# ENHANCED: CI/CD workflows
.github/
├── workflows/
│   ├── validate-structure.yml  # NEW: Runs on PR
│   ├── build-base-images.yml   # NEW: Builds shared bases
│   └── security-scan.yml       # NEW: Scans for vulnerabilities
└── instructions/
    └── dockerfile-standards.md  # NEW: Standards for developers
```

**Structure Decision:**

- **Keep current three-tier structure** (core/plugins/services) - it's working well
- **Add `.docker/` directory** for shared base images (prevents cluttering core/)
- **Add `.templates/` directory** for Dockerfile templates (discovery via docs)
- **Enhance `scripts/validate/`** for automated checks (CI/CD integration)
- **No breaking changes** - only additions and documentation updates


## Phase 0: Research & Discovery

**Objective:** Research industry best practices for Docker image management and directory structures in polyglot platforms.

**Deliverable:** Complete [`research.md`](./research.md) covering:

1. **Directory Structure Best Practices** - Study Kubernetes, Istio, Prometheus for service organization patterns
2. **Dockerfile Security Hardening** - Review CIS Docker Benchmark, NIST SP 800-190, Snyk best practices
3. **Base Image Strategies** - Evaluate Google Distroless, Chainguard, Alpine vs Debian Slim
4. **Build Performance Optimization** - Research Docker BuildKit layer caching and cache mount strategies
5. **Validation Automation** - Evaluate hadolint, trivy, grype, conftest for automated enforcement

**Timeline:** 1 week (parallel research across 5 areas)  
**Output:** Detailed findings, recommendation matrix, and approach comparison in `research.md`

**See:** [`research.md`](./research.md) for complete research template and findings.

---

## Phase 1: Design & Planning

**Objective:** Design the new structure, standards, and validation systems based on research findings.

### Design Deliverables

#### 1. Docker Standards Document (`docker-standards.md`)

Define comprehensive Dockerfile standards:

**Section 1: Security Requirements (MUST)**
- Non-root user (UID 1000, explicit USER instruction)
- Pinned base image versions (no `:latest` tags)
- Multi-stage builds (separate build from runtime)
- Minimal attack surface (remove build tools, package managers)
- Security labels (OCI annotations for tracking)
- Health checks (Docker HEALTHCHECK or application-level)

**Section 2: Build Optimization (SHOULD)**
- Layer ordering: OS packages → dependencies → application code
- Cache mount for package managers (`--mount=type=cache`)
- `.dockerignore` to exclude unnecessary files
- Combine RUN commands to reduce layers
- COPY only what's needed (avoid `COPY . .`)

**Section 3: Language-Specific Patterns**

**Go Services** (Infrastructure, CLI):
```dockerfile
# RECOMMENDED PATTERN
FROM golang:1.21-alpine3.19 AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o app

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=builder /build/app /app
RUN addgroup -g 1000 arcuser && adduser -D -u 1000 -G arcuser arcuser
USER arcuser
ENTRYPOINT ["/app"]
```

**Python Services** (AI, Agents):
```dockerfile
# RECOMMENDED PATTERN
FROM python:3.11-alpine3.19 AS builder
WORKDIR /build
RUN apk add --no-cache build-base postgresql-dev
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -r requirements.txt

FROM python:3.11-alpine3.19
RUN apk add --no-cache libpq curl
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
COPY src/ /app/src/
WORKDIR /app
RUN addgroup -g 1000 arcuser && adduser -D -u 1000 -G arcuser arcuser && \
    chown -R arcuser:arcuser /app
USER arcuser
CMD ["python", "-m", "src.main"]
```

**Node.js Services** (Frontend, if applicable):
```dockerfile
# RECOMMENDED PATTERN
FROM node:20-alpine3.19 AS builder
WORKDIR /build
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --only=production

FROM node:20-alpine3.19
WORKDIR /app
COPY --from=builder /build/node_modules ./node_modules
COPY . .
RUN addgroup -g 1000 arcuser && adduser -D -u 1000 -G arcuser arcuser && \
    chown -R arcuser:arcuser /app
USER arcuser
CMD ["node", "server.js"]
```

**Section 4: Image Size Targets**
- Go services: <50MB (statically compiled binaries)
- Python services: <500MB (runtime + dependencies)
- Infrastructure: <100MB (minimal OS + runtime)

**Section 5: Labels & Metadata**
```dockerfile
LABEL org.opencontainers.image.title="arc-sherlock-brain" \
      org.opencontainers.image.description="LangGraph reasoning engine" \
      org.opencontainers.image.version="0.1.0" \
      arc.service.codename="sherlock" \
      arc.service.role="brain" \
      arc.service.tier="services"
```

#### 2. Directory Structure Design (`directory-design.md`)

Document the three-tier structure with clear inclusion criteria:

**Tier 1: core/** (Essential Infrastructure)
- **Criteria:** Service is required for platform to function; cannot be swapped without major refactoring
- **Examples:** Gateway (Traefik), Messaging (NATS/Pulsar), Persistence (Postgres), Cache (Redis)
- **Naming:** `core/{category}/{tech}/` (e.g., `core/gateway/traefik/`)

**Tier 2: plugins/** (Optional Components)
- **Criteria:** Service is swappable; alternatives exist; not all deployments need it
- **Examples:** Identity (Kratos), Observability (Loki/Prometheus/Jaeger/Grafana)
- **Naming:** `plugins/{category}/{tech}/` (e.g., `plugins/observability/logging/loki/`)

**Tier 3: services/** (Application Logic)
- **Criteria:** Business logic, agents, workers; specific to A.R.C. framework
- **Examples:** Sherlock (Brain), Scarlett (Voice), Piper (TTS)
- **Naming:** `services/{arc-codename}/` (e.g., `services/arc-sherlock-brain/`)

**Supporting Directories:**
- `deployments/`: Deployment configurations (Docker Compose, K8s, Terraform)
- `libs/`: Shared libraries (Python SDK, Go packages)
- `docs/`: Documentation (architecture, guides, reference)
- `scripts/`: Automation scripts (setup, validation, migration)
- `tools/`: Development tools (linters, generators)
- `tests/`: Integration tests
- `.docker/`: Base images
- `.templates/`: Dockerfile templates

**Growth Strategy:** As services scale to 50+, consider sub-categorization:
- `services/agents/` (Sherlock, Scarlett)
- `services/workers/` (Critic, Gym)
- `services/utilities/` (Raymond)

#### 3. Base Images Design (`contracts/base-images.md`)

**Base Image 1: arc-base-go-infra**
- **Base:** `golang:1.21-alpine3.19` (builder), `alpine:3.19` (runtime)
- **Purpose:** Go services (infrastructure, CLI tools) - future use
- **Includes:** ca-certificates, timezone data
- **Size Target:** <20MB (runtime stage)
- **Use Cases:** Custom CLI tools, infrastructure controllers

**Base Image 2: arc-base-python-ai**
- **Base:** `python:3.11-alpine3.19`
- **Purpose:** Python AI services (agents, reasoning engines) - primary platform language
- **Includes:** Common AI dependencies (PostgreSQL client, NATS client, OTEL SDK)
- **Size Target:** <300MB
- **Use Cases:** Sherlock (brain), Scarlett (voice), Piper (TTS), Ramsay (critic), Drago (gym)

**Build Strategy:**
- Base images build automatically on version updates (GitHub Actions)
- Published to GHCR: `ghcr.io/arc/base-go-infra:1.21-alpine3.19`
- Services reference by digest for reproducibility
- **Note:** Only 2 base images needed (Go for future infra, Python for current AI services)

#### 4. Validation Design (`validation-spec.md`)

**Validation Script 1: Structure Consistency (`scripts/validate/check-structure.py`)**
```python
# Pseudocode
def validate_structure():
    services = parse_service_md()
    for service in services:
        # Check directory exists
        expected_path = map_service_to_path(service)
        assert path_exists(expected_path), f"{service} directory missing"
        
        # Check Dockerfile exists
        dockerfile = f"{expected_path}/Dockerfile"
        assert file_exists(dockerfile), f"{service} Dockerfile missing"
        
        # Check naming consistency
        assert service_name_matches_codename(service)
    
    return validation_report
```

**Validation Script 2: Dockerfile Linting (`scripts/validate/check-dockerfiles.sh`)**
```bash
#!/bin/bash
# Run hadolint on all Dockerfiles
find . -name "Dockerfile" -not -path "*/node_modules/*" | while read -r dockerfile; do
    echo "Linting: $dockerfile"
    hadolint "$dockerfile" || exit 1
done
```

**Validation Script 3: Security Scanning (`scripts/validate/check-security.sh`)**
```bash
#!/bin/bash
# Run trivy on all images
docker images --format "{{.Repository}}:{{.Tag}}" | grep "^arc-" | while read -r image; do
    echo "Scanning: $image"
    trivy image --severity HIGH,CRITICAL "$image" || exit 1
done
```

**Validation Script 4: Image Size Check (`scripts/validate/check-image-sizes.py`)**
```python
# Pseudocode
SIZE_LIMITS = {
    "go": 50 * 1024 * 1024,      # 50MB
    "python": 500 * 1024 * 1024,  # 500MB
    "node": 200 * 1024 * 1024,    # 200MB
}

def validate_image_sizes():
    images = docker.list_images(filter="arc-*")
    for image in images:
        language = detect_language(image)
        size = image.size
        limit = SIZE_LIMITS[language]
        assert size <= limit, f"{image} exceeds size limit ({size} > {limit})"
```

**CI/CD Integration:**
- GitHub Actions workflow: `.github/workflows/validate-structure.yml`
- Runs on every PR and commit to main
- Fails build if any validation fails
- Reports results as PR comments

#### 5. Migration Guide (`migration-guide.md`)

Step-by-step guide for migrating existing services:

**Phase 1: Audit (Week 1)**
1. Run security scans on all existing Dockerfiles
2. Document current issues and technical debt
3. Prioritize fixes (HIGH/CRITICAL vulnerabilities first)

**Phase 2: Base Images (Week 2)**
1. Create arc-base-go-infra, arc-base-python-ai, arc-base-node-frontend
2. Publish to GHCR with version tags
3. Test base images in isolation

**Phase 3: Service Migration (Weeks 3-4)**
1. Migrate one service per day (starting with lowest risk)
2. Update Dockerfile to use base image
3. Test build, deploy to staging, validate functionality
4. Update documentation and SERVICE.MD if needed

**Phase 4: Validation Automation (Week 5)**
1. Implement validation scripts
2. Integrate into GitHub Actions
3. Run full platform validation
4. Fix any discovered issues

**Phase 5: Documentation (Week 6)**
1. Update all docs/ references
2. Create quickstart.md for developers
3. Record demo video for team onboarding
4. Hold team Q&A session

**Rollback Plan:**
- Keep old Dockerfiles in `.deprecated/` for 3 months
- Maintain old GHCR images with `:legacy` tags
- Document rollback procedure in migration-guide.md

---

## Phase 2: Implementation

**Objective:** Execute the migration plan incrementally with continuous validation.

### Implementation Steps

#### Step 1: Create Base Images
- Implement `.docker/base/` directory structure
- Create Dockerfiles for go-infra and python-ai (2 base images, not 3)
- Add GitHub Actions workflow to build and publish base images
- Test base images in isolation
- **Note:** Node.js base image not needed - A.R.C. is Go + Python only

#### Step 2: Audit Existing Dockerfiles
- Run hadolint on all 7 existing Dockerfiles
- Run trivy security scans
- Document issues in migration tracker
- Prioritize fixes (HIGH/CRITICAL first)

#### Step 3: Implement Validation Scripts
- Create `scripts/validate/check-structure.py`
- Create `scripts/validate/check-dockerfiles.sh`
- Create `scripts/validate/check-security.sh`
- Create `scripts/validate/check-image-sizes.py`
- Test scripts manually before CI/CD integration

#### Step 4: Migrate Services (Incremental)
**Order:** Start with lowest-risk services

1. **arc-oracle-sql** (Postgres): Already uses pgvector base, minimal changes
2. **arc-widow-otel** (OTEL Collector): Configuration-only, low risk
3. **arc-piper-tts**: Simple Python service, good test case
4. **arc-sherlock-brain**: Complex dependencies, validate carefully
5. **arc-scarlett-voice**: Depends on Sherlock, migrate after brain
6. **utilities/raymond**: Utility service, low priority
7. **Kratos Dockerfile**: Plugin, minimal changes

**For each service:**
- Create feature branch: `002-migrate-{service}`
- Update Dockerfile using standards
- Test build locally
- Deploy to staging
- Validate functionality
- Update documentation
- Merge to main

#### Step 5: CI/CD Integration
- Add `.github/workflows/validate-structure.yml`
- Add `.github/workflows/build-base-images.yml`
- Add `.github/workflows/security-scan.yml`
- Test workflows on feature branch
- Enable required checks on main branch

#### Step 6: Documentation Updates
- Update `docs/guides/` with new Dockerfile standards
- Update SERVICE.MD with directory paths
- Create `specs/002-stabilize-framework/quickstart.md`
- Update README.md with new structure
- Create Architecture Decision Records (ADRs)

#### Step 7: Makefile Enhancements
Add new Make targets:

```makefile
# Validation targets
validate-structure:
	@scripts/validate/check-structure.py

validate-dockerfiles:
	@scripts/validate/check-dockerfiles.sh

validate-security:
	@scripts/validate/check-security.sh

validate-images:
	@scripts/validate/check-image-sizes.py

validate-all: validate-structure validate-dockerfiles validate-security validate-images
	@echo "✓ All validations passed"

# Build base images
build-base-images:
	@docker build -t ghcr.io/arc/base-go-infra:latest .docker/base/go-infra/
	@docker build -t ghcr.io/arc/base-python-ai:latest .docker/base/python-ai/

# Audit existing setup
audit-dockerfiles:
	@find . -name "Dockerfile" -exec hadolint {} \;

audit-security:
	@scripts/validate/check-security.sh --report

audit-all: audit-dockerfiles audit-security
	@echo "✓ Audit complete"
```

Update `.PHONY` declarations and help text.

---

## Phase 3: Validation & Testing

**Objective:** Ensure migration meets all success criteria defined in spec.

### Validation Checklist

#### Structure Validation
- [ ] All services in SERVICE.MD have corresponding directories
- [ ] Directory naming matches codename conventions
- [ ] No orphaned directories (not in SERVICE.MD)
- [ ] All services have Dockerfiles
- [ ] All services have README.md files

#### Dockerfile Standards
- [ ] All production Dockerfiles use multi-stage builds
- [ ] All production images run as non-root users (UID 1000)
- [ ] All base images use pinned versions (no `:latest`)
- [ ] All Dockerfiles pass hadolint with no errors
- [ ] All images have proper OCI labels

#### Security Compliance
- [ ] Zero HIGH/CRITICAL vulnerabilities in base images
- [ ] All images scanned with trivy or grype
- [ ] Security scan results documented
- [ ] All services follow CIS Docker Benchmark

#### Build Performance
- [ ] Incremental builds (code changes) complete in <60 seconds
- [ ] Cache hit rate is 85%+ for incremental builds
- [ ] Build times measured and documented

#### Image Sizes
- [ ] Go services: <50MB
- [ ] Python services: <500MB
- [ ] Infrastructure services: <100MB
- [ ] Image sizes tracked and documented

#### Automation
- [ ] CI/CD runs validation on every PR
- [ ] Failed validations block PR merges
- [ ] Validation results posted as PR comments
- [ ] Build failures provide actionable error messages

#### Documentation
- [ ] `docs/guides/dockerfile-standards.md` created
- [ ] `docs/architecture/directory-structure.md` updated
- [ ] SERVICE.MD paths verified
- [ ] All doc path references updated
- [ ] Migration guide completed

#### Developer Experience
- [ ] New developers can locate Dockerfile in <2 minutes (tested)
- [ ] Build errors are clear and actionable
- [ ] Make targets work on macOS, Linux, Windows WSL2
- [ ] Documentation is clear and comprehensive

---

## Phase 4: Rollout & Monitoring

**Objective:** Deploy changes to production safely with monitoring and rollback capability.

### Rollout Strategy

#### Week 1: Feature Branch Development
- Create `002-stabilize-framework` branch
- Implement base images and validation scripts
- Test in isolated environment
- Peer review

#### Week 2-3: Service Migration
- Migrate services incrementally (1-2 per day)
- Each service gets its own sub-branch
- Deploy to staging after each migration
- Run full test suite
- Update documentation

#### Week 4: CI/CD Integration
- Enable validation workflows
- Test with sample PRs
- Fix any workflow issues
- Enable required checks

#### Week 5: Staging Deployment
- Deploy full stack to staging environment
- Run extended integration tests
- Performance benchmarking
- Security audit
- Team review

#### Week 6: Production Rollout
- Schedule maintenance window (if needed)
- Deploy new images to production
- Monitor for 48 hours
- Collect developer feedback
- Address any issues

### Monitoring Metrics

**Build Metrics:**
- Build times (track p50, p90, p99)
- Cache hit rates
- Build failure rates
- Time to recovery (TTR)

**Image Metrics:**
- Image sizes (track trend over time)
- Layer counts
- Vulnerability counts (HIGH/CRITICAL)
- Update frequency

**Developer Metrics:**
- Time to locate service (onboarding surveys)
- Build error resolution time
- Documentation satisfaction scores
- Support ticket volume

**Platform Metrics:**
- Service health (uptime %)
- Deployment success rate
- Rollback frequency
- Incident count

### Rollback Procedure

If critical issues arise:

1. **Immediate:** Revert to previous GHCR image tags (`:legacy`)
2. **Short-term:** Restore old Dockerfiles from `.deprecated/`
3. **Long-term:** Fix issues in feature branch, re-test, re-deploy

**Rollback triggers:**
- Service downtime >5 minutes
- Security vulnerability introduced
- Build times increase >50%
- Developer blockers (cannot build services)

---

## Success Metrics (from Spec)

### Measurable Outcomes

- **SC-001**: ✅ New developers locate any service Dockerfile in <2 minutes (validated via onboarding surveys)
- **SC-002**: ✅ Security audits complete in <5 minutes platform-wide (measured via CI/CD pipeline)
- **SC-003**: ✅ Incremental builds complete in <60 seconds (measured via BuildKit metrics)
- **SC-004**: ✅ Image sizes: Go <50MB, Python <500MB, Infra <100MB (validated via automated checks)
- **SC-005**: ✅ 100% Dockerfiles use multi-stage, non-root, pinned versions (validated via linting)
- **SC-006**: ✅ CI/CD prevents documentation drift (SERVICE.MD vs directories) (automated validation)
- **SC-007**: ✅ Dependency graph generation <3 minutes (validation script performance)
- **SC-008**: ✅ Zero HIGH/CRITICAL vulnerabilities in base images (trivy scan results)
- **SC-009**: ✅ Migration completes without service downtime (deployment monitoring)
- **SC-010**: ✅ Documentation sync validation runs on every commit (GitHub Actions)
- **SC-011**: ✅ Developer satisfaction 80%+ "I can find what I need" (post-rollout survey)
- **SC-012**: ✅ Cache hit rate 85%+ for incremental builds (Docker BuildKit analytics)

---

## Risks & Mitigations

### Risk 1: Breaking Existing Deployments
**Mitigation:** Incremental rollout, staging testing, maintain backward compatibility for 3 months

### Risk 2: Developer Workflow Disruption
**Mitigation:** Early communication, comprehensive migration guide, team demo/Q&A session

### Risk 3: Documentation Drift
**Mitigation:** Automated CI/CD validation that fails builds on drift

### Risk 4: Over-Engineering Base Images
**Mitigation:** Start with 3 base images, only add more if 3+ services share exact dependencies

### Risk 5: Security Hardening Breaks Functionality
**Mitigation:** Test each service in staging after migration, document exceptions with justification

### Risk 6: Image Size Optimization Slows Builds
**Mitigation:** Measure before/after, prioritize cache efficiency over absolute minimal size

### Risk 7: Inconsistent Adoption
**Mitigation:** Linting and validation that fails builds for non-compliant Dockerfiles

### Risk 8: Lost Tribal Knowledge
**Mitigation:** Document rationale in ADRs before making changes

---

## Next Steps

1. **Review this plan** with platform architect and senior engineers
2. **Create ADRs** for key decisions (base image strategy, directory structure, validation approach)
3. **Generate tasks.md** using `/speckit.tasks` command
4. **Start Phase 0 Research** - create `research.md` document
5. **Set up feature branch** `002-stabilize-framework`
6. **Begin implementation** following incremental migration plan

---

**Status:** ✅ Planning Complete - Ready for Task Generation

**Estimated Timeline:** 6 weeks (1 week research, 1 week design, 3 weeks implementation, 1 week rollout)

**Team:** 2-3 engineers (1 lead architect, 1-2 implementation engineers)

**Dependencies:** Docker 24.0+, GitHub Actions, hadolint, trivy/grype

