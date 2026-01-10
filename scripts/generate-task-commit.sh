#!/bin/bash
# ==============================================================================
# A.R.C. Platform - Task Commit Generator
# ==============================================================================
# Generates commit entries and appends to specs/XXX/commits.md
# References tasks.md to show completed tasks grouped by phase
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          A.R.C. Task Commit Generator                             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
FEATURE_ID=$(echo "$CURRENT_BRANCH" | grep -oE '^[0-9]+' || echo "")

if [ -z "$FEATURE_ID" ]; then
    echo -e "${RED}❌ Branch doesn't follow feature convention (XXX-feature-name)${NC}"
    exit 1
fi

# Find spec directory
SPEC_DIR=$(find specs -maxdepth 1 -type d -name "${FEATURE_ID}-*" 2>/dev/null | head -n 1)
if [ -z "$SPEC_DIR" ]; then
    echo -e "${RED}❌ No spec directory found for feature $FEATURE_ID${NC}"
    exit 1
fi

TASKS_FILE="$SPEC_DIR/tasks.md"
COMMITS_FILE="$SPEC_DIR/commits.md"
SPEC_NAME=$(basename "$SPEC_DIR")

echo -e "${BLUE}Feature:${NC} #$FEATURE_ID - $SPEC_NAME"
echo -e "${BLUE}Spec:${NC} $SPEC_DIR"
echo -e "${BLUE}Tasks:${NC} $TASKS_FILE"
echo -e "${BLUE}Output:${NC} $COMMITS_FILE"
echo ""

# Check if tasks.md exists
if [ ! -f "$TASKS_FILE" ]; then
    echo -e "${RED}❌ tasks.md not found at $TASKS_FILE${NC}"
    exit 1
fi

# Detect active phase (phase containing the last completed task) - for commit message
ACTIVE_PHASE=""
# Find line number of last completed task, then find the phase header before it
LAST_TASK_LINE=$(grep -n '\- \[[Xx]\]' "$TASKS_FILE" 2>/dev/null | tail -1 | cut -d: -f1)
if [ -n "$LAST_TASK_LINE" ]; then
    ACTIVE_PHASE=$(head -n "$LAST_TASK_LINE" "$TASKS_FILE" | grep '^## Phase' | tail -1 | sed 's/^## //' | sed 's/ (.*//')
fi

# Initialize commits.md if it doesn't exist
if [ ! -f "$COMMITS_FILE" ]; then
    cat > "$COMMITS_FILE" << EOF
# Commit History: $SPEC_NAME

**Feature**: #$FEATURE_ID
**Branch**: \`$CURRENT_BRANCH\`

---

EOF
    echo -e "${GREEN}✓ Created $COMMITS_FILE${NC}"
fi

echo -e "${CYAN}📋 Reading tasks from tasks.md...${NC}"
echo ""

# Parse tasks.md to find all phases and their tasks
# We'll show completed tasks [x] grouped by phase

echo -e "${CYAN}Completed Tasks by Phase:${NC}"
echo ""

# Temporary file to collect tasks for this commit
TEMP_TASKS=$(mktemp)

# Extract phases and their completed tasks
CURRENT_PHASE=""
PHASE_HAS_TASKS=false

while IFS= read -r line; do
    # Check for phase header
    if echo "$line" | grep -qE '^## Phase'; then
        # If previous phase had tasks, add a blank line
        if [ "$PHASE_HAS_TASKS" = true ]; then
            echo "" >> "$TEMP_TASKS"
        fi
        CURRENT_PHASE=$(echo "$line" | sed 's/^## //')
        PHASE_HAS_TASKS=false
    fi

    # Check for completed task
    if echo "$line" | grep -qE '^\- \[[Xx]\]'; then
        if [ "$PHASE_HAS_TASKS" = false ] && [ -n "$CURRENT_PHASE" ]; then
            echo "### $CURRENT_PHASE" >> "$TEMP_TASKS"
            echo "" >> "$TEMP_TASKS"
            PHASE_HAS_TASKS=true
        fi
        # Extract task (remove leading "- [x] " or "- [X] ")
        TASK=$(echo "$line" | sed 's/^- \[[Xx]\] //')
        echo "- [x] $TASK" >> "$TEMP_TASKS"
    fi
done < "$TASKS_FILE"

# Show what we found
if [ -s "$TEMP_TASKS" ]; then
    cat "$TEMP_TASKS"
    echo ""
else
    echo -e "${YELLOW}No completed tasks found in tasks.md${NC}"
    echo ""
fi

# Count staged files
STAGED_FILES=$(git diff --staged --name-only 2>/dev/null)
STAGED_COUNT=$(echo "$STAGED_FILES" | grep -c . || echo "0")

echo -e "${CYAN}📁 Staged files: ${STAGED_COUNT}${NC}"
if [ -n "$STAGED_FILES" ]; then
    echo "$STAGED_FILES" | head -10 | while IFS= read -r f; do
        [ -n "$f" ] && echo "  • $f"
    done
    if [ "$STAGED_COUNT" -gt 10 ]; then
        echo "  ... and $((STAGED_COUNT - 10)) more"
    fi
fi
echo ""

# Prompt for commit summary
echo -e "${CYAN}📝 Enter commit summary (one line):${NC}"
read -r COMMIT_SUMMARY

if [ -z "$COMMIT_SUMMARY" ]; then
    COMMIT_SUMMARY="Task completion"
fi

# Generate timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# Append new commit entry to commits.md
echo -e "${CYAN}✍️  Appending to $COMMITS_FILE...${NC}"

cat >> "$COMMITS_FILE" << EOF

## [$TIMESTAMP] $COMMIT_SUMMARY

EOF

# Add tasks if any
if [ -s "$TEMP_TASKS" ]; then
    cat "$TEMP_TASKS" >> "$COMMITS_FILE"
    echo "" >> "$COMMITS_FILE"
fi

# Add files changed
cat >> "$COMMITS_FILE" << EOF
**Files Changed** ($STAGED_COUNT):
\`\`\`
EOF

echo "$STAGED_FILES" | head -15 >> "$COMMITS_FILE"
if [ "$STAGED_COUNT" -gt 15 ]; then
    echo "... and $((STAGED_COUNT - 15)) more" >> "$COMMITS_FILE"
fi

cat >> "$COMMITS_FILE" << EOF
\`\`\`

---
EOF

# Cleanup temp file
rm -f "$TEMP_TASKS"

echo ""
echo -e "${GREEN}✅ Commit entry appended to $COMMITS_FILE${NC}"
echo ""

# Generate commit message file in Conventional Commits format
COMMIT_MSG_FILE="$SPEC_DIR/.commit-msg"

# Collect task IDs
TASK_IDS=$(grep -E '^\- \[[Xx]\].*T[0-9]+' "$TASKS_FILE" 2>/dev/null | grep -oE 'T[0-9]+' | sort -u | tr '\n' ', ' | sed 's/,$//' | sed 's/,/, /g')

# Build conventional commit message
# Format: feat(FEATURE_ID): Summary
#
# Tasks: T001, T002, T003
# Phase: Phase 1: Setup
# Appends to .commit-msg so multiple task-commits can accumulate
cat >> "$COMMIT_MSG_FILE" << EOF
feat($FEATURE_ID): $COMMIT_SUMMARY

Tasks: $TASK_IDS

EOF

# Add phase info if detected
if [ -n "$ACTIVE_PHASE" ]; then
    echo "Phase: $ACTIVE_PHASE" >> "$COMMIT_MSG_FILE"
    echo "" >> "$COMMIT_MSG_FILE"
fi

# Add brief file summary
echo "Files: $STAGED_COUNT changed" >> "$COMMIT_MSG_FILE"

echo -e "${CYAN}Commit message (Conventional Commits):${NC}"
echo "────────────────────────────────────────"
cat "$COMMIT_MSG_FILE"
echo "────────────────────────────────────────"
echo ""
echo -e "${CYAN}Usage:${NC}"
echo "  ${GREEN}git add $COMMITS_FILE${NC}"
echo "  ${GREEN}git commit -F $COMMIT_MSG_FILE${NC}"
echo ""
echo -e "${CYAN}Or copy first line for -m:${NC}"
FIRST_LINE=$(head -1 "$COMMIT_MSG_FILE")
echo "  ${GREEN}git commit -m \"$FIRST_LINE\"${NC}"
echo ""
