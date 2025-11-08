# Analysis System

Comprehensive repository analysis framework for periodic health checks and quality assessment.

**Version:** 1.0  
**Created:** November 8, 2025  
**Purpose:** Automated periodic analysis of infrastructure repositories

---

## 🚀 Quick Start

### Run Analysis (Most Common)
```bash
# Run analysis for today
cd /path/to/project
./scripts/analysis/run-analysis.sh

# Run with comparison to previous analysis
./scripts/analysis/run-analysis.sh --compare

# Run for specific date (MMDD format)
./scripts/analysis/run-analysis.sh 1215

# Get help
./scripts/analysis/run-analysis.sh --help
```

### What Happens
1. Script generates a comprehensive analysis prompt
2. Prompt is saved to `/tmp/repo-analysis-prompt-MMDD.txt`
3. Prompt is copied to clipboard (if supported)
4. You paste it into your AI assistant (Copilot/ChatGPT/Claude)
5. AI generates two detailed reports in `reports/YYYY/MM/`

---

## 📊 What You Get

### Two Generated Reports

#### 1. Analysis Report (`MMDD-ANALYSIS.md`)
- Executive summary with overall grade (A-F)
- Detailed findings across 7 dimensions
- Scoring matrix (0-10 scale per dimension)
- Strengths and weaknesses
- Comparison with previous analysis
- Recommendations priority matrix

#### 2. Concerns & Action Plan (`MMDD-CONCERNS_AND_ACTION_PLAN.md`)
- Concerns categorized by severity:
  - 🔴 **CRITICAL** - Blocks production deployment
  - 🟡 **HIGH** - Fix before staging
  - 🟢 **MEDIUM** - Nice to have improvements
- Each concern includes:
  - Current state with code examples
  - Impact assessment
  - Files affected
  - Solution approach
  - Acceptance criteria
- Multi-phase implementation plan with effort estimates

---

## 📐 Analysis Dimensions

### 1. 🏢 Enterprise Standards Compliance (0-10)
- Industry best practices (CNCF, 12-factor app)
- Observability patterns (OpenTelemetry, metrics, logs, traces)
- Infrastructure layering and separation of concerns
- Container orchestration standards

### 2. ⚙️ Configuration Management & Stability (0-10)
- Environment variable management
- Multi-environment support (dev/staging/prod)
- Configuration validation
- Image versioning strategies (avoid `latest` tags)

### 3. 📦 Lightweight & Resource Efficiency (0-10)
- Container image sizes
- Multi-stage builds
- Resource limits and reservations
- Storage efficiency

### 4. 🔒 Security & Compliance (0-10)
- Secrets management (never commit secrets)
- Network isolation
- Port exposure strategy
- Authentication/authorization
- TLS/SSL configuration

### 5. 🔧 Operational Reliability (0-10)
- Health check configuration
- Service dependencies and startup order
- Logging configuration
- Monitoring and alerting readiness
- Error handling and recovery

### 6. 📚 Developer Experience & Documentation (0-10)
- README quality and completeness
- Makefile/script usability
- Quick start procedures
- Troubleshooting guides
- Code comments and inline documentation

### 7. 🚀 Production Readiness (0-10)
- Production deployment blockers
- Security audit readiness
- Scalability considerations
- High availability support
- Disaster recovery procedures

---

## 🎯 Usage Scenarios

### Scenario 1: Monthly Health Check
```bash
# First of each month
./scripts/analysis/run-analysis.sh 1201 --compare

# Review reports
# Create tickets for HIGH/CRITICAL items
# Track progress in next month's analysis
```

### Scenario 2: Pre-Production Audit
```bash
# Before major release
./scripts/analysis/run-analysis.sh

# Review CRITICAL items
# Block release until resolved
# Document decision if accepting risk
```

### Scenario 3: Post-Implementation Validation
```bash
# After fixing issues
./scripts/analysis/run-analysis.sh --compare

# Check "Issues Resolved" section
# Verify no new regressions
# Update team on progress
```

### Scenario 4: New Team Member Onboarding
```bash
# Show current state
./scripts/analysis/run-analysis.sh

# Use reports as:
# - Architecture overview
# - Known issues documentation
# - Improvement roadmap
```

---

## 🔄 Recommended Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    MONTHLY CYCLE                             │
└─────────────────────────────────────────────────────────────┘

Week 1: Run Analysis
├─ Execute: ./scripts/analysis/run-analysis.sh --compare
├─ Review: Both generated reports
└─ Prioritize: HIGH and CRITICAL items

Week 2: Implementation
├─ Create tickets for top issues
├─ Implement fixes (Phase 1)
└─ Test and validate

Week 3-4: Continuous Improvement
├─ Address MEDIUM items if time permits
├─ Update documentation
└─ Prepare for next cycle

Next Month: Re-analyze
└─ Run with --compare to see progress
```

---

## 📁 Files Structure

```
tools/analysis/
├── README.md                        # This file (complete guide)
└── (consolidated from SETUP, GUIDE, INDEX, QUICK-REFERENCE)

scripts/analysis/
├── run-analysis.sh                  # Main runner script
└── test-analysis-system.sh          # Test script

tools/prompts/
├── template-analysis.md             # Analysis prompt template

reports/YYYY/MM/
├── MMDD-ANALYSIS.md                 # Generated analysis report
└── MMDD-CONCERNS_AND_ACTION_PLAN.md # Generated action plan
```

---

## 💡 Pro Tips

### 1. Archive Reports in Git
```bash
git add reports/YYYY/MM/MMDD-*.md
git commit -m "chore: monthly repository analysis MMDD"
```
**Benefits:** Historical tracking, team visibility, trend analysis

### 2. Create Issue Templates from Concerns
Copy concern details directly into GitHub/Jira issues:
- Use severity as label
- Use category as label
- Copy acceptance criteria as checklist

### 3. Use Compare Mode Regularly
```bash
./scripts/analysis/run-analysis.sh --compare
```
**Shows:** Progress over time, motivates the team

### 4. Customize for Your Stack
Edit `tools/prompts/template-analysis.md` to:
- Add Kubernetes-specific checks
- Include application-level concerns
- Adjust severity definitions for your context

### 5. Run Before Major Changes
Establish baseline before:
- Adding new services
- Changing architecture
- Upgrading dependencies
- Production deployments

---

## 🎓 When to Run Analysis

| Timing | Purpose | Command |
|--------|---------|---------|
| **Monthly** | Regular health check | `./scripts/analysis/run-analysis.sh --compare` |
| **After major changes** | Validate changes didn't introduce issues | `./scripts/analysis/run-analysis.sh` |
| **Pre-deployment** | Gate for staging/production | `./scripts/analysis/run-analysis.sh` |
| **Post-fix** | Verify issues resolved | `./scripts/analysis/run-analysis.sh --compare` |
| **Quarterly** | Comprehensive review for stable projects | `./scripts/analysis/run-analysis.sh --compare` |

---

## 🛠️ Customization

### Modify Analysis Template
Edit `tools/prompts/template-analysis.md` to:
- Add new analysis dimensions
- Change severity level definitions
- Adjust grading rubric
- Include project-specific checks

### Update Runner Script
Edit `scripts/analysis/run-analysis.sh` to:
- Add new command-line flags
- Change output formats
- Integrate with other tools
- Automate additional steps

---

## 📈 What to Expect

### First Run
- Likely many issues identified (don't be discouraged!)
- Focus on CRITICAL items first
- Create multi-month improvement plan
- Establish baseline for tracking

### Subsequent Runs
- Track progress over time
- Celebrate resolved issues
- Catch new issues early
- Maintain quality standards

### Long-term Benefits
- ✅ Improved code quality
- ✅ Better documentation
- ✅ Reduced technical debt
- ✅ Easier onboarding
- ✅ Higher production confidence
- ✅ Faster incident resolution

---

## 🔍 Troubleshooting

### Clipboard Not Working
**Symptom:** Prompt not copied to clipboard  
**Solution:** Manually copy from `/tmp/repo-analysis-prompt-MMDD.txt`

### Script Permission Error
**Symptom:** `Permission denied` when running script  
**Solution:** 
```bash
chmod +x scripts/analysis/run-analysis.sh
```

### Reports Not Generated
**Symptom:** AI doesn't create reports  
**Solution:** Ensure you've provided the complete prompt to AI, including all instructions

### Old Date Format in Reports
**Symptom:** Reports using wrong date  
**Solution:** Specify date explicitly: `./scripts/analysis/run-analysis.sh MMDD`

---

## 🚦 Success Criteria

You'll know this system is working when:

- ✅ Analysis runs smoothly each month
- ✅ Reports guide sprint planning decisions
- ✅ Team references concerns in technical discussions
- ✅ Technical debt decreases over time
- ✅ Production incidents correlate with unresolved concerns
- ✅ New team members use reports for onboarding
- ✅ Compare mode shows measurable progress

---

## 📚 Related Tools

- **[Journal System](../journal/)** - Track daily development progress
- **[Prompt Templates](../prompts/)** - Customize AI prompts
- **[Scripts](../../scripts/)** - Automation and orchestration
- **[Reports Archive](../../reports/)** - Historical analysis reports

---

## ✅ Quick Reference Card

### Most Common Commands
```bash
# Today's analysis
./scripts/analysis/run-analysis.sh

# With comparison
./scripts/analysis/run-analysis.sh --compare

# Specific date
./scripts/analysis/run-analysis.sh 1215

# Help
./scripts/analysis/run-analysis.sh --help
```

### Severity Icons
- 🔴 **CRITICAL** - Production blocker
- 🟡 **HIGH** - Fix before staging
- 🟢 **MEDIUM** - Nice to have

### Report Locations
- Analysis: `reports/YYYY/MM/MMDD-ANALYSIS.md`
- Action Plan: `reports/YYYY/MM/MMDD-CONCERNS_AND_ACTION_PLAN.md`

---

**Status:** ✅ Ready to Use  
**Last Updated:** November 9, 2025  
**Version:** 1.0

