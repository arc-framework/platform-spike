# 🎯 Repository Analysis Quick Reference

## One-Line Commands

```bash
# Run analysis for today
./scripts/run-analysis.sh

# Run with comparison
./scripts/run-analysis.sh --compare

# Run for specific date
./scripts/run-analysis.sh 1215

# Help
./scripts/run-analysis.sh --help
```

---

## What You Get

### Two Reports Generated:
```
report/MMDD-ANALYSIS.md               # Overall assessment with grades
report/MMDD-CONCERNS_AND_ACTION_PLAN.md  # Prioritized action items
```

---

## Analysis Dimensions

| Dimension | What It Checks |
|-----------|----------------|
| 🏢 **Enterprise Standards** | CNCF compliance, observability, layering |
| ⚙️ **Configuration** | Env vars, multi-env support, secrets |
| 📦 **Lightweight** | Image sizes, resource limits, optimization |
| 🔒 **Security** | Credentials, network isolation, TLS |
| 🔧 **Operations** | Health checks, logging, monitoring |
| 📚 **Documentation** | README, guides, examples |
| 🚀 **Production Ready** | Deployment blockers, scalability |

---

## Severity Levels

| Icon | Level | Meaning |
|------|-------|---------|
| 🔴 | **CRITICAL** | Blocks production deployment |
| 🟡 | **HIGH** | Fix before staging |
| 🟢 | **MEDIUM** | Nice to have improvement |

---

## Typical Workflow

```
1. Run Script          →  2. Copy Prompt     →  3. Give to AI
./scripts/run-analysis.sh   (auto-copied)        (Copilot/ChatGPT)
                                                           ↓
                                                  4. Review Reports
                                             report/MMDD-*.md files
                                                           ↓
5. Prioritize Issues   →  6. Implement Fixes  →  7. Re-analyze
   (Focus on 🔴 & 🟡)        (Use action plan)      (with --compare)
```

---

## When to Run

- ✅ **Monthly** - Regular health check
- ✅ **After major changes** - New services, refactoring
- ✅ **Pre-deployment** - Before staging/production
- ✅ **Post-implementation** - Verify fixes worked

---

## Files Overview

```
.analysis-prompt-template.md     → The brain (reusable framework)
scripts/run-analysis.sh          → The executor (generates prompt)
report/MMDD-*.md                 → The output (analysis results)
ANALYSIS-SYSTEM-README.md        → Full documentation
```

---

## Example Output Structure

### ANALYSIS Report
```markdown
Executive Summary [Grade: B+]
├─ Enterprise Standards [8/10]
├─ Configuration [6/10]
├─ Lightweight [8/10]
├─ Security [7/10]
├─ Operations [6/10]
├─ Documentation [8/10]
└─ Production Ready [6/10]

Recommendations:
├─ HIGH: Fix env file loading
├─ HIGH: Pin image versions
└─ MEDIUM: Add resource limits
```

### CONCERNS Report
```markdown
16 Total Concerns
├─ 🔴 CRITICAL: 5 issues
├─ 🟡 HIGH: 5 issues
└─ 🟢 MEDIUM: 6 issues

Phase 1 (6-8 hours): Critical fixes
Phase 2 (4-5 hours): High priority
Phase 3 (2-3 hours): Enhancements
```

---

## Customization

### Focus on Specific Area
Edit prompt before giving to AI:
```
FOCUS THIS ANALYSIS ON: Security only
```

### Change Date Format
Default: MMDD (1108)
To change: Edit `run-analysis.sh` line 13

### Add New Checks
Edit: `.analysis-prompt-template.md`

---

## Tips

💡 **Use compare mode** to track progress over time  
💡 **Archive reports** in git for historical reference  
💡 **Create issues** from HIGH/CRITICAL concerns  
💡 **Run before major releases** as gate check  
💡 **Customize template** for your stack/needs  

---

## Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Script won't run | `chmod +x scripts/run-analysis.sh` |
| No reports generated | Check AI had prompt and file permissions |
| Clipboard fail | Prompt saved to `/tmp/repo-analysis-prompt-*.txt` |

---

## Need Help?

📖 Full docs: `ANALYSIS-SYSTEM-README.md`  
📝 Template: `.analysis-prompt-template.md`  
🐚 Script: `scripts/run-analysis.sh`  

---

**Ready? Run this:**
```bash
./scripts/run-analysis.sh
```

Then give the generated prompt to your AI assistant! 🚀

