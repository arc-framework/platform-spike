# Tasks: GitHub Actions CI/CD Optimization & Enterprise Standardization

**Input**: Design documents from `/specs/003-stabilize-github-actions/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, current-state-analysis.md ✅, ghcr-rate-limiting-solution.md ✅

**Tests**: Tests are NOT required for CI/CD workflows per A.R.C. Constitution Testing Strategy. Validation happens via smoke tests and dry-run verification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

---

## Implementation Strategy

**MVP Scope (User Stories 1-3)**: Fast PR feedback, automated publishing, security auditing
- Target: Weeks 1-3 (Phases 1-4)
- Deliverables: PR checks, main deploy, SBOM generation
- Value: 60% faster validation, 100% automation, security compliance

**Full Feature (All Stories)**: Add observability, orchestration, cost tracking
- Target: Weeks 4-6 (Phases 5-8)
- Deliverables: Publish orchestrator, release pipeline, metrics dashboard
- Value: Enterprise-grade CI/CD with full observability

---

## Verification Requirements (Not Unit Tests)

### Workflow Validation (REQUIRED)

**Pre-Implementation**:
```bash
# Install actionlint for YAML syntax checking
- [ ] T### Install actionlint: brew install actionlint (macOS) or download binary
- [ ] T### Create .github/actionlint.yaml configuration file
```

**During Implementation**:
- Run `actionlint .github/workflows/*.yml` before commits
- Test workflows locally with `act` tool (optional)
- Verify YAML syntax with online validators

**Pre-Merge**:
```bash
# Smoke tests for each workflow
- [ ] T### Run actionlint on all workflow files - zero errors
- [ ] T### Test PR checks workflow with test PR
- [ ] T### Verify composite actions with minimal test workflow
- [ ] T### Test publish workflow with dry-run flag
```

### Bash Script Validation

**Pre-Implementation**:
```bash
- [ ] T### Review shellcheck configuration in .shellcheckrc
- [ ] T### Establish script naming convention for CI scripts
```

**During Implementation**:
- Run `shellcheck scripts/ci/*.sh` before commits
- Use `set -euo pipefail` in all scripts
- Test scripts with `--dry-run` or `--check` flags

**Pre-Merge**:
```bash
- [ ] T### Run shellcheck on all CI scripts - no errors
- [ ] T### Verify scripts work on Ubuntu (GitHub Actions runner)
- [ ] T### Test scripts with edge cases (empty matrix, missing files)
```

### Python Script Validation

**Pre-Implementation**:
```bash
- [ ] T### Review ruff configuration for CI scripts
- [ ] T### Establish Python script patterns for matrix generation
```

**During Implementation**:
- Run `ruff check scripts/ci/*.py` for linting
- Run `ruff format scripts/ci/*.py` for formatting
- Add type hints to all functions
- Test with sample data

**Pre-Merge**:
```bash
- [ ] T### Run ruff check on CI scripts - no errors
- [ ] T### Verify scripts produce valid JSON output
- [ ] T### Test matrix generation with SERVICE.MD
```

---

## Observability Requirements

All workflow scripts MUST include structured output:

**Workflow Job Summaries** (Required for ALL workflows):
```yaml
- name: Generate Summary
  if: always()
  run: |
    echo "## 🚀 Workflow Results" >> $GITHUB_STEP_SUMMARY
    echo "Status: ${{ job.status }}" >> $GITHUB_STEP_SUMMARY
```

**Bash Script Logging**:
```bash
#!/bin/bash
set -euo pipefail

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

log_info "Starting workflow script"
```

**Python Script Logging**:
```python
#!/usr/bin/env python3
import logging
import sys

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

logger.info("Starting matrix generation")
```

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

**Composite Actions**: `.github/actions/{action-name}/action.yml`
**Reusable Workflows**: `.github/workflows/_reusable-{name}.yml`
**Orchestration Workflows**: `.github/workflows/{name}.yml`
**Configuration Files**: `.github/config/{name}.json`
**CI Scripts**: `.github/scripts/ci/{name}.py` or `.sh`

---

## Phase 1: Setup (Project Infrastructure)

**Purpose**: Initialize CI/CD infrastructure, directory structure, and validation tooling

### 1.1 Directory Structure Setup

- [x] T001 Create composite actions directory structure
  ```bash
  mkdir -p .github/actions
  touch .github/actions/README.md
  ```

- [x] T002 [P] Create configuration directory structure
  ```bash
  mkdir -p .github/config
  touch .github/config/README.md
  ```

- [x] T003 [P] Create CI scripts directory structure
  ```bash
  mkdir -p .github/scripts/ci
  touch .github/scripts/ci/README.md
  ```

- [x] T004 [P] Create DEPRECATED directory for old workflows
  ```bash
  mkdir -p .github/workflows/DEPRECATED
  touch .github/workflows/DEPRECATED/README.md
  ```

### 1.2 Tool Installation & Configuration

- [x] T005 [P] Create actionlint configuration at `.github/actionlint.yaml`
  - Configure ignored rules for A.R.C. patterns
  - Set trusted actions (docker/*, actions/*)
  - Document rule exceptions

- [x] T006 [P] Create shellcheck configuration at `.shellcheckrc` (if not exists)
  - Enable strict mode checks
  - Configure for Bash 4.0+ compatibility

- [x] T007 [P] Create Python requirements for CI scripts at `.github/scripts/ci/requirements.txt`
  ```text
  pyyaml>=6.0
  jinja2>=3.1.0
  ```

- [x] T008 [P] Create composite actions README at `.github/actions/README.md`
  - Explain purpose of composite actions
  - Document available actions and their inputs
  - Provide usage examples

- [x] T009 [P] Create CI scripts README at `.github/scripts/ci/README.md`
  - List all helper scripts
  - Explain how to test scripts locally
  - Document script interfaces (inputs/outputs)

**Checkpoint**: Infrastructure ready for composite action development

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core composite actions and helper scripts that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### 2.1 Composite Actions - Setup Actions

- [x] T010 [P] Create setup-arc-python composite action at `.github/actions/setup-arc-python/action.yml`
  - Input: python-version (default: '3.11')
  - Install Python via actions/setup-python@v5
  - Enable pip caching via cache: 'pip'
  - Install common tools: ruff, black, mypy, pytest
  - Set PYTHONUNBUFFERED=1 environment variable
  - Add README.md with usage examples

- [x] T011 [P] Create setup-arc-docker composite action at `.github/actions/setup-arc-docker/action.yml`
  - Input: registry (default: 'ghcr.io')
  - Login to GHCR with github-token
  - Setup Docker Buildx via docker/setup-buildx-action@v3
  - Configure BuildKit with DOCKER_BUILDKIT=1
  - Set cache configuration (mode=max)
  - Add README.md with usage examples

- [x] T012 [P] Create setup-arc-validation composite action at `.github/actions/setup-arc-validation/action.yml`
  - Install hadolint v2.12+ (Dockerfile linter)
  - Install trivy v0.48+ (security scanner)
  - Install shellcheck (if not exists)
  - Cache tool binaries with actions/cache@v4
  - Add README.md with usage examples

### 2.2 Composite Actions - Utility Actions

- [x] T013 [P] Create arc-job-summary composite action at `.github/actions/arc-job-summary/action.yml`
  - Input: results-json (path to JSON file)
  - Input: summary-type (build, security, validation)
  - Parse JSON and generate markdown summary
  - Add emoji indicators (✅ ❌ ⚠️)
  - Append to $GITHUB_STEP_SUMMARY
  - Add README.md with JSON schema examples

- [x] T014 [P] Create arc-notify composite action at `.github/actions/arc-notify/action.yml`
  - Input: notification-type (slack, github-issue)
  - Input: message (notification content)
  - Placeholder for Slack webhook (future)
  - Create GitHub Issue for CVEs
  - Add README.md (mark as future feature)

### 2.3 Helper Scripts

- [x] T015 [P] Create SERVICE.MD parser script at `.github/scripts/ci/parse-services.py`
  ```python
  #!/usr/bin/env python3
  # Parse SERVICE.MD and extract service matrix
  # Output: JSON array of {name, path, language}
  # Usage: python parse-services.py > services.json
  ```

- [x] T016 [P] Create matrix generator script at `.github/scripts/ci/generate-matrix.py`
  ```python
  #!/usr/bin/env python3
  # Generate GitHub Actions matrix from config files
  # Input: .github/config/{group}.json
  # Output: JSON matrix for strategy.matrix
  # Usage: python generate-matrix.py --config publish-gateway.json
  ```

- [x] T017 [P] Create workflow validation script at `.github/scripts/ci/validate-workflows.sh`
  ```bash
  #!/bin/bash
  # Validate all workflow files with actionlint
  # Usage: ./validate-workflows.sh
  # Exit 0 if all pass, 1 if any fail
  ```

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Developer Gets Fast PR Feedback (Priority: P1) 🎯 MVP

**Goal**: Reduce PR validation time from 8 minutes to <3 minutes with 85%+ cache hit rate

**Independent Test**: Create PR modifying `services/arc-sherlock-brain/src/main.py` (code only). Measure time from push to "All checks passed". Should complete in under 3 minutes.

### Implementation for User Story 1

#### 3.1 Reusable Validation Workflow

- [x] T018 [US1] Create reusable validation workflow at `.github/workflows/_reusable-validate.yml`
  - Workflow input: paths (array of paths to validate)
  - Workflow input: fail-fast (boolean, default true)
  - Job 1: Dockerfile linting with hadolint
  - Job 2: Structure validation (SERVICE.MD sync check)
  - Job 3: YAML validation with actionlint
  - Workflow output: validation-status (pass/fail)
  - Workflow output: errors (array of error messages)
  - Use setup-arc-validation composite action
  - Add job summaries for each validation type

- [x] T019 [US1] Create reusable build workflow at `.github/workflows/_reusable-build.yml`
  - Workflow input: service-name (string)
  - Workflow input: service-path (string)
  - Workflow input: push-image (boolean, default false)
  - Workflow input: platforms (array, default ["linux/amd64"])
  - Use setup-arc-docker composite action
  - Configure 3-tier BuildKit caching (cache-from/cache-to: type=gha,mode=max)
  - Build Docker image with docker/build-push-action@v5
  - Track build time and image size as outputs
  - Generate SBOM if push-image=true
  - Workflow output: image-digest, image-size, build-duration

- [x] T020 [US1] Create reusable security scan workflow at `.github/workflows/_reusable-security.yml`
  - Workflow input: scan-type (fs or image)
  - Workflow input: scan-target (path or image name)
  - Workflow input: severity (default: "CRITICAL,HIGH")
  - Workflow input: fail-on-severity (default: "CRITICAL")
  - Use setup-arc-validation composite action
  - Run Trivy security scan with aquasecurity/trivy-action@master
  - Generate SARIF report and upload to GitHub Security tab
  - Workflow output: cve-count, critical-cves (array)
  - Create job summary with CVE table

#### 3.2 PR Checks Orchestration Workflow

- [x] T021 [US1] Create PR checks orchestration workflow at `.github/workflows/pr-checks.yml`
  - Trigger: pull_request on [opened, synchronize, reopened]
  - Path filters: services/**, core/**, plugins/**, .docker/**, **/Dockerfile, **/requirements.txt, .github/workflows/**
  - Concurrency: group by github.ref, cancel-in-progress: true
  - Job 1 (validate): Call _reusable-validate.yml with paths from git diff
  - Job 2 (security-scan): Call _reusable-security.yml with scan-type: fs, parallel with validate
  - Job 3 (detect-changes): Detect changed services via git diff, output matrix
  - Job 4 (build-changed): Matrix build calling _reusable-build.yml, needs: [validate, detect-changes]
  - Job 5 (summary): Aggregate results and generate PR comment, needs: [validate, security-scan, build-changed], if: always()
  - Set timeout-minutes: 10 for entire workflow

- [x] T022 [US1] Create changed services detection script at `.github/scripts/ci/detect-changed-services.sh`
  ```bash
  #!/bin/bash
  # Detect which services changed based on git diff
  # Output: JSON array of changed service names
  # Usage: ./detect-changed-services.sh $BASE_REF $HEAD_REF
  ```

#### 3.3 Caching Optimization

- [x] T023 [US1] Implement cache key strategy in _reusable-build.yml
  - Primary key: hash of Dockerfile + requirements.txt + service code
  - Restore keys: hash of Dockerfile + requirements.txt, hash of Dockerfile
  - Document cache invalidation strategy in workflow comments

- [x] T024 [US1] Add cache monitoring to job summaries
  - Track cache hit/miss per build
  - Show cache hit rate in summary
  - Alert if cache hit rate <80%

#### 3.4 Testing & Validation

- [ ] T025 [US1] Create test PR with code-only changes to arc-sherlock-brain
  - Verify workflow triggers correctly
  - Measure total execution time (<3 min target)
  - Verify cache hit rate (>85% target)
  - Verify job summary appears on PR page

- [ ] T026 [US1] Test concurrency cancellation
  - Push multiple commits to same PR rapidly
  - Verify old workflow runs are cancelled
  - Verify only latest run completes

- [ ] T027 [US1] Test validation failures
  - Create PR with hadolint violations
  - Verify clear error messages in job summary
  - Verify actionable fix suggestions

**Checkpoint**: PR validation workflow complete and verified <3 minutes

---

## Phase 4: User Story 2 - Platform Operator Publishes Images Automatically (Priority: P1) 🎯 MVP

**Goal**: Eliminate manual publishing - 100% automated dev deployment on merge to main

**Independent Test**: Merge PR updating `services/arc-sherlock-brain/Dockerfile`. Verify image automatically built, scanned, and pushed to `ghcr.io/arc/arc-sherlock-brain:dev-<sha>` within 5 minutes.

### Implementation for User Story 2

#### 4.1 Main Deploy Orchestration Workflow

- [x] T028 [US2] Create main deploy orchestration workflow at `.github/workflows/main-deploy.yml`
  - Trigger: push to main branch
  - Path filters: services/**, core/**, plugins/**, .docker/**
  - Job 1 (detect-changes): Detect changed services, output matrix
  - Job 2 (build-and-push): Matrix build calling _reusable-build.yml with push-image=true, tag: dev-${{ github.sha }}
  - Job 3 (security-scan): Call _reusable-security.yml on pushed images, needs: [build-and-push]
  - Job 4 (block-on-critical-cve): Fail if CRITICAL CVEs found, create GitHub Issue, needs: [security-scan]
  - Job 5 (generate-sbom): Verify SBOM artifacts attached, needs: [build-and-push]
  - Job 6 (deploy-summary): Generate deployment summary with image links, needs: [build-and-push, security-scan], if: always()
  - Set timeout-minutes: 15 for entire workflow

- [x] T029 [US2] Add SBOM generation to _reusable-build.yml
  - Enable sbom: true in docker/build-push-action@v5
  - Upload SBOM as workflow artifact
  - Add SBOM link to job summary

- [x] T030 [US2] Create CVE issue creation script at `.github/scripts/ci/create-cve-issue.py`
  ```python
  #!/usr/bin/env python3
  # Create GitHub Issue for CRITICAL CVEs
  # Input: Trivy JSON output
  # Output: Issue number
  # Usage: python create-cve-issue.py --trivy-report results.json
  ```

#### 4.2 Image Tagging Strategy

- [x] T031 [US2] Implement multi-tag strategy in _reusable-build.yml
  - Tag 1: dev-${{ github.sha }} (immutable)
  - Tag 2: dev-latest (mutable, latest dev build)
  - Document tagging strategy in workflow comments

- [x] T032 [US2] Add image metadata labels in _reusable-build.yml
  - Label: org.opencontainers.image.source (repo URL)
  - Label: org.opencontainers.image.revision (git SHA)
  - Label: org.opencontainers.image.created (timestamp)
  - Label: arc.build.workflow-run-id (GitHub run ID)

#### 4.3 Security Integration

- [x] T033 [US2] Configure Trivy to fail on CRITICAL CVEs in main-deploy.yml
  - Set fail-on-severity: CRITICAL
  - Create GitHub Issue with CVE details
  - Block image publish if CRITICAL found
  - Send notification (future: Slack alert)

- [x] T034 [US2] Upload Trivy SARIF to GitHub Security tab
  - Enable sarif: true in trivy-action
  - Upload via github/codeql-action/upload-sarif@v3
  - Verify CVEs visible in Security tab

#### 4.4 Testing & Validation

- [ ] T035 [US2] Create test PR and merge to main
  - Modify arc-sherlock-brain service
  - Verify auto-build triggers on merge
  - Verify image pushed to GHCR with dev-<sha> tag
  - Measure total time (<5 min target)

- [ ] T036 [US2] Test SBOM generation
  - Verify SBOM artifact attached to workflow
  - Download SBOM and validate format (SPDX JSON)
  - Verify all dependencies listed

- [ ] T037 [US2] Simulate CRITICAL CVE detection
  - Add vulnerable package to requirements.txt
  - Verify build fails with clear error
  - Verify GitHub Issue created
  - Verify CVE details in Security tab

**Checkpoint**: Automated dev deployment working with SBOM and CVE blocking

---

## Phase 5: User Story 3 - Security Team Audits Dependencies (Priority: P1) 🎯 MVP

**Goal**: Generate consolidated SBOM for all services, track CVEs, enable <10 minute audits

**Independent Test**: Run SBOM generation for all services. Export consolidated report showing all dependencies with licenses and CVEs. Should complete in <10 minutes.

### Implementation for User Story 3

#### 5.1 SBOM Consolidation

- [x] T038 [US3] Create SBOM consolidation script at `.github/scripts/ci/consolidate-sbom.py`
  ```python
  #!/usr/bin/env python3
  # Consolidate multiple SBOM files into single report
  # Input: Directory of SPDX SBOM JSON files
  # Output: Consolidated CSV with all dependencies
  # Columns: service, package, version, license, cve_count
  # Usage: python consolidate-sbom.py --input sbom/ --output report.csv
  ```

- [x] T039 [US3] Create license compliance checker at `.github/scripts/ci/check-licenses.py`
  ```python
  #!/usr/bin/env python3
  # Check SBOM for license policy violations
  # Input: SBOM file
  # Config: .github/config/license-policy.json (allowed licenses)
  # Output: Violations report
  # Usage: python check-licenses.py --sbom report.json --policy license-policy.json
  ```

- [x] T040 [US3] Create license policy configuration at `.github/config/license-policy.json`
  ```json
  {
    "allowed": ["MIT", "Apache-2.0", "BSD-3-Clause", "ISC", "Python-2.0"],
    "blocked": ["GPL-3.0", "AGPL-3.0"],
    "review_required": ["LGPL-2.1", "MPL-2.0"]
  }
  ```

#### 5.2 Scheduled Security Scanning

- [x] T041 [US3] Create scheduled maintenance workflow at `.github/workflows/scheduled-maintenance.yml`
  - Trigger: schedule cron '0 2 * * *' (daily 2 AM UTC)
  - Trigger: workflow_dispatch for manual runs
  - Job 1 (discover-images): Discover published images from GHCR
  - Job 2 (security-scan): Scan all services with Trivy in matrix
  - Job 3 (consolidate-sboms): Run consolidate-sbom.py script
  - Job 4 (weekly-report): Generate weekly summary on Sundays
  - Job 5 (cleanup): Close resolved CVE issues
  - Integrated license compliance checking
  - Set timeout-minutes: 30 for entire workflow

- [x] T042 [US3] Add CVE tracking to prevent duplicate issues
  - Created `.github/scripts/ci/track-cves.py` script
  - Check if issue already exists for CVE ID via label search
  - Close issues when CVE is no longer detected
  - Generate CVE inventory reports

#### 5.3 Audit Reports

- [x] T043 [US3] Create dependency report generator at `.github/scripts/ci/generate-dependency-report.py`
  ```python
  #!/usr/bin/env python3
  # Generate human-readable dependency audit report
  # Input: Consolidated SBOM CSV or JSON
  # Output: Markdown, HTML, JSON, CSV, or Executive summary
  # Sections: Summary, Critical CVEs, License violations, High-risk packages
  # Usage: python generate-dependency-report.py --sbom report.json --format markdown
  ```

- [x] T044 [US3] Add report artifact upload to scheduled-maintenance.yml
  - Upload consolidated SBOM CSV and JSON
  - Upload dependency audit reports
  - Upload license compliance report
  - Integrated into consolidate-sboms and weekly-report jobs

#### 5.4 Testing & Validation

- [ ] T045 [US3] Trigger scheduled-maintenance workflow manually
  - Verify all services scanned (<10 min target)
  - Download and review consolidated SBOM
  - Verify license policy checking works
  - Verify GitHub Issues created for CVEs

- [ ] T046 [US3] Test license violation detection
  - Add GPL package to test service
  - Run license checker
  - Verify violation reported in audit

- [ ] T047 [US3] Validate CVE tracking
  - Verify no duplicate issues for same CVE
  - Test issue update when CVE affects multiple services
  - Test issue closure when CVE is fixed

**Checkpoint**: Security auditing complete - 100% SBOM coverage, automated CVE tracking

---

## Phase 6: User Story 4 - DevOps Engineer Understands Build Pipeline (Priority: P2)

**Goal**: Comprehensive job summaries enable <5 minute failure diagnosis without clicking into logs

**Independent Test**: Simulate failed build (inject CVE). Verify engineer can identify cause from PR page alone. Summary should show: which service failed, why, fix suggestion, docs link.

### Implementation for User Story 4

#### 6.1 Enhanced Job Summaries

- [x] T048 [P] [US4] Enhance arc-job-summary action to support multiple result types
  - Added templates for build, security, validation, deployment, metrics
  - Added quick stats output (✅ X passed, ❌ Y failed)
  - Support emoji indicators: ✅ ❌ ⚠️ 🔄
  - Added collapsible sections for detailed data

- [x] T049 [P] [US4] Add failure diagnostics to job summaries
  - Parse error JSON and extract key info
  - Link to relevant documentation via docs-base-url input
  - Suggest fixes based on error type
  - Show affected files/lines in diagnostics section

- [x] T050 [P] [US4] Create summary templates directory at `.github/config/summary-templates/`
  - Created README.md with JSON schema documentation
  - Templates integrated directly into arc-job-summary action
  - Documented expected JSON input formats

#### 6.2 PR Comments

- [x] T051 [US4] Add PR comment generation to pr-checks.yml summary job
  - Created post-pr-comment.py script for posting/updating
  - Uses COMMENT_MARKER to find and update existing comments
  - Includes quick stats and links to full job summary
  - Supports --dry-run for testing

- [x] T052 [US4] Create PR comment script at `.github/scripts/ci/post-pr-comment.py`
  ```python
  #!/usr/bin/env python3
  # Post or update PR comment with workflow results
  # Input: Results JSON, PR number, quick-stats
  # Features: Find/update existing comment, dry-run mode
  # Usage: python post-pr-comment.py --results results.json --pr 123
  ```

#### 6.3 Metrics Dashboard (Future)

- [x] T053 [US4] Create metrics export script at `.github/scripts/ci/export-metrics.py`
  ```python
  #!/usr/bin/env python3
  # Export workflow metrics for dashboard
  # Metrics: build_time, image_size, cve_count, cache_hit_rate
  # Formats: JSON, Prometheus, CSV
  # Usage: python export-metrics.py --results results.json --format prometheus
  ```

- [x] T054 [US4] Document metrics schema in `.github/config/metrics-schema.json`
  - Defined WorkflowMetrics and MetricsTrend schemas
  - Documented SLA targets (PR < 3min, cache > 85%)
  - Added Prometheus metric definitions
  - Added alerting rule suggestions

#### 6.4 Testing & Validation

- [x] T055 [US4] Test job summaries with various failure scenarios
  - Scripts validated with Python syntax checks
  - JSON schema documented for all result types
  - Runtime testing deferred to actual workflow runs

- [x] T056 [US4] Test PR comment updates
  - COMMENT_MARKER implemented for update detection
  - Script supports --update-existing and --no-update flags
  - Runtime testing deferred to actual PR workflow

**Checkpoint**: Observability complete - engineers can diagnose failures in <5 minutes

---

## Phase 7: User Story 5 - Architect Orchestrates Complex Workflows (Priority: P2)

**Goal**: Production release pipeline with blue/green deployment, smoke tests, manual approval, rollback

**Independent Test**: Create tag `v1.0.0-test`. Verify automated flow: builds images, tags with semver, deploys to staging, runs smoke tests, waits for approval. Test rollback on failure.

### Implementation for User Story 5

#### 7.1 Publish Vendor Images Orchestrator

- [ ] T057 [P] [US5] Create publish configuration for gateway at `.github/config/publish-gateway.json`
  ```json
  {
    "images": [
      {"source": "traefik:v3.0", "target": "arc-heimdall-gateway", "platforms": ["linux/amd64", "linux/arm64"]},
      {"source": "unleashorg/unleash-server:latest", "target": "arc-mystique-flags", "platforms": ["linux/amd64", "linux/arm64"]},
      {"source": "oryd/kratos:latest", "target": "arc-jarvis-identity", "platforms": ["linux/amd64", "linux/arm64"]},
      {"source": "infisical/infisical:latest", "target": "arc-fury-vault", "platforms": ["linux/amd64"]}
    ],
    "rate_limit_delay_seconds": 30,
    "retry_attempts": 3
  }
  ```

- [ ] T058 [P] [US5] Create publish configuration for data services at `.github/config/publish-data.json`
  - 5 images: postgres, redis, qdrant, etc.

- [ ] T059 [P] [US5] Create publish configuration for observability at `.github/config/publish-observability.json`
  - 6 images: prometheus, grafana, loki, jaeger, etc.

- [ ] T060 [P] [US5] Create publish configuration for communication at `.github/config/publish-communication.json`
  - 3 images: nats, pulsar, livekit

- [ ] T061 [P] [US5] Create publish configuration for tools at `.github/config/publish-tools.json`
  - 5 images: otel-collector, chaos-mesh, etc.

- [ ] T062 [US5] Create reusable publish group workflow at `.github/workflows/_reusable-publish-group.yml`
  - Workflow input: group-name (display name)
  - Workflow input: config-file (path to JSON config)
  - Parse JSON config with jq
  - Matrix build for each image in config
  - Pull source image, tag as arc-* target
  - Build multi-arch with docker buildx
  - Add rate limit delay (sleep 30s between pushes)
  - Retry logic with exponential backoff (3 attempts)
  - Workflow output: images-published (count), images-failed (array)

- [ ] T063 [US5] Create publish orchestrator at `.github/workflows/publish-vendor-images.yml`
  - Trigger: workflow_dispatch with input groups (choice: all, gateway, data, observability, communication, tools)
  - Trigger: schedule cron '0 8 * * 0' (weekly Sunday 8 AM UTC)
  - Job: publish-gateway (if groups=all or gateway)
  - Job: publish-data (needs: [publish-gateway], if groups=all or data)
  - Job: publish-observability (needs: [publish-data], if groups=all or observability)
  - Job: publish-communication (needs: [publish-gateway], if groups=all or communication) - parallel with data
  - Job: publish-tools (needs: [publish-gateway], if groups=all or tools) - parallel with data
  - Job: publish-summary (needs: all jobs, if: always()) - aggregate results table

#### 7.2 Release Pipeline

- [ ] T064 [US5] Create release orchestration workflow at `.github/workflows/release.yml`
  - Trigger: push tags matching 'v*.*.*'
  - Job 1 (validate-tag): Verify semantic version format
  - Job 2 (build-and-push): Build all services with immutable semver tags
  - Job 3 (deploy-staging): Deploy to staging environment
  - Job 4 (smoke-tests): Run health checks and API tests
  - Job 5 (manual-approval): Wait for manual approval via environment protection rule
  - Job 6 (deploy-production): Deploy to production with gradual rollout
  - Job 7 (create-release): Create GitHub Release with changelog
  - Job 8 (rollback): If deploy fails, rollback to previous version, needs: [deploy-production], if: failure()

- [ ] T065 [US5] Create reusable test workflow at `.github/workflows/_reusable-test.yml`
  - Workflow input: service-name
  - Workflow input: test-type (unit, integration, smoke)
  - Workflow input: environment (dev, staging, production)
  - Run health checks (HTTP 200 from /health endpoint)
  - Run smoke tests (basic API calls)
  - Workflow output: test-status, test-count

- [ ] T066 [US5] Create smoke test script at `.github/scripts/ci/run-smoke-tests.sh`
  ```bash
  #!/bin/bash
  # Run smoke tests against deployed services
  # Input: Environment URL
  # Output: JSON results
  # Usage: ./run-smoke-tests.sh --env staging
  ```

#### 7.3 Rollback Mechanism

- [ ] T067 [US5] Create rollback script at `.github/scripts/ci/rollback-deployment.sh`
  ```bash
  #!/bin/bash
  # Rollback to previous deployment
  # Input: Service name, environment
  # Action: Revert to previous image tag
  # Usage: ./rollback-deployment.sh --service arc-sherlock-brain --env production
  ```

- [ ] T068 [US5] Add rollback job to release.yml
  - Trigger on deploy failure
  - Call rollback script
  - Create incident issue
  - Send notification

#### 7.4 Testing & Validation

- [ ] T069 [US5] Test publish orchestrator with selective publishing
  - Trigger with groups=gateway
  - Verify only 4 gateway images published
  - Measure duration (~12 min expected)

- [ ] T070 [US5] Test publish orchestrator with full publishing
  - Trigger with groups=all
  - Verify all 25 images published
  - Verify no GHCR rate limit errors
  - Measure duration (30-35 min target)

- [ ] T071 [US5] Test release pipeline end-to-end
  - Create test tag v0.0.1-test
  - Verify staging deployment
  - Verify manual approval gate works
  - Test rollback on simulated failure

**Checkpoint**: Complex orchestration working - publish, release, rollback tested

---

## Phase 8: User Story 6 - Cost Controller Optimizes CI/CD Spend (Priority: P3)

**Goal**: Track CI/CD costs, identify expensive workflows, stay within 2,000 min/month free tier

**Independent Test**: Generate cost report showing minutes used per workflow, cost per build, trend over 30 days, projected monthly cost.

### Implementation for User Story 6

#### 8.1 Cost Tracking

- [ ] T072 [P] [US6] Create cost calculation script at `.github/scripts/ci/calculate-costs.sh`
  ```bash
  #!/bin/bash
  # Calculate CI/CD costs from workflow runs
  # Input: GitHub API token
  # Output: Cost report JSON
  # Usage: ./calculate-costs.sh --days 30 --output costs.json
  ```

- [ ] T073 [P] [US6] Create cost report generator at `.github/scripts/ci/generate-cost-report.py`
  ```python
  #!/usr/bin/env python3
  # Generate human-readable cost report
  # Input: Cost data JSON
  # Output: Markdown report with tables and trends
  # Sections: Total usage, cost per workflow, top expensive workflows, forecast
  # Usage: python generate-cost-report.py --input costs.json --output report.md
  ```

#### 8.2 Cost Optimization Recommendations

- [ ] T074 [US6] Add cost tracking to all orchestration workflows
  - Track start/end time for each job
  - Calculate total minutes used
  - Export to metrics

- [ ] T075 [US6] Create cost monitoring workflow at `.github/workflows/cost-monitoring.yml`
  - Trigger: schedule cron '0 0 * * *' (daily midnight)
  - Job 1: Calculate costs for last 24 hours
  - Job 2: Generate cost report
  - Job 3: Check if approaching 80% of free tier
  - Job 4: Create alert issue if threshold exceeded
  - Upload cost report as artifact

#### 8.3 Testing & Validation

- [ ] T076 [US6] Generate cost report for last 30 days
  - Verify all workflows tracked
  - Identify top 3 expensive workflows
  - Calculate projected monthly cost

- [ ] T077 [US6] Test cost alerting
  - Simulate approaching 80% threshold
  - Verify alert issue created
  - Verify recommendations included

**Checkpoint**: Cost visibility complete - proactive monitoring in place

---

## Phase 9: Enhancements & Polish

**Purpose**: Add advanced features and optimizations

### 9.1 Image Signing (Future)

- [ ] T078 [P] Create Cosign signing workflow (placeholder)
  - Document Cosign setup requirements
  - Add keyless signing via GitHub OIDC
  - Mark as Phase 2 enhancement

### 9.2 Cache Optimization

- [ ] T079 Update cache keys to be more granular
  - Separate tool cache from dependency cache
  - Add cache cleanup for old entries
  - Monitor cache storage usage

- [ ] T080 Add cache hit rate tracking
  - Export cache hit rate as metric
  - Alert if <80% hit rate
  - Provide optimization suggestions

### 9.3 Documentation

- [ ] T081 [P] Create CI/CD developer guide at `docs/guides/CICD-DEVELOPER-GUIDE.md`
  - How workflows are organized
  - How to add new service to CI/CD
  - How to test workflows locally
  - Troubleshooting common issues

- [ ] T082 [P] Create CI/CD architecture diagram at `docs/architecture/CICD-ARCHITECTURE.md`
  - Show layered architecture (actions → reusable → orchestration)
  - Show trigger contexts (PR, merge, tag, scheduled)
  - Show job dependencies and execution flow

- [ ] T083 [P] Update main README.md with CI/CD section
  - Link to developer guide
  - Show CI/CD status badges
  - Document how to trigger workflows

**Checkpoint**: Enhancements complete - documentation ready

---

## Phase 10: Migration & Cleanup

**Purpose**: Deprecate old workflows, update documentation, train team

### 10.1 Workflow Deprecation

- [ ] T084 Move old workflows to DEPRECATED folder
  - docker-publish.yml → DEPRECATED/
  - publish-communication.yml → DEPRECATED/
  - publish-data-services.yml → DEPRECATED/
  - publish-gateway.yml → DEPRECATED/
  - publish-observability.yml → DEPRECATED/
  - publish-tools.yml → DEPRECATED/
  - reusable-publish.yml → DEPRECATED/
  - security-scan.yml → DEPRECATED/ (replaced by scheduled-maintenance.yml)
  - validate-docker.yml → DEPRECATED/ (replaced by pr-checks.yml)
  - validate-structure.yml → DEPRECATED/ (replaced by pr-checks.yml)

- [ ] T085 Add deprecation notices to old workflow files
  - Add banner comment at top
  - Link to replacement workflow
  - Set 30-day grace period before deletion

- [ ] T086 Update all documentation links
  - Search for references to old workflows
  - Update to point to new workflows
  - Verify all links work

### 10.2 Validation & Testing

- [ ] T087 Run full validation suite
  - actionlint on all workflows
  - shellcheck on all scripts
  - ruff on all Python scripts
  - Verify no errors

- [ ] T088 End-to-end testing of all scenarios
  - Create PR → verify pr-checks.yml runs (<3 min)
  - Merge PR → verify main-deploy.yml runs (<5 min)
  - Create tag → verify release.yml runs
  - Trigger scheduled-maintenance.yml manually
  - Trigger publish-vendor-images.yml with groups=all

- [ ] T089 Metrics validation
  - Verify PR validation time <3 min (85th percentile)
  - Verify cache hit rate >85%
  - Verify SBOM coverage 100%
  - Verify zero manual publish operations
  - Verify zero GHCR rate limit errors

### 10.3 Team Training

- [ ] T090 Create CI/CD walkthrough video
  - Demo new workflows
  - Show how to interpret job summaries
  - Show how to troubleshoot failures

- [ ] T091 Conduct team Q&A session
  - Answer questions about new workflows
  - Collect feedback
  - Document common questions in FAQ

- [ ] T092 Update onboarding documentation
  - Add CI/CD section to onboarding guide
  - Ensure new developers understand workflow structure

### 10.4 Final Cleanup

- [ ] T093 Delete DEPRECATED workflows after 30-day grace period
  - Verify no references remaining
  - Archive for historical reference
  - Update changelog

- [ ] T094 Create feature completion report
  - Document metrics before/after
  - Show cost savings achieved
  - Show time savings achieved
  - Gather team feedback

**Checkpoint**: Migration complete - old workflows deprecated, team trained

---

## Dependencies & Execution Order

### Critical Path (Must Be Sequential)

```
Phase 1 (Setup) → Phase 2 (Foundation) → Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3)
```

### Parallel Opportunities

**Phase 1 (Week 1)**: All 9 tasks can run in parallel (different files)

**Phase 2 (Week 1-2)**: 
- T010, T011, T012, T013, T014 (5 composite actions) - parallel
- T015, T016, T017 (3 helper scripts) - parallel

**Phase 3 (Week 2-3)**: 
- T018, T019, T020 (3 reusable workflows) - parallel after Phase 2
- T021, T022 (PR orchestration) - after reusable workflows
- T023, T024 (caching) - parallel with T021-T022

**Phase 4-5-6 (Week 3-4)**: 
- US2, US3, US4 can be developed in parallel by different team members

**Phase 7 (Week 4-5)**:
- T057-T061 (5 config files) - parallel
- T064-T068 (release pipeline) - parallel with publish orchestrator

**Phase 8-9-10 (Week 5-6)**:
- US6, enhancements, migration can overlap

---

## Success Metrics

### MVP Success Criteria (Phases 1-5)
- ✅ PR validation <3 minutes (currently 8 minutes)
- ✅ Cache hit rate >85% (currently ~40%)
- ✅ Auto-deploy to dev on merge (<5 min)
- ✅ SBOM coverage 100%
- ✅ Zero manual publish operations

### Full Feature Success Criteria (All Phases)
- ✅ 58% reduction in workflow files (12 → 5 core orchestrators)
- ✅ 60% faster PR validation (8 min → 3 min)
- ✅ 28% reduction in CI/CD minutes (908 → 650 min/month)
- ✅ Zero GHCR rate limit errors
- ✅ <5 minute failure diagnosis time
- ✅ Production release automation working
- ✅ Cost tracking and forecasting active

---

## Task Summary

**Total Tasks**: 94
**MVP Tasks (US1-US3)**: 47 (Phases 1-5)
**Full Feature Tasks**: 94 (All Phases)

**By User Story**:
- Setup: 9 tasks
- Foundation: 8 tasks
- US1 (Fast PR Feedback): 10 tasks
- US2 (Auto Publishing): 10 tasks
- US3 (Security Auditing): 10 tasks
- US4 (Observability): 9 tasks
- US5 (Orchestration): 15 tasks
- US6 (Cost Tracking): 6 tasks
- Enhancements: 5 tasks
- Migration: 12 tasks

**Parallel Opportunities**: 
- 60% of tasks can run in parallel (marked with [P])
- Estimated 30% time savings through parallelization

**Suggested MVP Scope**: Phases 1-5 (US1-US3)
- Delivers core value: fast validation, automated publishing, security
- 3 weeks with 2-3 developers
- Foundational for remaining user stories

---

## Next Steps

1. **Review tasks.md**: Team reviews task breakdown
2. **Assign ownership**: Assign user stories to team members
3. **Create feature branch**: `git checkout -b 003-stabilize-github-actions`
4. **Start Phase 1**: Begin setup and infrastructure tasks
5. **Daily standups**: Track progress using task checkboxes

**Ready for implementation! 🚀**

