# Feature Specification: A.R.C. Framework Stabilization & Docker Excellence

**Feature Branch**: `002-stabilize-framework`  
**Created**: January 10, 2026  
**Status**: Draft  
**Input**: User description: "Stabilize and improve Docker image and service management across the A.R.C. platform"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Infrastructure Developer Onboards Successfully (Priority: P1)

A new developer joins the A.R.C. team and needs to understand the project structure, locate services, and identify where to add new components. They should be able to navigate the codebase intuitively without extensive documentation reading or mentor hand-holding.

**Why this priority**: Developer productivity and onboarding speed directly impacts feature velocity. A confusing structure multiplies debugging time and creates technical debt through misplaced code.

**Independent Test**: New developer can locate the Dockerfile for any service listed in SERVICE.MD within 2 minutes, and correctly identify whether a new service should go in `core/`, `plugins/`, or `services/` without asking the team.

**Acceptance Scenarios**:

1. **Given** a new developer joins the team, **When** they review the repository structure, **Then** they can identify the purpose of each top-level directory within 5 minutes
2. **Given** SERVICE.MD lists `arc-sherlock-brain`, **When** developer searches for its implementation, **Then** they find it in the expected location matching the service registry naming convention
3. **Given** developer needs to add a new worker service, **When** they review the directory structure documentation, **Then** they know the correct location and Dockerfile template to use

---

### User Story 2 - Platform Operator Maintains Secure Container Images (Priority: P1)

A platform operator or DevSecOps engineer needs to audit all Docker images for security vulnerabilities, outdated base images, and compliance with security hardening standards. They should be able to quickly identify and remediate issues across all services.

**Why this priority**: Security vulnerabilities in base images are critical infrastructure risks. Inconsistent Dockerfile patterns make security patches expensive and error-prone. This directly impacts production system integrity.

**Independent Test**: Security scanner can process all Dockerfiles and generate a compliance report showing base image versions, CVE counts, and security best practice violations in under 5 minutes. Any discovered issue can be fixed by updating a shared base image rather than patching 20+ individual files.

**Acceptance Scenarios**:

1. **Given** a CVE is discovered in Alpine 3.18, **When** security team audits the platform, **Then** they can identify all affected services and their base images within 2 minutes
2. **Given** Dockerfile security standards are documented, **When** developer creates a new service, **Then** the Dockerfile automatically inherits security hardening (non-root user, minimal layers, signed images)
3. **Given** a new base image version is released, **When** platform team updates shared base images, **Then** dependent services rebuild with the new version without individual Dockerfile edits

---

### User Story 3 - DevOps Engineer Understands Image Relationships (Priority: P1)

A DevOps engineer needs to understand the dependency graph of Docker images - which services share base images, which are published to GHCR, and how changes propagate through the build pipeline.

**Why this priority**: Build pipeline efficiency and change impact analysis depend on understanding image relationships. Without this, developers waste time rebuilding unchanged images or skip necessary rebuilds causing runtime errors.

**Independent Test**: Engineer can generate a visual dependency graph showing base images, service images, and GHCR publication targets in under 3 minutes. They can answer "if I change X, what needs rebuilding?" without running the build.

**Acceptance Scenarios**:

1. **Given** base image `arc-base-python-ai` is modified, **When** engineer reviews dependencies, **Then** they identify all affected services (arc-sherlock-brain, arc-scarlett-voice, etc.)
2. **Given** a service has a Dockerfile, **When** engineer checks build configuration, **Then** they can determine if it publishes to GHCR and what the image name will be
3. **Given** multiple services share infrastructure code, **When** engineer reviews the structure, **Then** they understand which images are bases vs. final services vs. sidecars

---

### User Story 4 - Developer Builds Services Efficiently (Priority: P2)

A developer working on a specific service needs fast build times through effective layer caching, minimal image sizes for quick pulls, and clear build error messages when something goes wrong.

**Why this priority**: Developer experience directly impacts iteration speed. Poor caching means 10-minute builds instead of 30-second incremental builds. Large images mean slow deployments and wasted CI/CD time.

**Independent Test**: Developer can modify application code (not dependencies) and rebuild a service in under 60 seconds. Image sizes are within 20% of minimal possible size for their language runtime. Build failures point to the specific problematic line with context.

**Acceptance Scenarios**:

1. **Given** developer modifies Python application code, **When** they rebuild the Docker image, **Then** Docker reuses cached dependency layers and rebuild completes in under 60 seconds
2. **Given** a production service image, **When** developer inspects the image size, **Then** it contains only runtime dependencies (no build tools, package managers, or dev dependencies)
3. **Given** a Dockerfile fails to build, **When** developer reads the error, **Then** they understand which instruction failed and why (e.g., "RUN pip install failed: package X not found in requirements.txt line 23")

---

### User Story 5 - Documentation Stays Synchronized with Code (Priority: P2)

A developer or technical writer needs to maintain documentation that accurately reflects the current directory structure, service locations, and Dockerfile standards without manual synchronization effort.

**Why this priority**: Outdated documentation is worse than no documentation - it actively misleads developers. Keeping docs synchronized manually is error-prone and frequently skipped under deadline pressure.

**Independent Test**: Automated validation runs in CI/CD that verifies all services in SERVICE.MD have corresponding directories, all documented paths exist, and Dockerfile standards match the documented patterns. Any drift triggers a build failure with actionable fix instructions.

**Acceptance Scenarios**:

1. **Given** SERVICE.MD documents `arc-sherlock-brain` at `services/arc-sherlock-brain`, **When** CI runs documentation validation, **Then** it confirms the directory exists with a valid Dockerfile
2. **Given** directory structure documentation describes organization principles, **When** a new top-level directory is added, **Then** CI flags it as undocumented and requires documentation update
3. **Given** Dockerfile standards document requires non-root users, **When** developer commits a Dockerfile with USER root, **Then** linting catches the violation before merge

---

### User Story 6 - Platform Architect Plans Future Services (Priority: P3)

A platform architect needs to plan where new services should live, understand capacity for growth, and ensure the directory structure scales to 100+ services without becoming unwieldy.

**Why this priority**: Proactive architectural planning prevents costly refactoring. While not immediately critical, a structure that doesn't scale becomes a bottleneck within 6-12 months.

**Independent Test**: Architect can add 3 new service categories (e.g., "analytics", "compliance", "ml-training") to the structure without restructuring existing services. Documentation clearly explains categorization principles that apply to future services.

**Acceptance Scenarios**:

1. **Given** architect needs to add an "analytics" service category, **When** they review the structure documentation, **Then** they understand whether it belongs in plugins/, services/, or a new top-level directory
2. **Given** the platform grows to 50+ services, **When** developer navigates the repository, **Then** services remain organized into logical groupings (max 15 services per directory)
3. **Given** A.R.C. framework needs to support multi-tenancy in future, **When** architect reviews current structure, **Then** they can identify how to add tenant-specific service variants without duplication

---

### Edge Cases

- What happens when a service needs multiple Dockerfiles for different deployment targets (e.g., GPU vs. CPU builds for ML services)?
- How does the system handle Dockerfiles that must reference files outside their immediate directory (e.g., shared proto definitions, common libraries)?
- What happens when a service is deprecated but must remain in the repository for historical reference?
- How does the system differentiate between development, staging, and production Dockerfile configurations?
- What happens when documentation references become stale after a directory reorganization?
- How are multi-stage builds organized when intermediate stages are shared across services?
- What happens when a service uses a proprietary base image that cannot be published to GHCR?
- How does the structure handle sidecar containers that deploy alongside but separately from main services?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a documented directory structure that clearly separates infrastructure (`core/`), optional components (`plugins/`), application logic (`services/`), deployment configurations (`deployments/`), and documentation (`docs/`)
- **FR-002**: System MUST enforce that all services listed in SERVICE.MD have corresponding directories with predictable naming (e.g., `arc-sherlock-brain` maps to `services/arc-sherlock-brain/`)
- **FR-003**: System MUST establish base Docker images for each language stack (Go for infra/CLI, Python for AI/agents, React for frontends) that enforce security hardening and best practices
- **FR-004**: All production Dockerfiles MUST implement multi-stage builds that separate build-time dependencies from runtime dependencies
- **FR-005**: All production Docker images MUST run as non-root users with explicitly defined USER instructions
- **FR-006**: All production Dockerfiles MUST specify exact base image versions (no `latest` tags) for reproducibility
- **FR-007**: System MUST provide linting tools that validate Dockerfiles against security standards (gosec for Go, bandit for Python, npm audit for Node.js)
- **FR-008**: System MUST document which services publish to GHCR and their exact image naming convention (`ghcr.io/arc/[codename]:[version]`)
- **FR-009**: System MUST provide templates for new service creation that include standard Dockerfile patterns for each language
- **FR-010**: System MUST audit all existing Dockerfiles and document security issues, anti-patterns, and technical debt in a migration plan
- **FR-011**: System MUST establish naming conventions for Docker images that align with A.R.C. service registry codenames (Heimdall, Sherlock, Scarlett, etc.)
- **FR-012**: System MUST organize shared libraries and common code in `libs/` with clear boundaries to prevent circular dependencies
- **FR-013**: System MUST separate deployment configurations (docker-compose, Kubernetes manifests, Terraform) from service code in `deployments/`
- **FR-014**: System MUST provide automated validation that verifies directory structure consistency (services match SERVICE.MD, Dockerfiles exist, etc.)
- **FR-015**: All Dockerfile changes MUST include audit logs explaining why the change was necessary (security fix, dependency update, performance optimization)
- **FR-016**: System MUST establish layer caching strategies that optimize for fast incremental builds (dependencies before application code)
- **FR-017**: System MUST define image size targets for each service category (infrastructure: <100MB, Python services: <500MB, Go services: <50MB)
- **FR-018**: System MUST provide migration scripts that help move services from old structure to new structure without breaking existing deployments
- **FR-019**: System MUST document the relationship between service types (INFRA, CORE, WORKER, SIDECAR) and their directory locations
- **FR-020**: System MUST establish guidelines for when to create a new top-level directory vs. adding to existing categories

### Key Entities *(include if feature involves data)*

- **Service**: A containerized component with a codename, image name, type (INFRA/CORE/WORKER/SIDECAR), source location, and Dockerfile
- **Base Image**: A foundational Docker image shared by multiple services (e.g., `arc-base-python-ai` used by Sherlock and Scarlett)
- **Directory Category**: Top-level organizational unit (core/, plugins/, services/, deployments/, etc.) with defined purpose and inclusion criteria
- **Docker Layer**: An image layer with caching implications, ordering requirements, and size constraints
- **Security Standard**: A documented best practice enforced across all Dockerfiles (e.g., "no root user", "pinned versions", "minimal attack surface")
- **Build Artifact**: The resulting Docker image published to GHCR with version tag, size, security scan results, and dependency manifest

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: New developers can locate any service's Dockerfile within 2 minutes by following documented structure conventions
- **SC-002**: Security audits complete in under 5 minutes, identifying all services using outdated base images or violating security standards
- **SC-003**: Incremental builds (code changes without dependency changes) complete in under 60 seconds for any service
- **SC-004**: Production Docker images meet size targets: Go services <50MB, Python services <500MB, infrastructure <100MB
- **SC-005**: 100% of production Dockerfiles use multi-stage builds, non-root users, and pinned base image versions
- **SC-006**: CI/CD pipeline includes automated validation that prevents merging code with documentation drift (SERVICE.MD vs actual directories)
- **SC-007**: Dependency graph generation (which services share which base images) completes in under 3 minutes
- **SC-008**: Zero security vulnerabilities rated HIGH or CRITICAL in base images after audit and remediation
- **SC-009**: Migration from old structure to new structure completes without service downtime or deployment failures
- **SC-010**: Documentation synchronization validation runs on every commit and fails build if paths, service names, or standards are inconsistent
- **SC-011**: Developer satisfaction survey shows 80%+ agreement that "I can find what I need quickly" after restructuring
- **SC-012**: Build cache hit rate improves to 85%+ for incremental builds (measuring Docker layer reuse)

## Out of Scope *(optional)*

The following items are explicitly excluded from this feature to maintain focus:

- **Runtime Performance Optimization**: This feature focuses on build-time and development experience, not runtime performance tuning of services
- **Kubernetes Migration**: While we organize `deployments/kubernetes/`, actual K8s deployment automation is a separate feature
- **CI/CD Pipeline Overhaul**: We'll add validation steps but won't rebuild the entire CI/CD infrastructure
- **Service Code Refactoring**: We reorganize directories but don't refactor application logic inside services
- **Observability Stack Changes**: Prometheus/Grafana/Loki configurations are adjusted for new paths but not redesigned
- **Live Production Migration**: Initial rollout targets development and staging environments; production cutover is a separate change management process
- **Programming Language Version Updates**: We standardize on current language versions but don't upgrade Python 3.11→3.12 or Go 1.21→1.22
- **Legacy Service Deprecation**: We document deprecated services but don't remove them (requires separate business decision)

## Assumptions *(optional)*

This specification assumes the following to be true:

- **Assumption 1**: All services can tolerate directory reorganization without code changes (imports and paths are relative or configurable)
- **Assumption 2**: GHCR (GitHub Container Registry) remains the container registry of choice (no migration to AWS ECR or other registries)
- **Assumption 3**: Docker Compose remains the primary local development environment (not Podman, not native Kubernetes)
- **Assumption 4**: The A.R.C. service registry (SERVICE.MD) is the source of truth for service naming and codenames
- **Assumption 5**: Security hardening standards can be enforced without breaking backward compatibility with existing service functionality
- **Assumption 6**: Development team has bandwidth to update build scripts and local environments after directory restructuring
- **Assumption 7**: Multi-stage builds are acceptable for all service types (no requirement for single-stage builds)
- **Assumption 8**: The polyglot nature of the platform (Go/Python/React) requires language-specific base images rather than a universal base
- **Assumption 9**: Image size targets are more important than absolute minimal size (trade convenience for moderate size reduction)
- **Assumption 10**: Documentation will be maintained in Markdown format in the `docs/` directory alongside code
- **Assumption 11**: Automated validation tools can run in CI/CD without significantly increasing build times
- **Assumption 12**: The current three-tier structure (core/plugins/services) adequately represents the architectural layers and doesn't need additional tiers

## Dependencies *(optional)*

This feature depends on or impacts the following:

- **SERVICE.MD Registry**: Source of truth for service names, codenames, and categorization - any restructuring must update this document
- **Existing Deployment Scripts**: Scripts in `scripts/` that reference hardcoded paths will need updating
- **Docker Compose Files**: All compose files in `deployments/docker/` reference service paths and must be updated
- **GitHub Actions Workflows**: CI/CD pipelines in `.github/workflows/` contain build paths that must match new structure
- **Developer Documentation**: `docs/guides/` and README files throughout the repository reference directory structure
- **GHCR Publishing Workflow**: GitHub Actions that push images to GHCR must use consistent naming conventions
- **Base Image Builds**: Establishing shared base images requires creating new Dockerfile definitions and build ordering
- **SpecKit Integration**: Moving directories requires updating `.specify/` metadata to reflect new paths
- **Makefile Targets**: The root Makefile has targets that reference service directories and must be synchronized
- **Environment Variables**: `.env` and `.env.example` contain paths that may need adjustment
- **IDE Configurations**: `.vscode/` and `.idea/` may contain path configurations that need updating for developer experience
- **Security Scanning Tools**: Existing security scanners (if any) must be reconfigured to scan new Dockerfile locations

## Risks *(optional)*

Potential risks and mitigation strategies:

- **Risk 1 - Breaking Existing Deployments**: Directory reorganization could break production deployments if not carefully migrated
  - *Mitigation*: Implement changes in feature branch, test thoroughly in staging, use symlinks during transition period if needed
  
- **Risk 2 - Developer Workflow Disruption**: Team members have muscle memory for current structure; changes cause temporary productivity loss
  - *Mitigation*: Communicate changes early, provide migration guide, maintain both old and new structure documentation during transition
  
- **Risk 3 - Documentation Drift**: After restructuring, documentation quickly becomes outdated as team adds new services
  - *Mitigation*: Implement automated validation in CI/CD that prevents merging undocumented changes
  
- **Risk 4 - Over-Engineering Base Images**: Creating too many shared base images increases build complexity and maintenance burden
  - *Mitigation*: Start with 3 base images (Go/Python/Node), only add more if 3+ services share identical dependencies
  
- **Risk 5 - Security Hardening Breaks Functionality**: Enforcing non-root users or minimal images could break services with specific requirements
  - *Mitigation*: Audit each service's requirements before applying blanket rules, document exceptions with justification
  
- **Risk 6 - Image Size Optimization Slows Builds**: Aggressive optimization techniques (multi-stage builds, minimal base images) could increase build times
  - *Mitigation*: Measure build times before and after, prioritize cache efficiency over absolute minimal size
  
- **Risk 7 - Inconsistent Adoption**: Without enforcement, developers might continue using old patterns
  - *Mitigation*: Add linting and validation that fails builds for non-compliant Dockerfiles
  
- **Risk 8 - Lost Tribal Knowledge**: Reorganizing may lose context about why services were structured a certain way
  - *Mitigation*: Document rationale in Architecture Decision Records (ADRs) before making changes

## Constraints *(optional)*

The following constraints apply to this feature:

- **No Service Downtime**: Production services must remain available during restructuring; changes deploy during maintenance windows only
- **Backward Compatibility**: Old image names in GHCR must remain available via tags/aliases until all deployments migrate (minimum 3 months)
- **Platform Polyglot Nature**: Must support Go, Python, and React/Node.js with language-specific optimizations (cannot use single universal Dockerfile)
- **GHCR Storage Limits**: GitHub Container Registry has storage quotas; image sizes directly impact costs and quotas
- **CI/CD Time Budget**: Total CI/CD pipeline time must remain under 15 minutes; validation steps cannot add more than 2 minutes
- **Team Familiarity**: Structure must be intuitive for developers familiar with standard open-source project layouts (inspired by Kubernetes, Istio, etc.)
- **Marvel/Hollywood Naming Convention**: Service codenames must remain consistent with A.R.C.'s established naming scheme (cannot rename Sherlock to "BrainService")
- **Minimal External Dependencies**: Base images should use Alpine or Debian slim variants; avoid large base images like Ubuntu or Fedora
- **Security Compliance**: Must pass security scans (Trivy, Grype) with zero HIGH/CRITICAL vulnerabilities before merging
- **Git Repository Size**: Reorganization must not significantly increase repository size (avoid duplicating large files during migration)
- **Developer Environment**: Changes must work on macOS, Linux, and Windows (WSL2) without platform-specific workarounds

## Acceptance Criteria Summary *(mandatory)*

This feature is complete and ready for production when:

1. **Structure Documentation**: A comprehensive guide exists in `docs/architecture/directory-structure.md` explaining the purpose of each top-level directory, inclusion criteria, and examples
2. **Service Alignment**: All services in SERVICE.MD have corresponding directories in the correct locations (core/plugins/services) with no orphaned or misplaced services
3. **Dockerfile Standards Document**: `docs/guides/dockerfile-standards.md` defines and enforces security requirements, multi-stage build patterns, and language-specific best practices
4. **Base Images Established**: At minimum, three base images exist (`arc-base-go`, `arc-base-python-ai`, `arc-base-node-frontend`) and are used by relevant services
5. **Security Audit Complete**: All existing Dockerfiles audited, issues documented, and remediation plan created with prioritized fixes
6. **Automated Validation**: CI/CD pipeline includes checks that verify structure consistency (SERVICE.MD matches directories, Dockerfiles pass linting, documentation is synchronized)
7. **Migration Guide**: Step-by-step guide exists for developers to update their local environments, update git remotes, and rebuild images
8. **Zero Breaking Changes**: All services build successfully, pass tests, and deploy to staging environment without errors
9. **Performance Targets Met**: Build times, image sizes, and cache hit rates meet or exceed success criteria benchmarks
10. **Team Approval**: Platform architect and at least two senior engineers review and approve the new structure before merging to main branch

---

**Next Steps After Approval**:
- Run `/speckit.plan` to break this specification into implementable tasks
- Create Architecture Decision Records (ADRs) documenting key structural decisions
- Set up feature flag to gradually enable new structure validation in CI/CD
- Schedule team demo and Q&A session for the proposed changes

