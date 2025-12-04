# A.R.C. Platform Spike - Concerns & Action Plan

**Created:** December 01, 2025  
**Status:** Ready for Implementation  
**Total Issues:** 8 | **Critical:** 2 | **High:** 3 | **Medium:** 3

## CONCERNS INVENTORY

### 🔴 CRITICAL CONCERNS (Blocking Production)

#### C1. Traefik Control Plane Exposed Without Auth

- **Category:** Security
- **Current State:** `core/gateway/traefik/traefik.yml` sets `api.insecure: true` and `deployments/docker/docker-compose.core.yml` exposes `8080:8080`, granting anonymous access to the Traefik dashboard and API.
- **Impact:** Attackers can re-route traffic, issue certificates, or disable services remotely; immediate production blocker.
- **Evidence:**
  ```yaml
  # core/gateway/traefik/traefik.yml
  api:
    dashboard: true
    insecure: true
  ```
- **Solution Approach:** Disable `api.insecure`, remove direct port mapping, and expose the dashboard only through an authenticated Traefik router with mTLS or basic auth backed by secrets. Pin Traefik image version while updating config.
- **Acceptance Criteria:** Dashboard/API accessible only behind authenticated route; port 8080 no longer published; security scan confirms no unauthenticated access paths.

#### C2. Pulsar Starts With `--wipe-data`

- **Category:** Operations / Reliability
- **Current State:** `arc_pulsar` command (`deployments/docker/docker-compose.core.yml`) includes `--wipe-data`, forcing broker to erase state on each restart despite mounted volume.
- **Impact:** Guaranteed data loss for durable topics after restart; violates durability promise and blocks production usage.
- **Evidence:**
  ```yaml
  arc_pulsar:
    command: >
      bin/pulsar standalone
      --no-functions-worker
      --wipe-data
  ```
- **Solution Approach:** Remove `--wipe-data`, add explicit retention configs, document upgrade/reset procedure, and verify persistence across restarts. Complement with backup plan.
- **Acceptance Criteria:** Topics persist across container restarts; documented migration/reset process; integration test validates message replay after restart.

### 🟡 HIGH-PRIORITY CONCERNS

#### H1. Default Basic-Auth Hashes Ship With Production Overlay

- **Category:** Security
- **Current State:** `deployments/docker/docker-compose.production.yml` sets `PROMETHEUS_AUTH`, `JAEGER_AUTH`, `ADMIN_AUTH` defaults to known htpasswd values (admin:admin style).
- **Impact:** If operators forget to override, attackers can authenticate with published credentials and access sensitive dashboards.
- **Evidence:**
  ```yaml
  - 'traefik.http.middlewares.prometheus-auth.basicauth.users=${PROMETHEUS_AUTH:-admin:$$apr1$$H6uskkkW$$IgXLP6ewTrSuBkTrqE8wj/}'
  ```
- **Solution Approach:** Remove default hashes, require secrets via `${VAR:?Missing}` guard, and document secret generation (e.g., `openssl`). Optionally source from Infisical.
- **Acceptance Criteria:** Compose fails to start unless custom credentials provided; documentation updated; smoke test verifies middleware blocks anonymous access.

#### H2. TLS Automation Missing

- **Category:** Security / Compliance
- **Current State:** Production overlay references `DOMAIN` but lacks ACME/certificate configuration; `core/gateway/traefik/traefik.yml` defines only web/websecure entrypoints without certificate resolver.
- **Impact:** Stack can only serve plain HTTP or requires manual certificate provisioning; violates transport security requirements.
- **Solution Approach:** Configure Traefik ACME (Let's Encrypt) or integrate externally managed certs, store secrets securely, enforce HTTPS redirects, and document renewal monitoring.
- **Acceptance Criteria:** Automated certificate issuance active; HTTP requests redirect to HTTPS; renewal logs monitored; compliance checklist updated.

#### H3. No Automated Backup & Restore Workflow

- **Category:** Operations / DR
- **Current State:** `Makefile` offers `make backup-db` for Postgres only; no routine backups for Infisical secrets, Pulsar data, or Redis persistence. Operations guide notes plan but scripts are still "Planned" (`scripts/operations/README.md`).
- **Impact:** High risk of irreversible data/secrets loss after incidents; fails enterprise DR expectations.
- **Solution Approach:** Implement scheduled backups (cron/CI) for Postgres, Infisical, Pulsar bookies; store artifacts securely; provide tested restore scripts and runbook.
- **Acceptance Criteria:** Automated job artifacts present; documented restore drill executed and logged; RPO/RTO targets defined and met.

### 🟢 MEDIUM-PRIORITY CONCERNS

#### M1. Unpinned Critical Images

- **Category:** Configuration / Security
- **Current State:** Core services still rely on floating tags (`traefik:latest`, `infisical/infisical:latest-postgres`, custom images tagged `:latest`).
- **Impact:** Supply-chain drift and reproducibility risk; complicates incident rollbacks.
- **Solution Approach:** Pin to explicit versions, publish internal tags for custom images (e.g., `${VERSION}`), expose versions via `.env` overrides.
- **Acceptance Criteria:** Compose configs reference immutable tags; changelog documents version bumps; vulnerability scan reports deterministic.

#### M2. Documentation Drift In Operations Guide

- **Category:** Developer Experience
- **Current State:** `docs/OPERATIONS.md` still references `.env.dev` / `.env.staging` manual copying rather than new `make generate-secrets` + `ENV_FILE` workflow; could mislead operators.
- **Impact:** Onboarding friction; potential misconfiguration if old steps followed.
- **Solution Approach:** Update guide to mirror current automation, add warnings about deprecated per-service `.env` files.
- **Acceptance Criteria:** Ops guide reflects latest workflow, reviewed by platform team, and linked from README changelog.

#### M3. Absence of CI/CD Security Gates

- **Category:** Security / Quality
- **Current State:** Repository lacks pipelines for `make validate`, vulnerability scanning, or image scanning (no `.github/workflows/` or similar).
- **Impact:** Regressions (e.g., Traefik insecure flag) slip into main; no automated guardrails for dependencies.
- **Solution Approach:** Add CI workflow running lint/validate + Trivy/Grype scans and Compose smoke tests; enforce branch protection.
- **Acceptance Criteria:** CI pipeline passes on main; failing checks block merges; security scan reports stored.

## SOLUTION PLAN

### PHASE 1: CRITICAL FIXES

1. Patch Traefik configuration
   - Files: `core/gateway/traefik/traefik.yml`, `deployments/docker/docker-compose.core.yml`
   - Deliverables: authenticated dashboard route, pinned image, removal of port 8080 mapping
   - Acceptance: `curl http://localhost:8080` denied; authenticated route accessible via Traefik only
2. Stabilize Pulsar persistence
   - Files: `deployments/docker/docker-compose.core.yml`, docs/runbooks
   - Deliverables: new command without wipe, smoke test ensuring message survival across restart
   - Acceptance: test script publishes, restarts, and consumes messages successfully

### PHASE 2: HIGH-PRIORITY FIXES

1. Enforce custom admin credentials in production overlay
   - Files: `deployments/docker/docker-compose.production.yml`, `.env.example`
   - Deliverables: `${VAR:?Missing}` guards, documentation for generating htpasswd
   - Acceptance: Compose start fails if credentials absent; docs updated
2. Implement TLS automation
   - Files: `core/gateway/traefik/traefik.yml`, `deployments/docker/docker-compose.production.yml`, secret storage
   - Deliverables: ACME or cert-mount configuration, renewal monitoring
   - Acceptance: HTTPS certificates issued automatically; redirect tests pass
3. Build automated backup/restore workflow
   - Files: `scripts/operations/backup.sh` (new), `Makefile`, docs
   - Deliverables: scheduled job templates, restore runbook, verification checklist
   - Acceptance: Successful restore drill documented; artifacts stored securely

### PHASE 3: MEDIUM-PRIORITY ENHANCEMENTS

1. Pin remaining images and publish versions
   - Files: `deployments/docker/docker-compose.*.yml`, `.env.example`, build pipeline
   - Deliverables: Version matrix, release notes, CI checks
   - Acceptance: Compose diff shows explicit tags; CI verifies
2. Refresh documentation
   - Files: `docs/OPERATIONS.md`, service `.env.example`
   - Deliverables: Updated instructions, deprecation notices, changelog entry
   - Acceptance: Docs review sign-off; onboarding checklist updated
3. Introduce CI/CD guardrails
   - Files: `.github/workflows/`, `Makefile`
   - Deliverables: Pipeline for `make validate`, health smoke test, Trivy scan
   - Acceptance: CI mandatory on PRs; sample failure proves enforcement

## IMPLEMENTATION ROADMAP

- **Week 1:** Complete Phase 1 critical fixes; run regression tests; update secrets inventory.
- **Week 2:** Implement TLS automation and credential enforcement; begin backup scripting.
- **Week 3:** Finalize backup/restore drills; pin images; update documentation.
- **Week 4:** Roll out CI pipelines, smoke tests, and schedule follow-up security review.

## SUCCESS CRITERIA

- [ ] Traefik dashboard inaccessible without auth and port 8080 closed externally.
- [ ] Pulsar topics survive controlled restart and retention tests.
- [ ] Production profile requires custom credentials and serves only HTTPS endpoints.
- [ ] Automated backups for Postgres, Infisical, and Pulsar succeed and restorations validated.
- [ ] All container images pinned; CI pipeline enforces validation and security scans.
- [ ] Operations documentation and onboarding steps align with implemented tooling.

## ESTIMATED EFFORT

| Phase                         | Estimated Effort |
| ----------------------------- | ---------------- |
| Phase 1 (Critical Fixes)      | 2 person-days    |
| Phase 2 (High-Priority Fixes) | 4 person-days    |
| Phase 3 (Medium Enhancements) | 3 person-days    |
