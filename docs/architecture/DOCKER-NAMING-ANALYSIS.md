# Docker Image Naming Analysis - Workflows vs SERVICE.MD

**Date:** January 10, 2026  
**Feature:** 002-stabilize-framework  
**Objective:** Reconcile Docker image names between GitHub workflows (source of truth) and SERVICE.MD documentation

---

## Executive Summary

### Critical Findings

1. **Mismatches Found:** 4 naming inconsistencies between workflows and SERVICE.MD
2. **New Services in Workflows:** 5 services documented in workflows but not in SERVICE.MD
3. **Source of Truth:** GitHub workflows (`.github/workflows/*.yml`) contain production image names
4. **Action Required:** Update SERVICE.MD to match workflow definitions

---

## Discrepancy Matrix

### 🔴 CRITICAL: Naming Mismatches (Fix Required)

| Service | Workflow (✅ CORRECT) | SERVICE.MD (❌ INCORRECT) | Impact |
|---------|----------------------|---------------------------|--------|
| **Identity** | `arc-deckard-identity` | `arc-jarvis-identity` | HIGH - Different codename (Deckard vs JARVIS) |
| **Storage** | `arc-holocron-storage` | `arc-storage` (MinIO as Tardis) | HIGH - Missing codename prefix, wrong codename |
| **Log Shipper** | `arc-hermes-shipper` | `arc-log-shipper` | MEDIUM - Missing codename in SERVICE.MD |
| **LiveKit** | `arc-daredevil-voice` | `arc-voice-server` | MEDIUM - Missing codename in SERVICE.MD |

### 🟡 NEW SERVICES: In Workflows but Not in SERVICE.MD

| Service | Workflow Image | Upstream | Codename | Type | Proposed Role |
|---------|---------------|----------|----------|------|---------------|
| **Backstage** | `arc-architect-portal` | `roadiehq/community-backstage-image` | **The Architect** | TOOLS | Developer portal for service catalog |
| **MailHog** | `arc-hedwig-mailer` | `mailhog/mailhog` | **Hedwig** | SIDECAR | Email testing (already in SERVICE.MD) |
| **Temporal** | `arc-kang-flow` | `temporalio/auto-setup` | **Kang the Conqueror** | INFRA | Workflow orchestration (time-based) |
| **Dkron** | `arc-doc-time` | `dkron/dkron` | **Doc Brown** | INFRA | Distributed cron scheduler |
| **Postgres 17** | `arc-oracle-sql` | `postgres:17-alpine` | **Oracle** | INFRA | Upgraded from Postgres 16 |

### ✅ CORRECT: Matching Names

| Service | Image Name | Status |
|---------|------------|--------|
| **NATS** | `arc-flash-pulse` | ✅ Matches (Flash) |
| **Pulsar** | `arc-strange-stream` | ✅ Matches (Dr. Strange) |
| **Redis** | `arc-sonic-cache` | ✅ Matches (Sonic) |
| **Traefik** | `arc-heimdall-gateway` | ✅ Matches (Heimdall) |
| **Unleash** | `arc-mystique-flags` | ✅ Matches (Mystique) |
| **Infisical** | `arc-fury-vault` | ✅ Matches (Nick Fury) |
| **OTEL** | `arc-widow-otel` | ✅ Matches (Black Widow) |
| **Prometheus** | `arc-house-metrics` | ✅ Matches (Dr. House) |
| **Loki** | `arc-watson-logs` | ✅ Matches (Watson) |
| **Jaeger** | `arc-columbo-traces` | ✅ Matches (Columbo) |
| **Grafana** | `arc-friday-viz` | ✅ Matches (Friday) |
| **Chaos Mesh** | `arc-terminator-chaos` | ✅ Matches (T-800) |
| **LiveKit Ingress** | `arc-sentry-ingress` | ✅ Matches (Sentry) |
| **LiveKit Egress** | `arc-scribe-egress` | ✅ Matches (Scribe) |

---

## Detailed Corrections for SERVICE.MD

### 1. Identity Service - Codename Change

**Current (INCORRECT):**
```markdown
| **Kratos**     | `arc-identity`     | INFRA   | `oryd/kratos:latest`           | **J.A.R.V.I.S.**  | **The Butler.** "Welcome home, sir." Handles identity and authentication. |
```

**Corrected (from workflow):**
```markdown
| **Kratos**     | `arc-deckard-identity`     | INFRA   | `oryd/kratos:latest`           | **Deckard**  | **The Blade Runner.** Validates identity: "Are you real?" Handles authentication. |
```

**Rationale:** 
- Workflow uses `arc-deckard-identity` (Deckard from Blade Runner - thematically fitting for identity validation)
- J.A.R.V.I.S. should be reserved for a more AI-assistant role if needed
- Deckard's role in Blade Runner (determining if replicants are real) is perfect for identity/auth

---

### 2. Storage Service - Missing Codename

**Current (INCORRECT):**
```markdown
| **MinIO**      | `arc-storage`      | INFRA   | `minio/minio`                  | **Tardis**        | **Infinite Storage.** It's bigger on the inside (S3 compatible). |
```

**Corrected (from workflow):**
```markdown
| **MinIO**      | `arc-holocron-storage`      | INFRA   | `minio/minio:latest`                  | **Holocron**        | **The Archive.** Stores ancient knowledge (S3 compatible object storage). Star Wars holocron = data vault. |
```

**Rationale:**
- Workflow uses `arc-holocron-storage` (Star Wars holocrons = knowledge storage devices)
- "Tardis" (Doctor Who) is clever but doesn't fit Marvel/Hollywood theme consistently
- Holocron fits better: ancient data storage, expandable, preserves information

---

### 3. Log Shipper - Missing Codename

**Current (INCORRECT):**
```markdown
| **Promtail**   | `arc-log-shipper`  | INFRA   | `grafana/promtail`             | **Hermes**        | **The Messenger.** Delivers the logs to Watson. |
```

**Corrected (from workflow):**
```markdown
| **Promtail**   | `arc-hermes-shipper`  | INFRA   | `grafana/promtail:latest`             | **Hermes**        | **The Messenger.** Delivers the logs to Watson at the speed of the gods. |
```

**Rationale:**
- Workflow uses `arc-hermes-shipper` (full codename format)
- Maintains consistency with other image names (codename in image name)

---

### 4. LiveKit Server - Missing Codename

**Current (INCORRECT):**
```markdown
| **LiveKit**    | `arc-voice-server` | INFRA   | `livekit/livekit-server`       | **Daredevil**     | **The Radar.** Sees the world through sound waves (WebRTC). |
```

**Corrected (from workflow):**
```markdown
| **LiveKit**    | `arc-daredevil-voice` | INFRA   | `livekit/livekit-server:latest`       | **Daredevil**     | **The Radar.** Sees the world through sound waves (WebRTC SFU for voice/video). |
```

**Rationale:**
- Workflow uses `arc-daredevil-voice` (includes codename)
- Aligns with other media services naming pattern

---

## New Services to Add to SERVICE.MD

### 5. Backstage Developer Portal

**Add to SERVICE.MD:**
```markdown
| **Backstage**  | `arc-architect-portal` | TOOLS   | `roadiehq/community-backstage-image:latest` | **The Architect** | **The Blueprint.** Service catalog and developer portal. "I am the Architect. I created the Matrix." |
```

**Placement:** After **T-800** (arc-chaos), in the INFRA or new TOOLS section  
**Rationale:** 
- The Architect (The Matrix) - creates and manages the system structure
- Backstage is for developers to understand the platform architecture
- Perfect thematic fit for service catalog/developer portal

---

### 6. Temporal Workflow Engine

**Add to SERVICE.MD:**
```markdown
| **Temporal**   | `arc-kang-flow`    | INFRA   | `temporalio/auto-setup:latest` | **Kang the Conqueror** | **The Time Keeper.** Orchestrates workflows across timelines. Controls durable execution. |
```

**Placement:** In INFRA section, near messaging/streaming services  
**Rationale:**
- Kang (Marvel villain) - controls time and timelines
- Temporal is about durable workflow orchestration (time-based)
- Perfect fit for a time-manipulation themed service

---

### 7. Dkron Scheduler

**Add to SERVICE.MD:**
```markdown
| **Dkron**      | `arc-doc-time`     | INFRA   | `dkron/dkron:latest`           | **Doc Brown**     | **The Scheduler.** "Where we're going, we don't need roads." Distributed cron for time-based jobs. |
```

**Placement:** In INFRA section, near Temporal  
**Rationale:**
- Doc Brown (Back to the Future) - time-travel expert, scheduler of events
- Dkron handles scheduled/cron jobs (time-based execution)
- Complements Temporal (workflow orchestration vs. scheduled jobs)

---

### 8. Postgres 17 Upgrade Note

**Update existing entry:**
```markdown
| **Postgres**   | `arc-oracle-sql`       | INFRA   | `postgres:17-alpine`           | **Oracle**        | **Long-Term Memory.** The photographic record of truth. (Upgraded to PG17) |
```

**Rationale:**
- Workflow now uses `postgres:17-alpine` (was 16)
- Maintain same image name and codename
- Add note about version upgrade

---

## Recommendations

### 1. Update SERVICE.MD (IMMEDIATE)
- Fix 4 naming mismatches to match workflows
- Add 4 new services (Backstage, Temporal, Dkron, MailHog already there)
- Update Postgres version to 17

### 2. Establish Workflow as Source of Truth (POLICY)
- Document in `docs/guides/NAMING-CONVENTIONS.md` that workflows are authoritative
- SERVICE.MD should be updated whenever workflows change
- Add CI/CD validation to detect drift

### 3. Codename Consistency Rules (STANDARDS)
- All image names MUST include codename: `arc-{codename}-{role}`
- Examples: `arc-heimdall-gateway`, `arc-sherlock-brain`, `arc-daredevil-voice`
- NO generic names without codenames: `arc-gateway`, `arc-storage`, `arc-voice-server`

### 4. Validate Plan.md and Research.md (ANALYSIS REQUEST 2)

After reviewing the spec files, here's what can be removed as unnecessary:

#### In `plan.md`:
- **✅ KEEP:** All content is relevant and actionable
- **Potential Simplification:** The "Constitution Check" section could be shortened (it's boilerplate)
- **Potential Simplification:** Some research questions are duplicated in `research.md` template

#### In `research.md`:
- **✅ KEEP:** Template structure is good
- **⚠️ REMOVE:** All placeholder sections marked "[TO BE COMPLETED IN PHASE 0]" - this is a template, not actual research
- **RECOMMENDATION:** Either complete the research or clearly mark this as a "Template for Future Research"

---

## Action Items

### High Priority (This Week)
1. ✅ **Update SERVICE.MD** - Fix 4 naming mismatches (see corrections above)
2. ✅ **Add new services** - Backstage, Temporal, Dkron to SERVICE.MD
3. ✅ **Document policy** - Workflows are source of truth for Docker image names

### Medium Priority (Next Sprint)
4. 🔄 **Create validation script** - Compare workflows vs SERVICE.MD automatically
5. 🔄 **Update plan.md** - Reference correct image names in migration plan
6. 🔄 **Update research.md** - Either complete research or mark as template

### Low Priority (Future)
7. 📋 **Add to CI/CD** - Automated drift detection between workflows and SERVICE.MD
8. 📋 **Codename registry** - Central source of truth for all codenames and their meanings

---

## Summary of Changes Needed

**SERVICE.MD Updates:**
- Change `arc-identity` → `arc-deckard-identity` (codename: J.A.R.V.I.S. → Deckard)
- Change `arc-storage` → `arc-holocron-storage` (codename: Tardis → Holocron)
- Change `arc-log-shipper` → `arc-hermes-shipper` (keep codename: Hermes)
- Change `arc-voice-server` → `arc-daredevil-voice` (keep codename: Daredevil)
- Add `arc-architect-portal` (Backstage, codename: The Architect)
- Add `arc-kang-flow` (Temporal, codename: Kang the Conqueror)
- Add `arc-doc-time` (Dkron, codename: Doc Brown)
- Update `arc-oracle-sql` base image to `postgres:17-alpine`

**Total Changes:** 8 corrections + 4 additions = 12 updates

---

**Status:** ✅ Analysis Complete - Ready for Implementation

**Next Step:** Apply corrections to SERVICE.MD


