#!/bin/bash
# Daily Journal Generator
# Analyzes git commits and project state to generate comprehensive journal entries
# Version: 1.0

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JOURNAL_DIR="$PROJECT_ROOT/tools/journal/entries"
TEMPLATE_FILE="$PROJECT_ROOT/tools/prompts/template-journal.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Date handling
TARGET_DATE="${1:-$(date +%Y-%m-%d)}"
# Try macOS date first, then GNU date
if date -j -f "%Y-%m-%d" "$TARGET_DATE" +%Y >/dev/null 2>&1; then
    # macOS
    YEAR=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" +%Y)
    MONTH=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" +%m)
    DAY=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" +%d)
    DAY_NAME=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" +%A)
else
    # GNU/Linux
    YEAR=$(date -d "$TARGET_DATE" +%Y)
    MONTH=$(date -d "$TARGET_DATE" +%m)
    DAY=$(date -d "$TARGET_DATE" +%d)
    DAY_NAME=$(date -d "$TARGET_DATE" +%A)
fi

# Output file
OUTPUT_DIR="$JOURNAL_DIR/$YEAR/$MONTH"
OUTPUT_FILE="$OUTPUT_DIR/$DAY-journal.md"

# Previous day
if date -j -f "%Y-%m-%d" "$TARGET_DATE" +%Y >/dev/null 2>&1; then
    # macOS
    PREV_DATE=$(date -j -v-1d -f "%Y-%m-%d" "$TARGET_DATE" +%Y-%m-%d)
    PREV_YEAR=$(date -j -f "%Y-%m-%d" "$PREV_DATE" +%Y)
    PREV_MONTH=$(date -j -f "%Y-%m-%d" "$PREV_DATE" +%m)
    PREV_DAY=$(date -j -f "%Y-%m-%d" "$PREV_DATE" +%d)
else
    # GNU/Linux
    PREV_DATE=$(date -d "$TARGET_DATE - 1 day" +%Y-%m-%d)
    PREV_YEAR=$(date -d "$PREV_DATE" +%Y)
    PREV_MONTH=$(date -d "$PREV_DATE" +%m)
    PREV_DAY=$(date -d "$PREV_DATE" +%d)
fi
PREV_JOURNAL="$JOURNAL_DIR/$PREV_YEAR/$PREV_MONTH/$PREV_DAY-journal.md"

# Parse options
COMPARE_MODE=false
UPDATE_MODE=false

for arg in "$@"; do
    case $arg in
        --compare)
            COMPARE_MODE=true
            shift
            ;;
        --update)
            UPDATE_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [YYYY-MM-DD] [--compare] [--update]"
            echo ""
            echo "Generate daily journal entry from git commits and project analysis"
            echo ""
            echo "Arguments:"
            echo "  YYYY-MM-DD  Target date (default: today)"
            echo "  --compare   Include comparison with previous day"
            echo "  --update    Update existing journal instead of creating new"
            echo ""
            echo "Examples:"
            echo "  $0                    # Generate today's journal"
            echo "  $0 2025-11-07         # Generate for specific date"
            echo "  $0 --compare          # Include previous day comparison"
            exit 0
            ;;
    esac
done

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║         Daily Journal Generator v1.0                   ║"
echo "║         Project: A.R.C. Platform Spike                 ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}Configuration:${NC}"
echo "  Target Date:     $TARGET_DATE ($DAY_NAME)"
echo "  Output File:     $OUTPUT_FILE"
echo "  Compare Mode:    $COMPARE_MODE"
echo "  Update Mode:     $UPDATE_MODE"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if journal already exists
if [ -f "$OUTPUT_FILE" ] && [ "$UPDATE_MODE" = false ]; then
    echo -e "${YELLOW}⚠ Journal for $TARGET_DATE already exists${NC}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Cancelled. Use --update to append to existing journal.${NC}"
        exit 0
    fi
fi

# Analyze git commits
echo -e "${BLUE}📊 Analyzing git commits...${NC}"

# Get commits since previous day or last 24 hours
if [ "$COMPARE_MODE" = true ] && [ -f "$PREV_JOURNAL" ]; then
    SINCE_DATE="$PREV_DATE"
else
    if date -j -f "%Y-%m-%d" "$TARGET_DATE" +%Y >/dev/null 2>&1; then
        SINCE_DATE=$(date -j -v-1d -f "%Y-%m-%d" "$TARGET_DATE" +%Y-%m-%d)
    else
        SINCE_DATE=$(date -d "$TARGET_DATE - 1 day" +%Y-%m-%d)
    fi
fi

if date -j -f "%Y-%m-%d" "$TARGET_DATE" +%Y >/dev/null 2>&1; then
    UNTIL_DATE=$(date -j -v+1d -f "%Y-%m-%d" "$TARGET_DATE" +%Y-%m-%d)
else
    UNTIL_DATE=$(date -d "$TARGET_DATE + 1 day" +%Y-%m-%d)
fi

cd "$PROJECT_ROOT"

# Git statistics
COMMIT_COUNT=$(git log --since="$SINCE_DATE" --until="$UNTIL_DATE" --oneline | wc -l | tr -d ' ')
AUTHORS=$(git log --since="$SINCE_DATE" --until="$UNTIL_DATE" --format='%an' | sort -u | tr '\n' ', ' | sed 's/,$//')
BRANCHES=$(git log --since="$SINCE_DATE" --until="$UNTIL_DATE" --all --format='%D' | grep -v '^$' | sed 's/, /\n/g' | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')

# Files changed
FILES_CHANGED=$(git diff --name-only --since="$SINCE_DATE" --until="$UNTIL_DATE" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
FILES_ADDED=$(git log --since="$SINCE_DATE" --until="$UNTIL_DATE" --diff-filter=A --name-only --pretty=format: | sort -u | wc -l | tr -d ' ')
FILES_DELETED=$(git log --since="$SINCE_DATE" --until="$UNTIL_DATE" --diff-filter=D --name-only --pretty=format: | sort -u | wc -l | tr -d ' ')

# Lines changed
LINES_STATS=$(git log --since="$SINCE_DATE" --until="$UNTIL_DATE" --shortstat | grep -E "fil(e|es) changed" | awk '{files+=$1; inserted+=$4; deleted+=$6} END {print files " " inserted " " deleted}')
read -r FILES_MOD LINES_ADDED LINES_DELETED <<< "$LINES_STATS"

# Get commit messages
COMMITS=$(git log --since="$SINCE_DATE" --until="$UNTIL_DATE" --oneline --no-merges | head -10)

echo -e "${GREEN}✓ Found $COMMIT_COUNT commits${NC}"

# Analyze project structure
echo -e "${BLUE}🔍 Analyzing project structure...${NC}"

# Count services
SERVICES_COUNT=$(find "$PROJECT_ROOT/services" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

# Count docs
DOCS_COUNT=$(find "$PROJECT_ROOT/docs" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

# Count configs
CONFIGS_COUNT=$(find "$PROJECT_ROOT/config" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')

# Count scripts
SCRIPTS_COUNT=$(find "$PROJECT_ROOT/scripts" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')

echo -e "${GREEN}✓ Project analysis complete${NC}"

# Build journal entry
echo -e "${BLUE}📝 Generating journal entry...${NC}"

# Create journal content
cat > "$OUTPUT_FILE" << EOF
# Daily Project Journal - $TARGET_DATE

**Project:** A.R.C. Platform Spike
**Date:** $TARGET_DATE
**Day:** $DAY_NAME
**Engineer/Team:** [Add your name]

---

## 📊 Daily Summary

**In One Sentence:**
Today we worked on the A.R.C. Platform with $COMMIT_COUNT commits across multiple areas.

**Status:** ✅ On Track
**Mood:** 😊 Productive

---

## 🔄 Changes Overview (Git Analysis)

### Commits Today
- **Total commits:** $COMMIT_COUNT
- **Authors:** ${AUTHORS:-No commits}
- **Branches:** ${BRANCHES:-main}

### Files Changed
- **Modified:** ${FILES_MOD:-0} files
- **Added:** ${FILES_ADDED:-0} files
- **Deleted:** ${FILES_DELETED:-0} files

### Code Statistics
- **Lines added:** +${LINES_ADDED:-0}
- **Lines removed:** -${LINES_DELETED:-0}
- **Net change:** $((${LINES_ADDED:-0} - ${LINES_DELETED:-0})) lines

### Key Commits
\`\`\`
$COMMITS
\`\`\`

---

## 🛠️ Technical Implementation

### What Was Built

EOF

# Analyze commits for technical details
if [ "$COMMIT_COUNT" -gt 0 ]; then
    echo "#### Recent Changes" >> "$OUTPUT_FILE"

    # Extract commit messages and categorize
    git log --since="$SINCE_DATE" --until="$UNTIL_DATE" --oneline --no-merges | while read commit; do
        msg=$(echo "$commit" | cut -d' ' -f2-)

        # Try to categorize
        if echo "$msg" | grep -iq "feat\|feature\|add"; then
            echo "- **Feature:** $msg" >> "$OUTPUT_FILE"
        elif echo "$msg" | grep -iq "fix\|bug"; then
            echo "- **Bug Fix:** $msg" >> "$OUTPUT_FILE"
        elif echo "$msg" | grep -iq "refactor\|improve"; then
            echo "- **Refactoring:** $msg" >> "$OUTPUT_FILE"
        elif echo "$msg" | grep -iq "doc\|docs"; then
            echo "- **Documentation:** $msg" >> "$OUTPUT_FILE"
        elif echo "$msg" | grep -iq "test"; then
            echo "- **Testing:** $msg" >> "$OUTPUT_FILE"
        elif echo "$msg" | grep -iq "chore\|ci\|cd\|deploy"; then
            echo "- **DevOps/Chore:** $msg" >> "$OUTPUT_FILE"
        else
            echo "- **Other:** $msg" >> "$OUTPUT_FILE"
        fi
    done
else
    echo "No commits recorded for this date." >> "$OUTPUT_FILE"
fi

# Continue building journal
cat >> "$OUTPUT_FILE" << EOF

### Technologies Used
- **Languages:** Go, Shell, YAML
- **Frameworks:** OpenTelemetry, Docker Compose
- **Tools:** Git, Make, Docker
- **Services:** Various (see config/)

### Project Structure
- **Services:** $SERVICES_COUNT microservices
- **Documentation:** $DOCS_COUNT markdown files
- **Configurations:** $CONFIGS_COUNT config files
- **Scripts:** $SCRIPTS_COUNT automation scripts

---

## 👥 For Non-Technical Stakeholders

### What This Means in Plain English

**Problem We Solved:**
We continued building and improving the A.R.C. platform infrastructure, which provides the foundation for running AI agents reliably.

**What We Built:**
Today's work focused on $(if [ "$COMMIT_COUNT" -gt 5 ]; then echo "significant development"; elif [ "$COMMIT_COUNT" -gt 0 ]; then echo "steady progress"; else echo "planning and analysis"; fi) across the platform components.

**Why It Matters:**
Each improvement makes the system more reliable, easier to maintain, and better prepared for production use.

**Real-World Analogy:**
This is like building a house - we're ensuring the foundation is solid, the utilities work properly, and everything is documented so others can maintain it.

### User Impact
- **Who benefits:** Development team and future platform users
- **How they benefit:** More reliable infrastructure, better observability, cleaner code organization
- **When available:** Continuous improvements being deployed

### Business Value
- **Efficiency gains:** Better organized code reduces maintenance time
- **Risk reduction:** Improved monitoring and error handling
- **Capability added:** Enhanced platform capabilities for running AI agents

---

## 🏗️ Architectural Decisions & Design

### Context
The A.R.C. Platform Spike demonstrates a production-ready infrastructure stack including:
- **Observability:** OpenTelemetry, Prometheus, Loki, Jaeger, Grafana
- **Platform Services:** PostgreSQL, Redis, NATS, Pulsar, Kratos, Unleash, Infisical, Traefik
- **Service Orchestration:** Docker Compose with environment-based configuration

### Recent Decisions
$(if [ "$COMMIT_COUNT" -gt 0 ]; then echo "[Extract from commit messages and document key architectural decisions]"; else echo "No new architectural decisions today. Continuing with established patterns."; fi)

---

## 💡 Ideas & Innovations

### Current Architecture Highlights
- **Layered Design:** Clean separation between observability, platform, and application layers
- **Configuration Management:** Per-service environment files with organized structure
- **Automated Analysis:** Built-in repository analysis system for continuous improvement

### Ongoing Innovations
- Journal system for tracking daily progress and decisions
- Automated analysis framework for code quality monitoring
- Production-grade directory structure for enterprise use

---

## 📈 Comparison with Previous Day

EOF

if [ "$COMPARE_MODE" = true ] && [ -f "$PREV_JOURNAL" ]; then
    echo "### Evolution from $PREV_DATE" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "#### Changes" >> "$OUTPUT_FILE"
    echo "- **Commits:** Previous work continued" >> "$OUTPUT_FILE"
    echo "- **Activity:** $(if [ "$COMMIT_COUNT" -gt 0 ]; then echo "Active development"; else echo "Planning/Review day"; fi)" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "*See [previous journal]($PREV_JOURNAL) for comparison*" >> "$OUTPUT_FILE"
else
    echo "### First Journal Entry" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "This is the first journal entry. Future entries will include comparison with previous days." >> "$OUTPUT_FILE"
fi

# Continue with template sections
cat >> "$OUTPUT_FILE" << 'EOF'

---

## 🎯 Challenges & Solutions

### Today's Challenges
[Document any challenges encountered]

### Solutions Applied
[How challenges were resolved]

---

## 📝 Documentation Updates

### Files Modified
EOF

# List modified documentation files
git diff --name-only --since="$SINCE_DATE" --until="$UNTIL_DATE" 2>/dev/null | grep "\.md$" | head -10 | while read file; do
    echo "- \`$file\`" >> "$OUTPUT_FILE"
done || echo "- No documentation changes detected" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << EOF

---

## 🔮 Next Steps & Planning

### Immediate Next Steps
1. Continue development based on today's progress
2. Address any identified technical debt
3. Update documentation as needed

### This Week's Focus
- Maintain platform stability
- Improve observability coverage
- Enhance documentation
- Prepare for production deployment

---

## 📊 Project Health Indicators

### Overall Health
- **Technical:** 🟢 Healthy
- **Schedule:** 🟢 On Track
- **Quality:** 🟢 High
- **Team Morale:** 🟢 Great

### Metrics
- **Services:** $SERVICES_COUNT
- **Documentation:** $DOCS_COUNT files
- **Automation:** $SCRIPTS_COUNT scripts
- **Commits today:** $COMMIT_COUNT

---

## 💭 Reflections

### What Went Well
$(if [ "$COMMIT_COUNT" -gt 3 ]; then echo "- Good commit velocity today"; fi)
$(if [ "$LINES_ADDED" -gt 100 ]; then echo "- Significant progress on implementation"; fi)
- [Add specific wins]

### What Could Be Better
- [Add areas for improvement]

---

## ✅ Action Items for Tomorrow

- [ ] Review today's changes
- [ ] Continue with planned work
- [ ] Update any pending documentation
- [ ] Check system health

---

**End of Journal Entry**

*Generated: $(date '+%Y-%m-%d %H:%M:%S')*
*Generated by: tools/journal/generate-journal.sh*

---

## Quick Navigation
- [Previous Day]($PREV_JOURNAL)
- [Journal Home](../README.md)
- [Project Documentation](../../docs/README.md)
EOF

echo -e "${GREEN}✓ Journal entry created: $OUTPUT_FILE${NC}"

# Generate AI-enhanced prompt if requested
PROMPT_FILE="/tmp/journal-enhancement-prompt-$TARGET_DATE.txt"

cat > "$PROMPT_FILE" << 'EOFPROMPT'
# Journal Enhancement Prompt

I have generated a daily journal entry from git commits. Please enhance it by:

1. **Analyzing the commits** to identify:
   - Major features implemented
   - Bug fixes applied
   - Architectural changes
   - Documentation improvements

2. **Writing a clear non-technical explanation** that:
   - Explains what was built in simple terms
   - Describes the business value
   - Uses everyday analogies
   - Focuses on user/business impact

3. **Documenting architectural decisions** including:
   - Why certain choices were made
   - Trade-offs considered
   - Alternative approaches
   - Long-term implications

4. **Comparing with previous work** to show:
   - How the project evolved
   - What patterns emerged
   - What improved
   - What challenges arose

5. **Suggesting next steps** based on:
   - Current progress
   - Identified gaps
   - Technical debt
   - Opportunities for improvement

Please read the journal file and enhance it with these insights while keeping all existing content and structure.

Journal file: OUTPUT_FILE_PLACEHOLDER

After enhancement, the journal should be:
- Comprehensive yet readable
- Technical yet accessible
- Actionable for the team
- Valuable for stakeholders
EOFPROMPT

sed -i.bak "s|OUTPUT_FILE_PLACEHOLDER|$OUTPUT_FILE|g" "$PROMPT_FILE"
rm "$PROMPT_FILE.bak" 2>/dev/null || true

echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo ""
echo -e "1. Journal created at: ${BLUE}$OUTPUT_FILE${NC}"
echo ""
echo -e "2. Review and enhance the journal with:"
echo -e "   ${GREEN}→${NC} Open in editor and fill in [bracketed] sections"
echo -e "   ${GREEN}→${NC} Add personal reflections and insights"
echo -e "   ${GREEN}→${NC} Document challenges and solutions"
echo ""
echo -e "3. Optional: Use AI to enhance the journal:"
echo -e "   ${GREEN}→${NC} Prompt saved to: ${BLUE}$PROMPT_FILE${NC}"
echo -e "   ${GREEN}→${NC} Provide this prompt + journal to AI for enhancement"
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
echo ""

# Copy to clipboard if available
if command -v pbcopy &> /dev/null; then
    cat "$PROMPT_FILE" | pbcopy
    echo -e "${GREEN}✓ Enhancement prompt copied to clipboard (macOS)${NC}"
elif command -v xclip &> /dev/null; then
    cat "$PROMPT_FILE" | xclip -selection clipboard
    echo -e "${GREEN}✓ Enhancement prompt copied to clipboard (Linux)${NC}"
fi

echo ""
echo -e "${GREEN}✓ Journal generation complete!${NC}"
echo ""
echo -e "View your journal: ${BLUE}cat $OUTPUT_FILE${NC}"

