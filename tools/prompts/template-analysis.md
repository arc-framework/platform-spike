# Repository Analysis Prompt Template

**Version:** 1.0  
**Last Updated:** November 8, 2025  
**Purpose:** Periodic comprehensive analysis of Docker/infrastructure repositories

---

## ANALYSIS REQUEST

You are a senior DevOps/Platform engineer conducting a comprehensive technical audit of this repository. Perform a thorough analysis covering enterprise standards, best practices, security, and operational readiness.

### ANALYSIS SCOPE

Analyze the following dimensions:

#### 1. **Enterprise Standards Compliance**

- Industry best practices (CNCF, 12-factor app, etc.)
- Observability patterns (OpenTelemetry, metrics, logs, traces)
- Infrastructure layering and separation of concerns
- Docker/Container orchestration standards
- Service mesh and networking patterns
- CI/CD integration readiness

#### 2. **Configuration Management & Stability**

- Environment variable management (`.env` files, secrets)
- Multi-environment support (dev, staging, prod)
- Configuration validation and error handling
- Image versioning and pinning strategies
- Volume and data persistence patterns
- Backup and recovery procedures

#### 3. **Lightweight & Resource Efficiency**

- Container image sizes and optimization
- Multi-stage build usage
- Resource limits and reservations
- Memory and CPU allocation
- Storage efficiency
- Network overhead

#### 4. **Security & Compliance**

- Secrets management (hardcoded credentials, weak defaults)
- Network isolation and segmentation
- Port exposure strategy (public vs internal)
- Authentication and authorization
- TLS/SSL configuration
- Container security (rootless, read-only, capabilities)
- Vulnerability scanning readiness

#### 5. **Operational Reliability**

- Health check configuration (consistency, timing)
- Service dependencies and startup ordering
- Logging configuration (drivers, rotation, aggregation)
- Monitoring and alerting hooks
- Graceful shutdown and restart procedures
- Error handling and recovery mechanisms
- Resource limit enforcement

#### 6. **Developer Experience & Documentation**

- README clarity and completeness
- Makefile/script usability
- Quick start procedures
- Troubleshooting guides
- Architecture documentation
- Code comments and inline docs
- Example configurations

#### 7. **Production Readiness**

- Can this run in production as-is?
- What blockers exist for production deployment?
- Security audit readiness
- Scalability considerations
- High availability support
- Disaster recovery capability

---

## ANALYSIS METHODOLOGY

### Phase 1: Discovery (30 minutes)

1. Read and understand:

   - `README.md` - Project overview and setup
   - `OPERATIONS.md` or similar - Operational procedures
   - `Makefile` - Automation and orchestration
   - `docker-compose.yml` - Base services
   - `docker-compose.stack.yml` or overlay files
   - `.env.example` - Configuration template
   - Key configuration files in `config/` directory

2. Identify:
   - Primary services and their roles
   - Technology stack and versions
   - Architecture patterns
   - Dependencies between services

### Phase 2: Analysis (45 minutes)

For each dimension listed above:

1. **Current State** - What is implemented now?
2. **Assessment** - Rate as EXCELLENT/GOOD/NEEDS IMPROVEMENT/POOR
3. **Findings** - Specific issues or strengths identified
4. **Impact** - What are the consequences?
5. **Evidence** - Code snippets, file references

### Phase 3: Reporting (30 minutes)

Generate two comprehensive reports:

#### Report 1: Analysis Report (`MMDD-ANALYSIS.md`)

- Executive summary with overall grade
- Detailed findings per dimension
- Scoring matrix (0-10 scale)
- Strengths and weaknesses
- Comparison with previous analysis (if exists)
- Recommendations priority matrix

#### Report 2: Concerns & Action Plan (`MMDD-CONCERNS_AND_ACTION_PLAN.md`)

- Concerns inventory (categorized by severity)
- Each concern includes:
  - Severity level (🔴 CRITICAL, 🟡 HIGH, 🟢 MEDIUM)
  - Category (Security, Operations, Configuration, etc.)
  - Current state with code examples
  - Impact assessment
  - Files affected
  - Solution approach
  - Acceptance criteria
- Multi-phase implementation plan
- Estimated effort per phase
- Success criteria
- Rollback strategy

---

## OUTPUT REQUIREMENTS

### File Naming Convention

```
report/MMDD-ANALYSIS.md
report/MMDD-CONCERNS_AND_ACTION_PLAN.md
```

Where `MMDD` = current month and day (e.g., `1108` for November 8)

### Report Structure Requirements

#### ANALYSIS Report Must Include:

```markdown
# [Project Name] - Comprehensive Analysis Report

**Date:** [Full date]
**Repository:** [Path/name]
**Analysis Scope:** [Brief description]

## Executive Summary

[2-3 paragraphs: Overall assessment, grade, key findings]

## 1. ENTERPRISE STANDARDS FOLLOWED

[Detailed analysis with status indicators]

## 2. CONFIGURATION STABILITY & DEPLOYMENT

[Lightweight score, resource analysis]

## 3. BEST PRACTICES ASSESSMENT

[What should be adopted]

## 4. UNNECESSARY VALUES & BLOAT

[What can be removed or simplified]

## 5. SECURITY & COMPLIANCE

[Security audit findings]

## 6. OPERATIONAL READINESS

[Production deployment status]

## 7. ASSESSMENT SUMMARY

[Scoring table with grades per dimension]

## 8. COMPARISON WITH PREVIOUS ANALYSIS

[If previous report exists, show progress/regressions]

## 9. RECOMMENDATIONS PRIORITY MATRIX

[HIGH/MEDIUM/LOW priority items with effort estimates]

## 10. NEXT STEPS

[When approved, what to implement]
```

#### CONCERNS Report Must Include:

```markdown
# [Project Name] - Concerns & Action Plan

**Created:** [Date]
**Status:** Ready for Implementation
**Total Issues:** [N] | **Critical:** [N] | **High:** [N] | **Medium:** [N]

## CONCERNS INVENTORY

### 🔴 CRITICAL CONCERNS (Blocking Production)

[Each concern with full detail]

### 🟡 HIGH-PRIORITY CONCERNS

[Each concern with full detail]

### 🟢 MEDIUM-PRIORITY CONCERNS

[Each concern with full detail]

## SOLUTION PLAN

### PHASE 1: CRITICAL FIXES

[Step-by-step with deliverables, files, acceptance criteria]

### PHASE 2: HIGH-PRIORITY FIXES

[Step-by-step with deliverables, files, acceptance criteria]

### PHASE 3: MEDIUM-PRIORITY ENHANCEMENTS

[Step-by-step with deliverables, files, acceptance criteria]

## IMPLEMENTATION ROADMAP

[Visual timeline/tree showing phases]

## SUCCESS CRITERIA

[Checkboxes for completion verification]

## ESTIMATED EFFORT

[Hours/days per phase]
```

---

## GRADING RUBRIC

### Overall Repository Grade Scale

- **A (9-10)**: Production-ready, best-in-class, minimal improvements needed
- **B (7-8)**: Solid implementation, some improvements recommended
- **C (5-6)**: Functional but needs significant hardening for production
- **D (3-4)**: Major issues present, requires substantial work
- **F (0-2)**: Fundamentally broken, not deployable

### Per-Dimension Scoring (0-10)

- **10**: Exemplary, exceeds industry standards
- **8-9**: Excellent, follows best practices
- **6-7**: Good, minor improvements needed
- **4-5**: Adequate, multiple issues present
- **2-3**: Poor, significant problems
- **0-1**: Critical failures, blocking

---

## CONCERN SEVERITY DEFINITIONS

### 🔴 CRITICAL

- Blocks production deployment
- Security vulnerability (high/critical CVE equivalent)
- Data loss risk
- Service availability risk
- Compliance violation

### 🟡 HIGH

- Recommended before staging deployment
- Security issue (medium CVE equivalent)
- Operational burden
- Maintenance difficulty
- Performance degradation risk

### 🟢 MEDIUM

- Nice to have improvements
- Developer experience enhancements
- Minor security hardening
- Documentation gaps
- Code quality issues

---

## SPECIAL INSTRUCTIONS

### Change Tracking

If previous analysis reports exist in `report/` directory:

1. Compare current state against previous findings
2. Identify: Fixed issues, New issues, Regressed issues, Unchanged issues
3. Include progress tracking in analysis report

### Evidence Requirements

For every finding:

- Reference specific files and line numbers when possible
- Include code snippets (before/after examples)
- Explain WHY it matters (impact on security, operations, cost, etc.)

### Actionability

Every concern must have:

- Clear reproduction steps or identification method
- Concrete solution approach (not just "fix it")
- Files that need modification
- Acceptance criteria (how to verify fix works)

### Context Awareness

Consider:

- Is this a spike/POC or production system?
- What's the team's experience level?
- Are there budget/resource constraints?
- What's the deployment target (cloud, on-prem, edge)?

---

## ANALYSIS CHECKLIST

Before completing analysis, verify:

- [ ] All key files read and understood
- [ ] Each dimension thoroughly analyzed
- [ ] Evidence provided for all findings
- [ ] Scoring justified with reasoning
- [ ] Both reports generated with proper naming
- [ ] Previous reports compared (if exist)
- [ ] Concerns categorized by severity
- [ ] Solution approaches are actionable
- [ ] Effort estimates provided
- [ ] Files saved in `report/` directory

---

## RUNNING THIS ANALYSIS

### Manual Execution

1. Copy this entire prompt
2. Provide context: "Analyze this repository using the template"
3. AI will conduct full analysis and generate reports
4. Review reports in `report/MMDD-*.md` files

### Automated Execution (with runner script)

```bash
# Run analysis for today's date
./tools/analysis/run-analysis.sh

# Run analysis for specific date
./tools/analysis/run-analysis.sh 1115

# Compare with previous analysis
./tools/analysis/run-analysis.sh --compare
```

---

## CUSTOMIZATION GUIDE

To adapt this template for different repository types:

### For Application Repositories (not infrastructure)

Add dimensions:

- Code quality and testing coverage
- Dependency management and vulnerabilities
- Build and CI/CD pipeline
- API design and documentation

### For Kubernetes/Helm Repositories

Add dimensions:

- Helm chart best practices
- RBAC and pod security policies
- Resource quotas and limit ranges
- HPA and scaling policies

### For Serverless/Lambda Repositories

Add dimensions:

- Cold start optimization
- Function packaging size
- IAM policy least privilege
- Event source configuration

### For Library/SDK Repositories

Add dimensions:

- API surface and semver compliance
- Backward compatibility
- Example code and samples
- Release automation

---

## VERSION HISTORY

| Version | Date       | Changes                                                  |
| ------- | ---------- | -------------------------------------------------------- |
| 1.0     | 2025-11-08 | Initial template based on A.R.C. Platform Spike analysis |

---

## NOTES

- This template is designed to be comprehensive but flexible
- Adjust scope based on repository size and complexity
- Analysis should take 1.5-2 hours for thorough review
- Reports should be actionable, not just descriptive
- Use this monthly or after major changes
- Archive old reports (don't delete) for trend analysis

---

**END OF TEMPLATE**

When you use this prompt, simply say:

> "Analyze this repository using the standard analysis prompt template. Generate dated reports for today."

The AI will read this template, conduct the analysis, and generate both reports automatically.
