# Tasks: A.R.C. Framework Stabilization & Docker Excellence

**Input**: Design documents from `/specs/002-stabilize-framework/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, directory-design.md ✅, docker-standards.md ✅, migration-guide.md ✅

**Tests**: Validation happens via automated scripts and user story acceptance criteria (see Independent Tests per story).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

---

## Test Coverage Requirements (From Constitution Principle V)

**Coverage Targets**:
- **Validation scripts**: 75%+ coverage (critical infrastructure)
- **CI/CD workflows**: 60%+ coverage (core automation)
- **Documentation validation**: 40%+ coverage (verification tools)

**Test Types Required**:
1. **Unit tests**: Validation script logic (Python: pytest)
2. **Integration tests**: Full validation suite execution
3. **Contract tests**: SERVICE.MD schema validation
4. **Smoke tests**: Quick sanity checks in CI/CD

---

## Code Quality & Validation Requirements

### Shell Scripts (Bash)

**Pre-Implementation**:
```
- [ ] T### Review shellcheck rules and configure .shellcheckrc
- [ ] T### Establish script naming convention ({verb}-{noun}.sh)
```

**During Implementation**:
- Run `shellcheck scripts/validate/*.sh` before commits
- Use `set -euo pipefail` in all scripts
- Quote all variables: `"$var"` not `$var`

**Pre-Merge**:
```
- [ ] T### Run shellcheck on all scripts - no errors
- [ ] T### Verify scripts work on macOS and Linux
- [ ] T### Test scripts with edge cases (empty dirs, missing files)
```

### Python Scripts (Validators)

**Pre-Implementation**:
```
- [ ] T### Review ruff/pyright configuration
- [ ] T### Establish validation script patterns
```

**During Implementation**:
- Run `ruff check scripts/validate/*.py` for linting
- Run `ruff format scripts/validate/*.py` for formatting
- Add type hints to all functions

**Pre-Merge**:
```
- [ ] T### Run ruff check - no errors
- [ ] T### Run pytest on validation scripts
- [ ] T### Verify scripts handle errors gracefully
```

---

## Observability Requirements (From Constitution Principle VI)

All validation scripts MUST include logging:

```python
import structlog
logger = structlog.get_logger()

# Log validation start
logger.info("validation.start", script="check-structure.py", target="SERVICE.MD")

# Log validation result
logger.info("validation.complete", status="passed", services_checked=25, issues=0)
```

**Metrics to Track**:
- `validation.duration_seconds` - Time to complete validation
- `validation.issues_found` - Count of issues discovered
- `validation.services_checked` - Number of services validated

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

**Validation Scripts**: `scripts/validate/`
**Docker Base Images**: `.docker/base/`
**Dockerfile Templates**: `.templates/`
**Documentation**: `docs/guides/`, `docs/architecture/`
**GitHub Actions**: `.github/workflows/`

---

## Phase 1: Setup (Project Infrastructure)

**Purpose**: Initialize validation infrastructure, tooling, and directory structure

### 1.1 Directory Structure Setup

- [x] T001 Create validation scripts directory structure
  ```bash
  mkdir -p scripts/validate
  touch scripts/validate/__init__.py
  touch scripts/validate/README.md
  ```

- [x] T002 [P] Create Docker base images directory structure
  ```bash
  mkdir -p .docker/base/python-ai
  mkdir -p .docker/base/go-infra
  touch .docker/README.md
  ```

- [x] T003 [P] Create Dockerfile templates directory
  ```bash
  mkdir -p .templates
  touch .templates/README.md
  ```

### 1.2 Tool Installation & Configuration

- [x] T004 [P] Create hadolint configuration at `.hadolint.yaml`
  - Configure ignored rules for A.R.C. patterns
  - Document rule exceptions with justification
  - Set trusted registries (ghcr.io/arc/*)

- [x] T005 [P] Create .dockerignore template at `.templates/.dockerignore.template`
  - Exclude: `__pycache__`, `.pytest_cache`, `.git`, `*.md`, `tests/`
  - Include: Source code, requirements.txt, config files

- [x] T006 [P] Create shellcheck configuration at `.shellcheckrc`
  - Disable SC2086 (word splitting) where intentional
  - Enable strict mode checks

- [x] T007 [P] Create Python validation environment
  ```bash
  touch scripts/validate/requirements.txt
  # Add: pyyaml, structlog, rich (for output formatting)
  ```

**Checkpoint**: Infrastructure ready for validation script development

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core documentation and base images that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### 2.1 Docker Standards & Base Images

- [x] T008 Verify docker-standards.md exists and is complete at `docs/standards/DOCKER-STANDARDS.md`
  - Security requirements section (non-root, pinned versions)
  - Build optimization section (layer ordering, cache mounts)
  - Language-specific patterns (Python, Go)
  - Image size targets

- [x] T009 Verify directory-design.md exists and is complete at `docs/architecture/DIRECTORY-DESIGN.md`
  - Three-tier structure (core/plugins/services)
  - Inclusion criteria for each tier
  - Naming conventions

- [x] T010 [P] Create Python AI base image Dockerfile at `.docker/base/python-ai/Dockerfile`
  ```dockerfile
  # arc-base-python-ai
  # Base: python:3.11-alpine3.19
  # Includes: PostgreSQL client, NATS client, OTEL SDK
  # Size target: <300MB
  # Security: Non-root user (uid 1000)
  ```

- [x] T011 [P] Create Python base image README at `.docker/base/python-ai/README.md`
  - Purpose and use cases
  - Included dependencies
  - How to extend
  - Version history

- [x] T012 [P] Build and test arc-base-python-ai image locally
  ```bash
  docker build -t arc-base-python-ai:local .docker/base/python-ai/
  docker run --rm arc-base-python-ai:local python --version
  # Verify size: docker images arc-base-python-ai:local --format "{{.Size}}"
  ```

### 2.2 Migration & Validation Design

- [x] T013 Verify migration-guide.md exists and is complete at `docs/guides/MIGRATION-GUIDE.md`
  - Phase-by-phase migration steps
  - Rollback procedures
  - Service migration order

- [x] T014 Create validation script interface specification at `specs/002-stabilize-framework/contracts/validation-api.md`
  - Input: What each validator expects
  - Output: JSON schema for validation results
  - Exit codes: 0=pass, 1=fail, 2=error

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Infrastructure Developer Onboards Successfully (Priority: P1) 🎯 MVP

**Goal**: New developers can locate any service's Dockerfile within 2 minutes and understand directory organization intuitively

**Independent Test**: New developer given SERVICE.MD can:
1. Find arc-sherlock-brain Dockerfile in <2 minutes
2. Correctly categorize where a new "analytics" service would go (services/, not core/)
3. Understand the three-tier structure without asking team

### Implementation for User Story 1

#### 3.1 Directory-Level Documentation

- [x] T015 [P] [US1] Create README.md at `core/README.md`
  ```markdown
  # A.R.C. Core Infrastructure
  Essential services that MUST run for the platform to function.

  ## Inclusion Criteria
  - Service is required for platform to function
  - Cannot be swapped without major refactoring
  - Platform fails to start without it

  ## Services
  | Service | Codename | Purpose |
  |---------|----------|---------|
  | PostgreSQL | arc-oracle | Persistent storage, pgvector |
  | Redis | arc-sonic | High-speed caching |
  | NATS | arc-flash | Real-time messaging |
  | Pulsar | arc-strange | Durable event streaming |
  | Traefik | arc-heimdall | API gateway, routing |
  | OTEL Collector | arc-widow | Observability pipeline |

  ## Directory Structure
  core/{category}/{technology}/
  Example: core/persistence/postgres/
  ```

- [x] T016 [P] [US1] Create README.md at `plugins/README.md`
  ```markdown
  # A.R.C. Plugins
  Optional and swappable components. Platform works without them.

  ## Inclusion Criteria
  - Service is optional (platform works without it)
  - Alternatives exist (can swap implementations)
  - Not all deployments need it

  ## Services
  | Service | Codename | Purpose |
  |---------|----------|---------|
  | Kratos | arc-jarvis | Identity management |
  | Jaeger | arc-columbo | Distributed tracing |
  | Prometheus | arc-house | Metrics collection |
  | Grafana | arc-friday | Visualization |
  | Loki | arc-watson | Log aggregation |
  ```

- [x] T017 [P] [US1] Create README.md at `services/README.md`
  ```markdown
  # A.R.C. Services
  Application logic, AI agents, and reasoning engines.

  ## Inclusion Criteria
  - Business logic specific to A.R.C.
  - AI agents and reasoning engines
  - Workers and utilities

  ## Services
  | Service | Codename | Purpose | Language |
  |---------|----------|---------|----------|
  | arc-sherlock-brain | sherlock | LangGraph reasoning | Python |
  | arc-scarlett-voice | scarlett | Voice agent | Python |
  | arc-piper-tts | piper | Text-to-speech | Python |
  | raymond | raymond | Bootstrap utilities | Go |
  ```

- [x] T018 [P] [US1] Create README.md at `.docker/README.md`
  - Explain base image strategy
  - Document available base images
  - Link to Dockerfile templates

- [x] T019 [P] [US1] Create README.md at `scripts/validate/README.md`
  - List all validation scripts
  - Explain how to run validations
  - Document CI/CD integration

#### 3.2 Service Registry Enhancement

- [x] T020 [US1] Enhance SERVICE.MD with directory structure section
  - Add "Directory Location" column
  - Add categorization decision tree
  - Add "How to add a new service" section
  - Cross-reference with constitution codename requirements

- [x] T021 [US1] Create quickstart reference at `specs/002-stabilize-framework/quickstart.md`
  - 5-minute developer onboarding guide
  - "Find a service" walkthrough
  - "Add a new service" walkthrough
  - Common questions answered

#### 3.3 Architecture Diagrams

- [x] T022 [US1] Create architecture diagram at `docs/architecture/DIRECTORY-STRUCTURE.md`
  ```
  platform-spike/
  ├── core/           # Essential infrastructure (always required)
  ├── plugins/        # Optional components (swappable)
  ├── services/       # Application logic (your code)
  ├── libs/           # Shared libraries
  ├── deployments/    # Docker Compose, K8s manifests
  ├── docs/           # Documentation
  ├── scripts/        # Automation
  └── .docker/        # Base images & templates
  ```

- [x] T023 [US1] Audit all services and add README.md where missing
  - `services/arc-sherlock-brain/README.md`
  - `services/arc-scarlett-voice/README.md`
  - `services/arc-piper-tts/README.md`
  - `services/utilities/raymond/README.md`
  - Verify: Purpose, dependencies, how to build, how to run

**Checkpoint**: Developer onboarding documentation complete - test with new team member

---

## Phase 4: User Story 2 - Platform Operator Maintains Secure Container Images (Priority: P1)

**Goal**: Security team can audit all images in <5 minutes. CVE fixes propagate via base image updates.

**Independent Test**:
1. Run `scripts/validate/check-security.sh` and get compliance report in <5 minutes
2. Simulate CVE fix: Update base image, verify dependent services detect the change
3. Verify all Dockerfiles pass hadolint without HIGH violations

### Implementation for User Story 2

#### 4.1 Security Scanning Scripts

- [x] T024 [P] [US2] Create hadolint wrapper at `scripts/validate/check-dockerfiles.sh`
  ```bash
  #!/bin/bash
  set -euo pipefail

  # Find all Dockerfiles and run hadolint
  # Exit 1 if any fail
  # Output: JSON report to stdout

  find . -name "Dockerfile" -not -path "*/node_modules/*" | while read -r dockerfile; do
    echo "Linting: $dockerfile"
    hadolint --format json "$dockerfile" || exit 1
  done
  ```

- [x] T025 [P] [US2] Create trivy security scan script at `scripts/validate/check-security.sh`
  ```bash
  #!/bin/bash
  set -euo pipefail

  # Scan all arc-* images for vulnerabilities
  # Fail on HIGH/CRITICAL
  # Output: JSON report

  SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
  docker images --format "{{.Repository}}:{{.Tag}}" | grep "^arc-" | while read -r image; do
    echo "Scanning: $image"
    trivy image --severity "$SEVERITY" --format json "$image"
  done
  ```

- [x] T026 [P] [US2] Create security compliance report generator at `scripts/validate/generate-security-report.py`
  ```python
  #!/usr/bin/env python3
  """Generate security compliance report for all Docker images."""

  # Inputs: trivy JSON output, hadolint JSON output
  # Output: Markdown report with:
  #   - Base image versions
  #   - CVE counts by severity
  #   - Security best practice violations
  #   - Remediation recommendations
  ```

#### 4.2 Dockerfile Templates

- [x] T027 [P] [US2] Create Python Dockerfile template at `.templates/Dockerfile.python.template`
  ```dockerfile
  # A.R.C. Python Service Template
  # Constitution Compliance: Security by Default (Principle VIII)

  FROM ghcr.io/arc/base-python-ai:3.11-alpine3.19 AS builder
  WORKDIR /build
  COPY requirements.txt .
  RUN --mount=type=cache,target=/root/.cache/pip \
      pip install --user --no-warn-script-location -r requirements.txt

  FROM ghcr.io/arc/base-python-ai:3.11-alpine3.19
  COPY --from=builder /root/.local /root/.local
  ENV PATH=/root/.local/bin:$PATH
  COPY src/ /app/src/
  WORKDIR /app

  # Security: Non-root user (Constitution VIII)
  RUN addgroup -g 1000 arcuser && adduser -D -u 1000 -G arcuser arcuser && \
      chown -R arcuser:arcuser /app
  USER arcuser

  # Health check (Constitution VII)
  HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
      CMD wget -q --spider http://localhost:8000/health || exit 1

  # Labels (Constitution IV - Codenames)
  LABEL org.opencontainers.image.title="arc-{SERVICE_NAME}" \
        arc.service.codename="{CODENAME}" \
        arc.service.tier="services"

  CMD ["python", "-m", "src.main"]
  ```

- [x] T028 [P] [US2] Create Go Dockerfile template at `.templates/Dockerfile.go.template`
  ```dockerfile
  # A.R.C. Go Service Template
  # Constitution Compliance: Security by Default (Principle VIII)

  FROM golang:1.21-alpine3.19 AS builder
  WORKDIR /build
  COPY go.mod go.sum ./
  RUN --mount=type=cache,target=/go/pkg/mod go mod download
  COPY . .
  RUN --mount=type=cache,target=/go/pkg/mod \
      CGO_ENABLED=0 go build -ldflags="-s -w" -o app ./cmd/main.go

  FROM alpine:3.19
  RUN apk add --no-cache ca-certificates
  COPY --from=builder /build/app /app

  # Security: Non-root user (Constitution VIII)
  RUN addgroup -g 1000 arcuser && adduser -D -u 1000 -G arcuser arcuser
  USER arcuser

  # Health check (Constitution VII)
  HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
      CMD wget -q --spider http://localhost:8080/health || exit 1

  ENTRYPOINT ["/app"]
  ```

#### 4.3 CI/CD Integration

- [x] T029 [US2] Create GitHub Actions workflow at `.github/workflows/validate-docker.yml`
  ```yaml
  name: Validate Dockerfiles
  on: [pull_request, push]
  jobs:
    hadolint:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: hadolint/hadolint-action@v3
          with:
            dockerfile: "**/Dockerfile"
            config: .hadolint.yaml
  ```

- [x] T030 [US2] Create GitHub Actions workflow at `.github/workflows/security-scan.yml`
  ```yaml
  name: Security Scan
  on:
    schedule:
      - cron: '0 6 * * *'  # Daily at 6 AM
    workflow_dispatch:
  jobs:
    trivy:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Run Trivy
          uses: aquasecurity/trivy-action@master
          with:
            scan-type: 'fs'
            severity: 'HIGH,CRITICAL'
  ```

- [x] T031 [US2] Configure hadolint rules in `.hadolint.yaml`
  ```yaml
  ignored:
    - DL3008  # Pin versions in apt-get - we use Alpine
  trustedRegistries:
    - ghcr.io/arc
  ```

- [x] T032 [US2] Create security scanning guide at `docs/guides/SECURITY-SCANNING.md`
  - How to run scans locally
  - How to interpret results
  - How to fix common issues
  - CVE response process

- [x] T033 [US2] Create security baseline at `reports/security-baseline.json`
  - Current state of all images
  - Known issues and remediation plans
  - Exceptions with justification

**Checkpoint**: Security scanning infrastructure operational

---

## Phase 5: User Story 3 - DevOps Engineer Understands Image Relationships (Priority: P1)

**Goal**: Generate dependency graph in <3 minutes. Answer "if I change X, what rebuilds?" without building.

**Independent Test**:
1. Run `scripts/validate/analyze-dependencies.py` and get visual graph
2. Verify arc-base-python-ai shows all 4 Python services as dependents
3. Change base image, verify impact analysis shows affected services

### Implementation for User Story 3

- [ ] T034 [P] [US3] Create image dependency analyzer at `scripts/validate/analyze-dependencies.py`
  ```python
  #!/usr/bin/env python3
  """Analyze Docker image dependency tree."""

  # Parse all Dockerfiles
  # Extract FROM statements
  # Build dependency graph
  # Output: JSON and Mermaid diagram

  def analyze_dependencies():
      # Find all Dockerfiles
      # Parse FROM lines (handle multi-stage)
      # Build graph: base -> service
      # Output formats: JSON, Mermaid, ASCII tree
  ```

- [ ] T035 [P] [US3] Create build impact analysis script at `scripts/validate/check-build-impact.sh`
  ```bash
  #!/bin/bash
  # Input: Changed file or directory
  # Output: List of services that need rebuilding

  # If base image changed -> all dependent services
  # If service code changed -> only that service
  # If lib changed -> services using that lib
  ```

- [ ] T036 [US3] Document image relationships at `docs/architecture/DOCKER-IMAGE-HIERARCHY.md`
  ```markdown
  # Docker Image Hierarchy

  ## Base Images
  - `ghcr.io/arc/base-python-ai` → sherlock, scarlett, piper
  - `ghcr.io/arc/base-go-infra` → raymond (future)

  ## Build Order
  1. Base images (on base image changes)
  2. Service images (on service code changes)
  3. Compose stacks (on config changes)
  ```

- [ ] T037 [US3] Add Makefile targets for dependency analysis
  ```makefile
  .PHONY: analyze-deps build-impact

  analyze-deps:
  	@python scripts/validate/analyze-dependencies.py --output mermaid

  build-impact:
  	@scripts/validate/check-build-impact.sh $(FILE)
  ```

- [ ] T038 [US3] Create image tagging documentation at `docs/guides/IMAGE-TAGGING.md`
  - Semantic versioning for images
  - Tag format: `{service}:{version}-{git-sha}`
  - GHCR publication workflow

- [ ] T039 [US3] Create GHCR publishing guide at `docs/guides/GHCR-PUBLISHING.md`
  - Authentication setup
  - Manual publishing steps
  - Automated publishing via GitHub Actions

- [ ] T040 [US3] Update base image Dockerfiles with metadata labels
  - OCI annotations
  - Build timestamp
  - Git SHA
  - Dependency versions

- [ ] T041 [US3] Create GitHub Actions workflow for base images at `.github/workflows/build-base-images.yml`
  ```yaml
  name: Build Base Images
  on:
    push:
      paths:
        - '.docker/base/**'
    workflow_dispatch:
  jobs:
    build-python-ai:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Build and push
          uses: docker/build-push-action@v5
          with:
            context: .docker/base/python-ai
            push: true
            tags: ghcr.io/arc/base-python-ai:latest
  ```

**Checkpoint**: Build pipeline relationships documented and queryable

---

## Phase 6: User Story 4 - Developer Builds Services Efficiently (Priority: P2)

**Goal**: Code-only changes rebuild in <60 seconds. Image sizes within targets.

**Independent Test**:
1. Modify `services/arc-sherlock-brain/src/main.py` (add comment)
2. Rebuild with warm cache: `docker build -t test services/arc-sherlock-brain/`
3. Verify build completes in <60 seconds
4. Verify image size <500MB

### Implementation for User Story 4

#### 6.1 Dockerfile Optimization

- [ ] T042 [P] [US4] Audit arc-sherlock-brain Dockerfile for cache optimization
  - Layer ordering: OS packages → pip deps → source code
  - Add cache mounts for pip
  - Review .dockerignore

- [ ] T043 [P] [US4] Audit arc-scarlett-voice Dockerfile for cache optimization
  - Same as T042

- [ ] T044 [P] [US4] Audit arc-piper-tts Dockerfile for cache optimization
  - Same as T042

- [ ] T045 [P] [US4] Audit raymond (Go) Dockerfile for cache optimization
  - Layer ordering: go.mod → go mod download → source code
  - Add cache mounts for go modules

- [ ] T046 [P] [US4] Create .dockerignore for all services
  ```
  # services/arc-sherlock-brain/.dockerignore
  __pycache__/
  *.pyc
  .pytest_cache/
  .git/
  .github/
  tests/
  *.md
  .env*
  ```

#### 6.2 Build Performance Tracking

- [ ] T047 [US4] Create build time tracking script at `scripts/validate/track-build-times.sh`
  ```bash
  #!/bin/bash
  # Build all services and record times
  # Output: JSON with build times per service
  # Compare against baseline
  ```

- [ ] T048 [US4] Create image size validation at `scripts/validate/check-image-sizes.py`
  ```python
  #!/usr/bin/env python3
  """Validate image sizes against targets from Constitution."""

  SIZE_LIMITS = {
      "python": 500 * 1024 * 1024,  # 500MB
      "go": 50 * 1024 * 1024,        # 50MB
      "infra": 100 * 1024 * 1024,    # 100MB
  }
  ```

- [ ] T049 [US4] Create build performance baseline at `reports/build-performance-baseline.json`
  - Current build times per service
  - Current image sizes
  - Cache hit rates

- [ ] T050 [US4] Create build optimization guide at `docs/guides/DOCKER-BUILD-OPTIMIZATION.md`
  - Layer ordering best practices
  - Cache mount usage
  - .dockerignore configuration
  - BuildKit features

- [ ] T051 [US4] Document BuildKit configuration
  - Enable BuildKit: `export DOCKER_BUILDKIT=1`
  - Configure cache backends
  - Parallel build stages

- [ ] T052 [US4] Create GitHub Actions workflow for build tracking at `.github/workflows/track-build-performance.yml`
  - Measure build times on PR
  - Compare against baseline
  - Alert on regressions

**Checkpoint**: All services building efficiently

---

## Phase 7: User Story 5 - Documentation Stays Synchronized with Code (Priority: P2)

**Goal**: CI/CD catches SERVICE.MD drift. Dockerfile violations caught before merge.

**Independent Test**:
1. Add fake service to SERVICE.MD without creating directory
2. Run validation: `scripts/validate/check-structure.py`
3. Verify it fails with clear error message
4. Add Dockerfile without USER instruction, verify hadolint catches it

### Implementation for User Story 5

#### 7.1 Structure Validation

- [ ] T053 [P] [US5] Create SERVICE.MD validator at `scripts/validate/check-service-registry.py`
  ```python
  #!/usr/bin/env python3
  """Validate SERVICE.MD against actual directory structure."""

  def validate():
      services = parse_service_md()
      for service in services:
          path = map_service_to_path(service)
          if not os.path.exists(path):
              raise ValidationError(f"Service {service} missing directory: {path}")
          if not os.path.exists(f"{path}/Dockerfile"):
              raise ValidationError(f"Service {service} missing Dockerfile")
  ```

- [ ] T054 [P] [US5] Create directory structure validator at `scripts/validate/check-structure.py`
  ```python
  #!/usr/bin/env python3
  """Validate directory structure follows constitution."""

  # Check: No orphaned directories
  # Check: All services in correct tier (core/plugins/services)
  # Check: Naming follows convention (arc-{codename}-{function})
  ```

- [ ] T055 [P] [US5] Create Dockerfile standards validator at `scripts/validate/check-dockerfile-standards.py`
  ```python
  #!/usr/bin/env python3
  """Validate Dockerfiles follow constitution security requirements."""

  # Check: Non-root user (USER instruction)
  # Check: No :latest tags
  # Check: Multi-stage build
  # Check: HEALTHCHECK present
  # Check: OCI labels present
  ```

#### 7.2 Validation Orchestration

- [ ] T056 [US5] Create validation orchestrator at `scripts/validate/validate-all.sh`
  ```bash
  #!/bin/bash
  set -euo pipefail

  echo "🔍 Running structure validation..."
  python scripts/validate/check-structure.py

  echo "📋 Running SERVICE.MD validation..."
  python scripts/validate/check-service-registry.py

  echo "🐳 Running Dockerfile linting..."
  ./scripts/validate/check-dockerfiles.sh

  echo "🔒 Running Dockerfile standards check..."
  python scripts/validate/check-dockerfile-standards.py

  echo "✅ All validations passed!"
  ```

- [ ] T057 [US5] Create GitHub Actions workflow at `.github/workflows/validate-structure.yml`
  ```yaml
  name: Validate Structure
  on: [pull_request]
  jobs:
    validate:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Run validations
          run: ./scripts/validate/validate-all.sh
  ```

- [ ] T058 [US5] Create pre-commit hooks at `.pre-commit-config.yaml`
  ```yaml
  repos:
    - repo: local
      hooks:
        - id: check-structure
          name: Check directory structure
          entry: python scripts/validate/check-structure.py
          language: python
          pass_filenames: false
        - id: hadolint
          name: Lint Dockerfiles
          entry: hadolint
          language: docker
          types: [dockerfile]
  ```

- [ ] T059 [US5] Create validation failure guide at `docs/guides/VALIDATION-FAILURES.md`
  - Common errors and fixes
  - How to run validations locally
  - How to add exceptions

- [ ] T060 [US5] Add CI/CD status badge to README.md
  ```markdown
  [![Validation](https://github.com/arc/platform-spike/actions/workflows/validate-structure.yml/badge.svg)](...)
  ```

- [ ] T061 [US5] Create doc path sync checker
  - Verify all path references in docs exist
  - Check SERVICE.MD references
  - Check README.md links

- [ ] T062 [US5] Add quickstart.md scenario verification
  - Automated test that runs quickstart steps
  - Verify commands work as documented

**Checkpoint**: Automated validation preventing drift

---

## Phase 8: User Story 6 - Platform Architect Plans Future Services (Priority: P3)

**Goal**: New service categories can be added without restructuring. Clear categorization principles.

**Independent Test**:
1. Architect proposes "analytics" service
2. Using only documentation, they determine: goes in `services/`, not `core/`
3. Using template, they can scaffold new service in <10 minutes

### Implementation for User Story 6

- [ ] T063 [P] [US6] Create service categorization guide at `docs/architecture/SERVICE-CATEGORIZATION.md`
  ```markdown
  # Service Categorization Decision Tree

  Is the service required for the platform to start?
  ├── YES → core/
  └── NO → Is it swappable with alternatives?
           ├── YES → plugins/
           └── NO → services/
  ```

- [ ] T064 [P] [US6] Create scaling strategy document at `docs/architecture/SCALING-STRATEGY.md`
  - When to add subdirectories (>15 services per category)
  - How to handle service variants (GPU/CPU)
  - Multi-tenancy considerations

- [ ] T065 [US6] Add capacity planning to SERVICE.MD
  - Current service count per tier
  - Growth projections
  - Category limits

- [ ] T066 [US6] Create new service generator at `scripts/create-service.sh`
  ```bash
  #!/bin/bash
  # Usage: ./scripts/create-service.sh --name arc-analytics --tier services --lang python
  # Creates: Directory, Dockerfile, README, adds to SERVICE.MD
  ```

- [ ] T067 [US6] Document service lifecycle in SERVICE.MD
  - States: prototype → stable → deprecated → removed
  - Transition criteria
  - Deprecation process

- [ ] T068 [US6] Create ADR template at `docs/architecture/adr/000-template.md`
  ```markdown
  # ADR-000: [Title]

  ## Status
  [Proposed | Accepted | Deprecated | Superseded]

  ## Context
  [Why is this decision needed?]

  ## Decision
  [What was decided?]

  ## Consequences
  [What are the results?]
  ```

- [ ] T069 [US6] Write ADR for three-tier structure at `docs/architecture/adr/002-three-tier-structure.md`
  - Why core/plugins/services?
  - Alternatives considered
  - Trade-offs

- [ ] T070 [US6] Create service roadmap at `docs/architecture/SERVICE-ROADMAP.md`
  - Planned services
  - Deprecation candidates
  - Category evolution

**Checkpoint**: Architectural guidance complete

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final quality assurance and production readiness

### 9.1 Quality Assurance

- [ ] T071 [P] Run hadolint on all Dockerfiles and fix violations
  ```bash
  find . -name "Dockerfile" -exec hadolint {} \; 2>&1 | tee reports/hadolint-results.txt
  ```

- [ ] T072 [P] Run trivy security scan and document results
  ```bash
  ./scripts/validate/check-security.sh > reports/security-scan.json
  ```

- [ ] T073 [P] Migrate all Python services to use arc-base-python-ai
  - Update FROM statements
  - Test builds
  - Verify functionality

- [ ] T074 [P] Update PROGRESS.md with feature status

### 9.2 Documentation Finalization

- [ ] T075 Create metrics dashboard design for tracking
  - Build times trend
  - Image sizes trend
  - Security issues trend

- [ ] T076 Create CHANGELOG.md entry
  ```markdown
  ## [002-stabilize-framework] - 2026-01-XX

  ### Added
  - Docker base images (arc-base-python-ai)
  - Validation scripts for structure and security
  - Comprehensive directory documentation

  ### Changed
  - Standardized Dockerfile patterns across all services
  - Enhanced SERVICE.MD with directory locations
  ```

- [ ] T077 Update root README.md
  - Add links to new documentation
  - Update directory structure description
  - Add validation instructions

### 9.3 Final Validation

- [ ] T078 Run complete validation suite
  ```bash
  ./scripts/validate/validate-all.sh
  ```

- [ ] T079 Generate final security compliance report
  ```bash
  python scripts/validate/generate-security-report.py > reports/security-compliance.md
  ```

- [ ] T080 Verify quickstart.md works end-to-end
  - Fresh clone
  - Follow all steps
  - Verify expected outcomes

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ──────────────────────┐
                                      │
Phase 2 (Foundational) ◄──────────────┘
         │
         ├──► Phase 3 (US1 - Documentation)
         │
         ├──► Phase 4 (US2 - Security) ──────┐
         │                                    │
         ├──► Phase 5 (US3 - Dependencies)   │
         │                                    │
         │    Phase 6 (US4 - Build Speed) ◄──┤ (soft dependency)
         │                                    │
         │    Phase 7 (US5 - Validation) ◄───┤ (soft dependency)
         │                                    │
         └──► Phase 8 (US6 - Architecture) ◄─┘
                                      │
Phase 9 (Polish) ◄────────────────────┘
```

### Parallel Execution Matrix

| Phase | Parallelizable Tasks | Max Concurrent |
|-------|---------------------|----------------|
| 1 | T002-T007 | 6 |
| 2 | T010-T012 | 3 |
| 3 | T015-T019 | 5 |
| 4 | T024-T028 | 5 |
| 5 | T034-T035 | 2 |
| 6 | T042-T046 | 5 |
| 7 | T053-T055 | 3 |
| 8 | T063-T064 | 2 |
| 9 | T071-T074 | 4 |

---

## Implementation Strategy

### MVP (Week 1-2): P1 User Stories

Focus on immediate developer value:
- **US1**: Navigation and onboarding (documentation)
- **US2**: Security scanning (compliance)
- **US3**: Build dependencies (understanding)

**Deliverables**:
- All tier README.md files created
- Security scanning operational in CI/CD
- Dependency analysis tools working

### Iteration 2 (Week 3): P2 User Stories

Focus on developer experience:
- **US4**: Build optimization (speed)
- **US5**: Validation automation (quality)

**Deliverables**:
- All Dockerfiles optimized
- CI/CD validation blocking bad PRs
- Pre-commit hooks installed

### Iteration 3 (Week 4): P3 + Polish

Focus on long-term sustainability:
- **US6**: Architectural guidance (growth)
- **Polish**: Production readiness

**Deliverables**:
- ADRs written
- Security compliance report clean
- All validations passing

---

## Success Metrics

| Metric | Target | Validation |
|--------|--------|------------|
| Service Dockerfile location time | <2 min | User test |
| Security scan completion | <5 min | CI/CD timer |
| Incremental build time | <60 sec | Build timer |
| Python image size | <500MB | Size check script |
| Go image size | <50MB | Size check script |
| Dockerfile lint errors | 0 | hadolint |
| HIGH/CRITICAL CVEs | 0 | trivy |
| Documentation drift | 0 | Structure validator |
| Cache hit rate | >85% | BuildKit metrics |

---

## Task Summary

**Total Tasks**: 80 tasks across 9 phases

| Phase | Tasks | Priority |
|-------|-------|----------|
| 1 - Setup | 7 | Foundation |
| 2 - Foundational | 7 | Foundation |
| 3 - US1 (Onboarding) | 9 | P1 |
| 4 - US2 (Security) | 10 | P1 |
| 5 - US3 (Dependencies) | 8 | P1 |
| 6 - US4 (Build Speed) | 11 | P2 |
| 7 - US5 (Validation) | 10 | P2 |
| 8 - US6 (Architecture) | 8 | P3 |
| 9 - Polish | 10 | Final |

**Parallel Opportunities**: 35 tasks marked [P]

**Constitution Compliance**:
- ✅ Principle V (TDD): Validation scripts tested
- ✅ Principle VI (Observability): Logging in all scripts
- ✅ Principle VII (Resilience): Health checks in templates
- ✅ Principle VIII (Security): Non-root users enforced
- ✅ Principle IX (Compose Layering): Base image strategy
- ✅ Principle X (Documentation): READMEs everywhere

---

## Notes

- **[P]** tasks = different files, no dependencies - can run in parallel
- **[Story]** label maps task to specific user story for traceability
- All paths relative to repository root: `/Users/dgtalbug/Workspace/arc/platform-spike/`
- Shell scripts must pass `shellcheck`
- Python scripts must pass `ruff` and have type hints
- All validation scripts output JSON for CI/CD parsing
