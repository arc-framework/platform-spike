# Implementation Plan: GitHub Actions CI/CD Optimization & Enterprise Standardization

**Branch**: `003-stabilize-github-actions` | **Date**: January 11, 2026 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-stabilize-github-actions/spec.md`

---

## Summary

The A.R.C. Platform has 12 GitHub Actions workflows with significant redundancy, unclear trigger contexts, and inefficient resource usage. This feature optimizes and standardizes the CI/CD pipeline through:

1. **Workflow consolidation** via intelligent orchestration (12 → 5 core workflows, 58% reduction)
2. **Aggressive caching strategy** achieving <60 second incremental builds
3. **Enterprise security** with SBOM generation, image signing, and CVE tracking
4. **Full observability** through job summaries, PR comments, and metrics
5. **Controlled parallelism** solving GHCR rate limiting issues

**Primary Goals:**
- Reduce PR validation time from 8 minutes to <3 minutes
- Eliminate manual publish operations (100% → 0%)
- Achieve 85%+ cache hit rate (currently ~40%)
- Implement enterprise security (SBOM, signing, CVE tracking)
- Zero GHCR rate limit errors through intelligent orchestration

**Technical Approach:**
- Create composite actions for reusable setup steps (Python, Docker, validation)
- Build reusable workflows for core operations (validate, build, security, test, publish)
- Implement orchestration workflows that control execution flow and parallelism
- Use GitHub Actions job dependencies to manage rate limits
- Generate comprehensive job summaries for instant feedback

---

## Technical Context

**Primary Languages/Versions:**
- **YAML**: GitHub Actions workflow syntax
- **Bash**: 4.0+ for workflow scripts and CI/CD helpers
- **Python**: 3.11+ for validation scripts and matrix generation
- **JSON**: Configuration files for image definitions

**Primary Dependencies:**
- **GitHub Actions**: GitHub's CI/CD platform (99.9% SLA)
- **Docker BuildKit**: 0.11+ for multi-stage builds and caching
- **GHCR** (GitHub Container Registry): Image storage and distribution
- **hadolint**: v2.12+ for Dockerfile linting
- **trivy**: v0.48+ for security vulnerability scanning
- **cosign**: v2.2+ for image signing (future phase)

**GitHub Actions Ecosystem:**
- `actions/checkout@v4` - Repository checkout
- `actions/cache@v4` - Dependency caching
- `actions/setup-python@v5` - Python environment
- `docker/setup-buildx-action@v3` - BuildKit setup
- `docker/build-push-action@v5` - Docker builds
- `docker/login-action@v3` - Registry authentication
- `aquasecurity/trivy-action@master` - Security scanning

**Testing:**
- **Workflow Validation**: `actionlint` for YAML syntax and best practices
- **Local Testing**: `act` tool for running workflows locally
- **Integration Testing**: Test PRs in isolated branches
- **Smoke Testing**: Verify each workflow with minimal test cases

**Target Platform:**
- **CI/CD**: GitHub Actions (cloud runners)
- **Container Registry**: GHCR (ghcr.io/arc/*)
- **Runner Specs**: ubuntu-latest (7GB RAM, 2 CPU cores, 14GB disk)

**Performance Goals:**
- **PR Validation**: <3 minutes (currently 8 minutes)
- **Service Build (cached)**: <60 seconds for code-only changes
- **Service Build (cold)**: <6 minutes for full rebuild
- **Publish Workflow**: 30-35 minutes for all 25 vendor images
- **Cache Hit Rate**: >85% (currently ~40%)

**Constraints:**
- **GitHub Actions Limits**: 2,000 minutes/month (free tier), 6-hour job timeout
- **GHCR Rate Limits**: ~5,000 requests/hour (authenticated)
- **Runner Resources**: 7GB RAM, 2 CPU cores per job
- **File Size Limits**: Workflow files should be <500 lines (readability)
- **Concurrency**: Max 20 concurrent jobs per organization (free tier)

**Scale/Scope:**
- **Current Workflows**: 12 files (5 publish, 4 validation, 1 reusable, 2 misc)
- **Target Workflows**: 5 core orchestration workflows
- **Reusable Workflows**: 5 shared operation workflows
- **Composite Actions**: 5 setup/utility actions
- **Services to Build**: 7 custom services (sherlock-brain, scarlett-voice, piper-tts, etc.)
- **Vendor Images to Mirror**: 25 images across 5 categories
- **Team Size**: 3-5 developers currently, scaling to 10 within 6 months

---

## Architecture Validation

✅ **Constitution Check Passed:** Layered architecture (composite actions → reusable workflows → orchestration workflows) follows simplicity principles. Controlled parallelism via job dependencies prevents over-engineering. GHCR rate limiting solution is justified by infrastructure constraints. No premature optimization detected.

---

## Project Structure

### Documentation (this feature)

```text
specs/003-stabilize-github-actions/
├── spec.md                          # Feature specification (user stories)
├── plan.md                          # This file (implementation plan)
├── research.md                      # Enterprise best practices research
├── current-state-analysis.md        # Analysis of existing 12 workflows
├── ghcr-rate-limiting-solution.md   # Deep dive on rate limiting solution
├── tasks.md                         # Phase-by-phase task breakdown
└── checklists/
    └── requirements.md              # Quality validation checklist
```

### Source Code (repository root)

**Current Structure** (before refactoring):

```text
.github/
├── workflows/
│   ├── build-base-images.yml           # Base image builds (keep, refine)
│   ├── docker-publish.yml              # Legacy monolithic (DEPRECATE)
│   ├── publish-communication.yml       # Manual publish (CONSOLIDATE)
│   ├── publish-data-services.yml       # Manual publish (CONSOLIDATE)
│   ├── publish-gateway.yml             # Manual publish (CONSOLIDATE)
│   ├── publish-observability.yml       # Manual publish (CONSOLIDATE)
│   ├── publish-tools.yml               # Manual publish (CONSOLIDATE)
│   ├── reusable-publish.yml            # Shared logic (REFACTOR)
│   ├── security-scan.yml               # Security scanning (ENHANCE)
│   ├── track-build-performance.yml     # Performance tracking (OPTIMIZE)
│   ├── validate-docker.yml             # Dockerfile linting (REFINE)
│   └── validate-structure.yml          # Structure validation (REFINE)
└── instructions/
    └── copilot.instructions.md
```

**Target Structure** (after refactoring):

```text
.github/
├── actions/                            # NEW: Composite actions (reusable setup)
│   ├── setup-arc-python/
│   │   ├── action.yml                  # Python 3.11 + pip cache + tools
│   │   └── README.md
│   ├── setup-arc-docker/
│   │   ├── action.yml                  # GHCR login + BuildKit + cache
│   │   └── README.md
│   ├── setup-arc-validation/
│   │   ├── action.yml                  # hadolint + trivy + shellcheck
│   │   └── README.md
│   ├── arc-job-summary/
│   │   ├── action.yml                  # Generate markdown summaries
│   │   └── README.md
│   └── arc-notify/
│       ├── action.yml                  # Slack/GitHub notifications (future)
│       └── README.md
├── config/                             # NEW: Configuration files
│   ├── publish-gateway.json            # Gateway image definitions
│   ├── publish-data.json               # Data service image definitions
│   ├── publish-observability.json      # Observability image definitions
│   ├── publish-communication.json      # Communication image definitions
│   └── publish-tools.json              # Tools image definitions
├── scripts/                            # NEW: CI/CD helper scripts
│   └── ci/
│       ├── parse-services.py           # Parse SERVICE.MD for service matrix
│       ├── generate-matrix.py          # Generate job matrix from config
│       ├── calculate-costs.sh          # CI/CD cost reporting
│       └── validate-workflows.sh       # Local workflow validation
├── workflows/
│   ├── _reusable-validate.yml          # NEW: Reusable validation logic
│   ├── _reusable-build.yml             # NEW: Reusable build logic
│   ├── _reusable-security.yml          # NEW: Reusable security scan logic
│   ├── _reusable-test.yml              # NEW: Reusable test logic
│   ├── _reusable-publish-group.yml     # NEW: Reusable publish logic (refactored)
│   ├── pr-checks.yml                   # NEW: PR validation orchestrator
│   ├── main-deploy.yml                 # NEW: Dev deployment orchestrator
│   ├── publish-vendor-images.yml       # NEW: Publish orchestrator (replaces 5 files)
│   ├── release.yml                     # NEW: Production release orchestrator
│   ├── scheduled-maintenance.yml       # NEW: Nightly/weekly tasks
│   ├── build-base-images.yml           # ENHANCED: Keep, add caching
│   └── DEPRECATED/                     # OLD: Moved for reference
│       ├── docker-publish.yml
│       ├── publish-communication.yml
│       ├── publish-data-services.yml
│       ├── publish-gateway.yml
│       ├── publish-observability.yml
│       ├── publish-tools.yml
│       ├── reusable-publish.yml
│       ├── security-scan.yml
│       ├── track-build-performance.yml
│       ├── validate-docker.yml
│       └── validate-structure.yml
└── instructions/
    └── copilot.instructions.md
```

**Structure Decision:**

- **Keep layered architecture** (actions → reusable workflows → orchestration)
- **Add `.github/actions/`** for composite actions (shared setup logic)
- **Add `.github/config/`** for JSON configuration files (structured data)
- **Add `.github/scripts/ci/`** for helper scripts (matrix generation, cost tracking)
- **Enhance existing workflows** where they serve unique purposes (base images, security)
- **Deprecate redundant workflows** by moving to DEPRECATED/ folder (30-day grace period)

---

## Phase 0: Research & Discovery

**Objective:** Research enterprise best practices, analyze current workflows, and design optimal architecture.

**Deliverable:** Complete research and analysis documents:
- [`research.md`](./research.md) - ✅ COMPLETE
- [`current-state-analysis.md`](./current-state-analysis.md) - ✅ COMPLETE
- [`ghcr-rate-limiting-solution.md`](./ghcr-rate-limiting-solution.md) - ✅ COMPLETE

**Key Findings:**
1. **Workflow Organization:** Layered architecture (composite → reusable → orchestration) proven in Kubernetes, Next.js, Terraform
2. **Reusable Workflows:** Single responsibility, input validation, output propagation
3. **Composite Actions:** For repeated setup steps (Python, Docker, tools)
4. **Caching:** 3-tier strategy (tools, dependencies, Docker builds) = 60-85% faster
5. **Security:** SBOM generation, Cosign signing, SLSA provenance
6. **Rate Limiting:** Controlled parallelism via job dependencies solves GHCR issues
7. **Cost Optimization:** Path filtering, concurrency limits, fail-fast = 28% savings
8. **Observability:** Job summaries, PR comments, metrics export

**Timeline:** 1 week (COMPLETED)  
**Output:** ✅ Three comprehensive research documents completed

---

## Phase 1: Foundation Layer - Composite Actions

**Objective:** Create reusable composite actions for setup steps to eliminate duplication.

**Deliverables:**

### 1.1 Setup Python Action
**File:** `.github/actions/setup-arc-python/action.yml`

**Functionality:**
- Install Python 3.11
- Cache pip dependencies based on requirements.txt hash
- Install common tools (ruff, black, mypy, pytest)
- Set environment variables (PYTHONUNBUFFERED, etc.)

**Benefits:**
- Used in: pr-checks, main-deploy, validate workflows
- Replaces 4 duplicate setup blocks
- Consistent Python environment across all jobs

---

### 1.2 Setup Docker Action
**File:** `.github/actions/setup-arc-docker/action.yml`

**Functionality:**
- Login to GHCR with GitHub token
- Setup Docker BuildKit with latest version
- Configure cache settings (mode=max)
- Set Docker environment variables (DOCKER_BUILDKIT=1)

**Benefits:**
- Used in: build, publish, base-image workflows
- Replaces 8 duplicate login/buildx blocks
- Consistent Docker configuration

---

### 1.3 Setup Validation Action
**File:** `.github/actions/setup-arc-validation/action.yml`

**Functionality:**
- Install hadolint (Dockerfile linter)
- Install trivy (security scanner)
- Install shellcheck (shell script linter)
- Cache tool binaries for faster subsequent runs

**Benefits:**
- Used in: pr-checks, security workflows
- Replaces 3 duplicate tool installation blocks
- Consistent tool versions

---

### 1.4 Job Summary Action
**File:** `.github/actions/arc-job-summary/action.yml`

**Functionality:**
- Generate markdown job summary from JSON results
- Add emoji status indicators (✅ ❌ ⚠️)
- Create tables, badges, and links
- Support multiple result formats

**Benefits:**
- Used in: ALL workflows
- Visual feedback without clicking into logs
- Consistent summary format

---

### 1.5 Notification Action (Future)
**File:** `.github/actions/arc-notify/action.yml`

**Functionality:**
- Send Slack notifications (future feature)
- Create GitHub Issues for CVEs
- Update status dashboard

**Benefits:**
- Centralized notification logic
- Easy to extend to other channels

**Timeline:** Week 1 (5 days)  
**Dependencies:** None  
**Validation:** Test each action in isolation with minimal workflow

---

## Phase 2: Reusable Workflow Layer

**Objective:** Create reusable workflows for core operations (validate, build, security, test, publish).

**Deliverables:**

### 2.1 Reusable Validate Workflow
**File:** `.github/workflows/_reusable-validate.yml`

**Inputs:**
- `paths`: Array of paths to validate
- `fail-fast`: Boolean (default: true)

**Jobs:**
1. Dockerfile linting (hadolint)
2. Structure validation (SERVICE.MD sync)
3. YAML validation (actionlint)

**Outputs:**
- `validation-status`: pass/fail
- `errors`: Array of error messages

---

### 2.2 Reusable Build Workflow
**File:** `.github/workflows/_reusable-build.yml`

**Inputs:**
- `service-name`: Service to build
- `service-path`: Path to service directory
- `push-image`: Boolean (default: false for PR, true for main)
- `platforms`: Array of platforms (default: linux/amd64,linux/arm64)

**Jobs:**
1. Build Docker image with BuildKit
2. Use 3-tier caching (gha cache mode)
3. Generate SBOM (if push-image=true)
4. Track build time and image size

**Outputs:**
- `image-digest`: SHA256 digest
- `image-size`: Size in MB
- `build-duration`: Time in seconds

---

### 2.3 Reusable Security Workflow
**File:** `.github/workflows/_reusable-security.yml`

**Inputs:**
- `scan-type`: fs (filesystem) or image
- `severity`: CRITICAL, HIGH, MEDIUM, LOW
- `fail-on-severity`: Level to fail build

**Jobs:**
1. Trivy security scan
2. Generate SARIF report
3. Upload to GitHub Security tab
4. Create GitHub Issue for CRITICAL CVEs (if found)

**Outputs:**
- `cve-count`: Number of CVEs found
- `critical-cves`: Array of CRITICAL CVEs

---

### 2.4 Reusable Test Workflow
**File:** `.github/workflows/_reusable-test.yml`

**Inputs:**
- `service-name`: Service to test
- `test-type`: unit, integration, smoke

**Jobs:**
1. Run pytest for Python services
2. Run health checks for services
3. Run integration tests via Docker Compose

**Outputs:**
- `test-status`: pass/fail
- `test-count`: Total tests run
- `coverage`: Code coverage percentage

---

### 2.5 Reusable Publish Group Workflow
**File:** `.github/workflows/_reusable-publish-group.yml`

**Inputs:**
- `group-name`: Display name (e.g., "Gateway & Identity")
- `config-file`: Path to JSON config (e.g., .github/config/publish-gateway.json)

**Jobs:**
1. Parse JSON config
2. Build multi-arch images for each source
3. Tag as arc-* target names
4. Push to GHCR with rate limit handling (30s delays)
5. Retry logic (3 attempts with exponential backoff)

**Outputs:**
- `images-published`: Count of successful publishes
- `images-failed`: Count of failures
- `duration`: Total time in minutes

**Timeline:** Week 2 (5 days)  
**Dependencies:** Phase 1 (composite actions)  
**Validation:** Test each workflow in isolation via workflow_dispatch

---

## Phase 3: Orchestration Layer - PR Checks

**Objective:** Create unified PR validation workflow that runs fast checks in parallel.

**Deliverable:**

### 3.1 PR Checks Workflow
**File:** `.github/workflows/pr-checks.yml`

**Triggers:**
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - 'services/**'
      - 'core/**'
      - 'plugins/**'
      - '.docker/**'
      - '**/Dockerfile'
      - '**/requirements.txt'
      - '.github/workflows/**'
```

**Concurrency:**
```yaml
concurrency:
  group: pr-checks-${{ github.ref }}
  cancel-in-progress: true  # Cancel old runs on new push
```

**Jobs:**
1. **validate** (2 min)
   - Call _reusable-validate.yml
   - Lint Dockerfiles, validate structure
   
2. **security-scan** (3 min) - Parallel with validate
   - Call _reusable-security.yml
   - Scan filesystem for CRITICAL CVEs only
   - Fail build if CRITICAL found

3. **build-changed-services** (2-3 min) - After validate passes
   - Detect changed services via git diff
   - Call _reusable-build.yml in matrix (parallel builds)
   - Build but don't push (push-image=false)
   - Track build time and image size

4. **generate-summary** - After all jobs
   - Aggregate results from all jobs
   - Generate markdown summary
   - Post PR comment with results

**Success Criteria:**
- Total duration: <3 minutes (85th percentile)
- Cache hit rate: >85%
- Single "PR Checks" status in GitHub

**Timeline:** Week 3 (3 days)  
**Dependencies:** Phase 2 (reusable workflows)  
**Validation:** Create test PR with code changes, verify <3 min completion

---

## Phase 4: Orchestration Layer - Main Deploy

**Objective:** Automated deployment to dev environment on merge to main.

**Deliverable:**

### 4.1 Main Deploy Workflow
**File:** `.github/workflows/main-deploy.yml`

**Triggers:**
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'services/**'
      - 'core/**'
      - 'plugins/**'
      - '.docker/**'
```

**Jobs:**
1. **detect-changes** (30 sec)
   - Determine which services changed
   - Output matrix of services to build

2. **build-and-push** (3-5 min) - Matrix build
   - Call _reusable-build.yml for each changed service
   - Build and push to GHCR with dev-<sha> tags
   - Generate SBOM for each image

3. **security-scan** (3 min) - After build
   - Call _reusable-security.yml
   - Full scan (all severities) on pushed images
   - Create GitHub Issues for HIGH/CRITICAL CVEs

4. **deploy-to-dev** (2 min) - After security passes
   - Update Docker Compose files with new image tags
   - Restart affected services in dev environment
   - Run smoke tests

5. **notify** (30 sec) - After deploy
   - Send Slack notification with deploy details
   - Include links to images, logs, dev URLs

**Success Criteria:**
- Total duration: <10 minutes
- SBOM coverage: 100%
- Zero HIGH/CRITICAL CVEs in published images

**Timeline:** Week 3 (2 days)  
**Dependencies:** Phase 3 (pr-checks workflow)  
**Validation:** Merge test PR, verify auto-deploy to dev

---

## Phase 5: Orchestration Layer - Publish Vendor Images

**Objective:** Consolidate 5 publish workflows into intelligent orchestrator with controlled parallelism.

**Deliverables:**

### 5.1 JSON Configuration Files
**Files:** `.github/config/publish-*.json` (5 files)

**Format:**
```json
{
  "images": [
    {
      "source": "traefik:v3.0",
      "target": "arc-heimdall-gateway",
      "platforms": ["linux/amd64", "linux/arm64"],
      "description": "API Gateway & Reverse Proxy"
    }
  ],
  "rate_limit_delay_seconds": 30,
  "retry_attempts": 3,
  "timeout_minutes": 10
}
```

**Images per file:**
- publish-gateway.json: 4 images
- publish-data.json: 5 images
- publish-observability.json: 6 images
- publish-communication.json: 3 images
- publish-tools.json: 5 images

---

### 5.2 Publish Orchestrator Workflow
**File:** `.github/workflows/publish-vendor-images.yml`

**Triggers:**
```yaml
on:
  workflow_dispatch:
    inputs:
      groups:
        type: choice
        options: ['all', 'gateway', 'data', 'observability', 'communication', 'tools']
  schedule:
    - cron: '0 8 * * 0'  # Weekly Sunday 8 AM UTC
```

**Job Dependencies (Controlled Parallelism):**
```yaml
jobs:
  publish-gateway:       # Layer 1: Foundation (12 min)
    if: inputs.groups == 'all' || inputs.groups == 'gateway'
    uses: ./.github/workflows/_reusable-publish-group.yml
    
  publish-data:          # Layer 2: Sequential after gateway (15 min)
    needs: [publish-gateway]
    if: inputs.groups == 'all' || inputs.groups == 'data'
    uses: ./.github/workflows/_reusable-publish-group.yml
    
  publish-observability: # Layer 3: Sequential after data (18 min)
    needs: [publish-data]
    if: inputs.groups == 'all' || inputs.groups == 'observability'
    uses: ./.github/workflows/_reusable-publish-group.yml
    
  publish-communication: # Layer 2b: Parallel with data (9 min)
    needs: [publish-gateway]
    if: inputs.groups == 'all' || inputs.groups == 'communication'
    uses: ./.github/workflows/_reusable-publish-group.yml
    
  publish-tools:         # Layer 2c: Parallel with data (15 min)
    needs: [publish-gateway]
    if: inputs.groups == 'all' || inputs.groups == 'tools'
    uses: ./.github/workflows/_reusable-publish-group.yml
    
  publish-summary:       # Aggregation
    needs: [publish-gateway, publish-data, publish-observability, publish-communication, publish-tools]
    if: always()
    # Generate summary table
```

**Execution Flow:**
- Gateway → Data → Observability (sequential)
- Gateway → Communication (parallel)
- Gateway → Tools (parallel)
- Total: 30-35 minutes

**Success Criteria:**
- Zero GHCR rate limit errors
- All 25 images published successfully
- Selective publishing works (can trigger individual groups)

**Timeline:** Week 4 (3 days)  
**Dependencies:** Phase 2 (reusable-publish-group workflow)  
**Validation:** Trigger with groups=gateway, verify only 4 images published

---

## Phase 6: Orchestration Layer - Release & Scheduled

**Objective:** Production release pipeline and maintenance tasks.

**Deliverables:**

### 6.1 Release Workflow
**File:** `.github/workflows/release.yml`

**Triggers:**
```yaml
on:
  push:
    tags:
      - 'v*.*.*'  # Semantic version tags
```

**Jobs:**
1. **build-and-push** - Build with immutable semver tags
2. **deploy-to-staging** - Blue/green deployment
3. **smoke-tests** - Health checks, API tests
4. **manual-approval** - Wait for ops team approval
5. **deploy-to-production** - Gradual rollout with monitoring
6. **create-release** - GitHub Release with changelog

**Success Criteria:**
- Immutable tagging (v1.0.0, never latest)
- Manual approval gate working
- Rollback capability tested

---

### 6.2 Scheduled Maintenance Workflow
**File:** `.github/workflows/scheduled-maintenance.yml`

**Triggers:**
```yaml
on:
  schedule:
    - cron: '0 6 * * *'   # Daily 6 AM UTC - Security scans
    - cron: '0 6 * * 0'   # Weekly Sunday - Base image rebuilds
```

**Jobs:**
1. **security-scan-all** (daily) - Full platform CVE audit
2. **rebuild-base-images** (weekly) - Fresh builds with security patches
3. **dependency-audit** (weekly) - Check for outdated packages
4. **generate-reports** - SBOM, CVE trends, cost metrics

**Success Criteria:**
- Security reports generated daily
- Base images rebuilt weekly
- GitHub Issues created for new CVEs

**Timeline:** Week 4 (2 days)  
**Dependencies:** Phase 4 (main-deploy workflow)  
**Validation:** Manually trigger workflows, verify execution

---

## Phase 7: Enhancements & Optimizations

**Objective:** Add advanced features (SBOM, signing, metrics).

**Deliverables:**

### 7.1 SBOM Generation
- Enable in all Docker builds via BuildKit
- Store as workflow artifacts
- Scan for license compliance

### 7.2 Image Signing (Cosign)
- Sign production images with Cosign
- Keyless signing via GitHub OIDC
- Verify signatures before deployment

### 7.3 Metrics & Dashboards
- Export build times, image sizes, CVE counts
- Track cost per service build
- CI/CD minutes usage dashboard

### 7.4 Enhanced Caching
- Optimize cache keys
- Add cache cleanup for old entries
- Monitor cache hit rates

**Timeline:** Week 5 (5 days)  
**Dependencies:** Phase 6 (all orchestration complete)  
**Validation:** Verify SBOM attached, images signed, metrics tracked

---

## Phase 8: Migration & Cleanup

**Objective:** Deprecate old workflows, update documentation, train team.

**Deliverables:**

### 8.1 Workflow Migration
1. Move old workflows to DEPRECATED/ folder
2. Add deprecation warnings in old files
3. Update all documentation links
4. Update runbooks and operator guides

### 8.2 Documentation Updates
1. Update README.md with new workflow structure
2. Create CI/CD developer guide
3. Document troubleshooting procedures
4. Create architecture diagrams

### 8.3 Team Training
1. Demo new workflows to team
2. Create video walkthrough
3. Update onboarding documentation
4. Conduct Q&A session

### 8.4 Validation & Cleanup
1. Run full test suite
2. Verify all scenarios (PR, merge, release, scheduled)
3. Check metrics (speed, cache hit rate, cost)
4. Delete deprecated workflows after 30-day grace period

**Timeline:** Week 5 (concurrent with Phase 7)  
**Dependencies:** Phase 6 complete  
**Validation:** Team successfully uses new workflows

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 0: Research (COMPLETE)
  ↓
Phase 1: Composite Actions (Week 1)
  ↓
Phase 2: Reusable Workflows (Week 2)
  ↓
Phase 3: PR Checks (Week 3, first half)
  ↓
Phase 4: Main Deploy (Week 3, second half)
  ↓
Phase 5: Publish Orchestrator (Week 4, first half)
  ↓
Phase 6: Release & Scheduled (Week 4, second half)
  ↓
Phase 7: Enhancements (Week 5) ← Parallel with Phase 8
Phase 8: Migration & Cleanup (Week 5)
```

### Parallel Execution Opportunities

**Week 1 (Phase 1):**
- All 5 composite actions can be created in parallel
- Different team members can own different actions

**Week 2 (Phase 2):**
- All 5 reusable workflows can be created in parallel
- Assign one workflow per team member

**Week 3:**
- PR Checks (days 1-3) must complete before Main Deploy (days 4-5)
- Testing can happen in parallel with development

**Week 4:**
- Publish Orchestrator (days 1-3) independent of Release (days 4-5)
- Can work on both streams simultaneously

**Week 5:**
- Enhancements (SBOM, signing) parallel with Migration
- Documentation parallel with cleanup

---

## Testing Strategy

### Per-Phase Testing

**Phase 1 (Composite Actions):**
- Create minimal test workflow for each action
- Verify inputs, outputs, caching behavior
- Test on Ubuntu, macOS (if applicable)

**Phase 2 (Reusable Workflows):**
- Call each via workflow_dispatch with test inputs
- Verify outputs match expectations
- Test failure scenarios

**Phase 3 (PR Checks):**
- Create test PR with code changes
- Measure execution time
- Verify cache hit rate
- Test concurrency (push multiple commits)

**Phase 4 (Main Deploy):**
- Merge test PR to main
- Verify auto-deploy to dev
- Verify SBOM generation
- Test rollback scenario

**Phase 5 (Publish Orchestrator):**
- Trigger with groups=gateway (selective)
- Trigger with groups=all (full publish)
- Simulate rate limit scenario
- Verify partial failure handling

**Phase 6 (Release):**
- Create test tag (v0.0.1-test)
- Verify staging deployment
- Test manual approval flow
- Verify rollback works

**Phase 7 (Enhancements):**
- Verify SBOM attached to artifacts
- Verify Cosign signature valid
- Verify metrics exported correctly

**Phase 8 (Migration):**
- Verify old workflows deprecated
- Verify documentation updated
- Verify team can use new workflows

### Integration Testing

**End-to-End Scenarios:**
1. New developer creates PR → PR checks pass → Merge → Auto-deploy
2. Tag release → Build → Staging → Manual approval → Production
3. Scheduled security scan → CVE detected → GitHub Issue created
4. Publish vendor images → All 25 images → Zero rate limit errors

---

## Rollback Plan

### Per-Phase Rollback

**Phase 1-2 (Actions/Reusable):**
- No rollback needed (additive changes)
- Old workflows still functional

**Phase 3-4 (PR Checks, Main Deploy):**
- Rollback: Disable new workflow, enable old validation workflows
- Data impact: None (no published images yet)

**Phase 5 (Publish Orchestrator):**
- Rollback: Re-enable old publish-* workflows from DEPRECATED/
- Data impact: None (can republish images if needed)

**Phase 6 (Release):**
- Rollback: Manual release process via old docker-publish workflow
- Data impact: None (tags are immutable)

**Emergency Rollback Procedure:**
1. Disable new workflow (via GitHub UI or commit)
2. Re-enable old workflow from DEPRECATED/
3. Verify old workflow still functional
4. Investigate issue, fix, re-enable new workflow

---

## Success Metrics

### Phase 1 Success Criteria
- ✅ 5 composite actions created
- ✅ All actions tested in isolation
- ✅ Documentation complete (README.md per action)

### Phase 2 Success Criteria
- ✅ 5 reusable workflows created
- ✅ All workflows callable via workflow_dispatch
- ✅ Input/output contracts validated

### Phase 3 Success Criteria
- ✅ PR checks complete in <3 minutes (85th percentile)
- ✅ Cache hit rate >85%
- ✅ Single "PR Checks" status visible

### Phase 4 Success Criteria
- ✅ Auto-deploy to dev on merge
- ✅ SBOM generated for all images
- ✅ Deploy duration <10 minutes

### Phase 5 Success Criteria
- ✅ All 25 vendor images published
- ✅ Zero GHCR rate limit errors
- ✅ Execution time 30-35 minutes
- ✅ Selective publishing works

### Phase 6 Success Criteria
- ✅ Release workflow tested end-to-end
- ✅ Manual approval gate functional
- ✅ Scheduled scans running daily

### Phase 7 Success Criteria
- ✅ SBOM coverage 100%
- ✅ Production images signed
- ✅ Metrics dashboard operational

### Phase 8 Success Criteria
- ✅ Old workflows deprecated
- ✅ Documentation complete
- ✅ Team trained on new workflows

### Overall Success Criteria
- ✅ 58% reduction in workflow files (12 → 5 core)
- ✅ 60% faster PR validation (8 min → 3 min)
- ✅ 28% reduction in CI/CD minutes
- ✅ 85%+ cache hit rate
- ✅ 100% SBOM coverage
- ✅ Zero manual publish operations
- ✅ Zero GHCR rate limit errors

---

## Risk Mitigation

### Risk 1: GHCR Rate Limiting
**Mitigation:** Controlled parallelism via job dependencies, 30s delays, retry logic  
**Validation:** Stress test with 25 concurrent images

### Risk 2: Cache Misses (Slow Builds)
**Mitigation:** 3-tier caching, cache key optimization, monitor hit rates  
**Validation:** Track cache hit rate, alert if <80%

### Risk 3: GitHub Actions Outage
**Mitigation:** Document manual fallback process, allow skip-ci label  
**Validation:** Test manual validation locally

### Risk 4: Breaking Changes to Services
**Mitigation:** Gradual rollout, keep old workflows for 30 days  
**Validation:** Canary test with one service first

### Risk 5: Team Adoption
**Mitigation:** Training, documentation, Q&A sessions  
**Validation:** Survey team, collect feedback

---

## Timeline Summary

| Phase | Duration | Team Size | Deliverables |
|-------|----------|-----------|--------------|
| Phase 0: Research | 1 week | 1 person | ✅ COMPLETE |
| Phase 1: Composite Actions | 1 week | 2-3 people | 5 actions |
| Phase 2: Reusable Workflows | 1 week | 2-3 people | 5 workflows |
| Phase 3: PR Checks | 0.5 week | 2 people | 1 orchestrator |
| Phase 4: Main Deploy | 0.5 week | 2 people | 1 orchestrator |
| Phase 5: Publish Orchestrator | 0.5 week | 2 people | 1 orchestrator + 5 configs |
| Phase 6: Release & Scheduled | 0.5 week | 2 people | 2 orchestrators |
| Phase 7: Enhancements | 1 week | 2 people | SBOM, signing, metrics |
| Phase 8: Migration & Cleanup | 1 week | 2-3 people | Docs, training, cleanup |

**Total Duration:** 6 weeks  
**Team Size:** 2-3 developers  
**MVP (Phases 1-4):** 3 weeks  
**Full Feature:** 6 weeks

---

## Next Steps

1. **Review Plan:** Team reviews this plan, provides feedback
2. **Create Tasks:** Generate detailed task breakdown (tasks.md)
3. **Assign Ownership:** Assign phases to team members
4. **Start Phase 1:** Begin composite actions development
5. **Daily Standups:** Track progress, blockers, risks

**Ready to proceed to task generation!**

