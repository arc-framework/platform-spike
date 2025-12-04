# Journal System

Automated daily journal generation that tracks project evolution, technical implementations, and architectural decisions.

**Status:** ✅ Ready to Use  
**Created:** November 8, 2025  
**Version:** 1.0

---

## 🚀 Quick Start

### Generate Today's Journal

```bash
./tools/journal/generate-journal.sh
```

### Generate for Specific Date

```bash
./tools/journal/generate-journal.sh 2025-11-08
```

### With Comparison to Previous Day

```bash
./tools/journal/generate-journal.sh --compare
```

---

## 📝 What Gets Captured

### Automatically Analyzed

- ✅ **Git commits** since last journal
- ✅ **Files changed** (added/modified/deleted)
- ✅ **Lines of code** changed (+/-)
- ✅ **Authors** who contributed
- ✅ **Project statistics** (services, docs, scripts)

### Categorized Commits

- 🎯 **Features** (feat, feature, add)
- 🐛 **Bug Fixes** (fix, bug)
- ♻️ **Refactoring** (refactor, improve)
- 📚 **Documentation** (doc, docs)
- 🧪 **Testing** (test)
- 🔧 **DevOps** (chore, ci, cd, deploy)

---

## 📊 Journal Structure

Each journal entry includes:

### 1. Technical Summary

- Commit statistics (count, authors, time range)
- Code changes (files modified, lines changed)
- Technologies used
- Project structure metrics

### 2. Non-Technical Explanation

- What was built in plain English
- Business value delivered
- Real-world analogies
- User/stakeholder impact

### 3. Architectural Decisions

- Design choices made today
- Trade-offs considered
- Patterns applied
- Future implications
- Technical debt considerations

### 4. Daily Comparison

- How today differs from yesterday
- Progress indicators
- Velocity tracking
- Evolution patterns

### 5. Next Steps

- Action items for tomorrow
- Weekly/sprint goals
- Technical debt identified
- Learning opportunities

---

## 📁 Output Format

```
tools/journal/entries/
└── YYYY/
    └── MM/
        ├── 08-journal.md
        ├── 09-journal.md
        └── 10-journal.md
```

Each journal is a complete standalone markdown file.

---

## 🎯 Usage Scenarios

### Daily Workflow (Recommended)

```bash
# End of workday (5-6 PM)
./tools/journal/generate-journal.sh

# Review generated content
cat tools/journal/entries/$(date +%Y/%m/%d)-journal.md

# Enhance with personal notes if needed
vim tools/journal/entries/$(date +%Y/%m/%d)-journal.md
```

### Weekly Review

```bash
# View all journals for the week
ls -l tools/journal/entries/2025/11/

# Extract summaries
grep -A 3 "## 📊 Daily Summary" tools/journal/entries/2025/11/*.md
```

### Monthly Archive

```bash
# Create monthly summary (optional)
cat tools/journal/entries/2025/11/*.md > archives/2025-11-summary.md
```

### Specific Date Backfill

```bash
# Generate journal for a past date
./tools/journal/generate-journal.sh 2025-11-07
```

---

## 🤖 AI Enhancement

The script generates an enhancement prompt saved to:

```
/tmp/journal-enhancement-prompt-DATE.txt
```

**The AI Prompt Helps:**

1. Analyze commits for patterns
2. Write non-technical explanations
3. Document architectural decisions
4. Compare with previous work
5. Suggest next steps and improvements

**Usage:**

```bash
# Prompt is auto-copied to clipboard (macOS)
# Paste into ChatGPT/Copilot/Claude with:
# "Please enhance this journal: [paste journal content]"
```

---

## 📅 Automation Options

### Option 1: Daily Cron Job

```bash
# Add to crontab
crontab -e

# Generate journal at 6 PM daily
0 18 * * * cd /path/to/project && ./tools/journal/generate-journal.sh
```

### Option 2: Git Hook

```bash
# Create post-commit hook
cat > .git/hooks/post-commit << 'EOF'
#!/bin/bash
# Update today's journal after each commit
cd "$(git rev-parse --show-toplevel)"
./tools/journal/generate-journal.sh --update
EOF

chmod +x .git/hooks/post-commit
```

### Option 3: Manual (Recommended)

Run manually at end of day for more thoughtful, intentional entries.

---

## 🎨 Customization

### Customize Journal Template

Edit `tools/prompts/template-journal.md` to change:

- Section structure
- Questions asked
- Analysis depth
- Output format

### Modify Script Behavior

Edit `tools/journal/generate-journal.sh` to change:

- What gets analyzed
- Commit categorization rules
- Output location
- Date handling

### Add Custom Sections

Extend the template with:

- Team interactions log
- Meetings attended
- Learning goals achieved
- Personal reflections
- Blockers encountered

---

## 📊 Example Journal Entry

```markdown
# Daily Project Journal - 2025-11-08

**Project:** A.R.C. Platform Spike  
**Date:** Friday, November 8, 2025  
**Status:** ✅ On Track  
**Commits:** 15 (3 authors)  
**Lines Changed:** +350 / -120

---

## 📊 Technical Summary

### Code Changes

- Restructured directory for production-grade organization
- Created journal system for daily progress tracking
- Updated docker-compose paths and references
- Added comprehensive documentation

### Technologies

- Git workflows
- Shell scripting
- Markdown documentation
- Docker Compose

---

## 🎓 For Non-Technical Stakeholders

Today we organized the project structure to make it easier
to maintain and scale long-term. Think of it like organizing
a messy garage - everything now has its proper place, making
it faster to find things and add new items.

We also created an automated system to track daily progress,
similar to a ship's captain keeping a daily log.

---

## 🏗️ Architectural Decisions

**Decision:** Separate tools from framework code
**Rationale:** Developer tools should be independently versioned
**Impact:** Cleaner structure, easier to maintain
**Trade-off:** More directories, but better organization

---

## 🔄 Daily Comparison

**Yesterday:** Initial platform setup
**Today:** Organization and tooling improvements
**Progress:** Structure is now production-ready

---

## 📋 Next Steps

- [ ] Test journal system with team
- [ ] Document new directory structure
- [ ] Update deployment scripts
- [ ] Create getting started guide

**Weekly Goal:** Complete platform documentation
**Sprint Goal:** Production-ready infrastructure
```

---

## 🔍 Finding Information

### Search All Journals

```bash
# Find when feature X was added
grep -r "Feature X" tools/journal/entries/

# Find all bug fixes
grep -r "🐛" tools/journal/entries/

# Find architectural decisions
grep -r "Architectural Decisions" tools/journal/entries/
```

### Statistics

```bash
# Count total commits this month
cat tools/journal/entries/2025/11/*.md | grep "Commits:" | \
  awk '{sum+=$2} END {print "Total commits:", sum}'

# Count journal entries
ls -1 tools/journal/entries/2025/11/ | wc -l
```

---

## 🎯 Benefits

### For Individual Contributors

- ✅ **Track progress** - See what you accomplished
- ✅ **Spot patterns** - Identify recurring issues
- ✅ **Learn continuously** - Review decisions and outcomes
- ✅ **Self-document** - Automatic work history

### For Teams

- ✅ **Onboarding** - New members understand evolution
- ✅ **Retrospectives** - Data for sprint reviews
- ✅ **Knowledge sharing** - Capture tribal knowledge
- ✅ **Collaboration** - See what others are working on

### For Stakeholders

- ✅ **Transparency** - Clear visibility into daily work
- ✅ **Value tracking** - Understand business impact
- ✅ **Planning** - Make informed decisions
- ✅ **Trust building** - See consistent progress

### For Project Management

- ✅ **Velocity tracking** - Historical data
- ✅ **Capacity planning** - Understand team output
- ✅ **Risk identification** - Spot issues early
- ✅ **Documentation** - Automatic project history

---

## ❓ Frequently Asked Questions

**Q: How long does it take to generate?**  
A: ~5 seconds for git analysis. Add 5-10 minutes if enhancing with personal notes.

**Q: Can I edit after generation?**  
A: Yes! Edit the markdown file directly. It's your journal.

**Q: What if I miss a day?**  
A: Generate for any past date: `./tools/journal/generate-journal.sh 2025-11-07`

**Q: Can I automate completely?**  
A: Partially. Git analysis is automatic, but personal reflections/insights require human input.

**Q: Does it work with multiple contributors?**  
A: Yes! It captures all authors. Each person can maintain their own journal or collaborate on a shared one.

**Q: What if there are no commits?**  
A: The script will note "No commits today" and you can add manual notes about non-coding work.

**Q: Can I use it for multiple projects?**  
A: Yes! Run the script from each project's root directory.

---

## 🚨 Troubleshooting

### Script Not Running

```bash
# Make executable
chmod +x tools/journal/generate-journal.sh

# Test
./tools/journal/generate-journal.sh --help
```

### No Commits Found

```bash
# Check git log for date range
git log --since="2025-11-07" --until="2025-11-09"

# Verify you're in a git repository
git status

# Try specific date
./tools/journal/generate-journal.sh 2025-11-08
```

### Wrong Date Format

```bash
# Use ISO format: YYYY-MM-DD
./tools/journal/generate-journal.sh 2025-11-08
```

### Clipboard Not Working

**macOS:** Requires `pbcopy` (should be built-in)  
**Linux:** Install `xclip` or `xsel`  
**Windows Git Bash:** Install `clip` (usually available)

---

## 🎉 Success Story

### Before Journal System

- ❌ Hard to remember what was done each day
- ❌ Difficult to explain progress to stakeholders
- ❌ Architectural decisions lost in code comments
- ❌ No historical tracking
- ❌ Team members don't know what others are doing

### After Journal System

- ✅ Clear daily record of all work
- ✅ Easy stakeholder communication with plain-English summaries
- ✅ Architectural decisions well-documented
- ✅ Complete project evolution history
- ✅ Team transparency and collaboration
- ✅ Better retrospectives with real data
- ✅ Faster onboarding for new team members

---

## 📚 Related Tools

- **[Analysis System](../analysis/)** - Repository health checks
- **[Prompt Templates](../prompts/)** - Customize journal format
- **[Scripts](../../scripts/)** - Automation tools

---

## 🚀 Ready to Start!

```bash
# Generate your first journal
./tools/journal/generate-journal.sh

# View it
cat tools/journal/entries/$(date +%Y/%m/%d)-journal.md

# Make it a habit!
# Set a daily reminder at end of workday
```

**Track your journey. Document your growth. Build better!** 🎯

---

**Version:** 1.0  
**Last Updated:** November 9, 2025  
**Part of:** A.R.C. Framework Development Tools
