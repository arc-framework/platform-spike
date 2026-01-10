#!/bin/bash
# ==============================================================================
# A.R.C. Platform - PR Description Generator
# ==============================================================================
# Generates comprehensive PR descriptions with change analysis and spec integration
# Adapted from arc-cli for platform-spike infrastructure project
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          A.R.C. Platform - PR Description Generator              ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get current branch name
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    echo -e "${RED}❌ Error: Not on a git branch${NC}"
    exit 1
fi

echo -e "${BLUE}📍 Current branch: ${YELLOW}$CURRENT_BRANCH${NC}"

# Extract feature ID from branch name (e.g., 002-stabilize-framework -> 002)
FEATURE_ID=$(echo "$CURRENT_BRANCH" | grep -oE '^[0-9]+')
if [ -z "$FEATURE_ID" ]; then
    echo -e "${YELLOW}⚠️  Branch name doesn't follow feature convention (e.g., 002-feature-name)${NC}"
    echo -e "${YELLOW}   Generating generic PR description...${NC}"
    FEATURE_ID="000"
fi

# Find the spec directory
SPEC_DIR="specs/${CURRENT_BRANCH}"
if [ ! -d "$SPEC_DIR" ]; then
    # Try to find spec directory by feature ID
    echo -e "${YELLOW}⚠️  Exact match not found, searching for spec directory with ID $FEATURE_ID...${NC}"
    SPEC_DIR=$(find specs -maxdepth 1 -type d -name "${FEATURE_ID}-*" 2>/dev/null | head -n 1)
    if [ -z "$SPEC_DIR" ] || [ ! -d "$SPEC_DIR" ]; then
        echo -e "${YELLOW}⚠️  No spec directory found for feature $FEATURE_ID${NC}"
        echo -e "${YELLOW}   Creating generic PR description...${NC}"
        SPEC_DIR=""
    fi
fi

if [ -n "$SPEC_DIR" ]; then
    echo -e "${GREEN}✓ Found spec directory: $SPEC_DIR${NC}"
fi
echo ""

# Get spec directory name for display
SPEC_NAME=$(basename "$SPEC_DIR" 2>/dev/null || echo "$CURRENT_BRANCH")

# Get git statistics
echo -e "${CYAN}📈 Analyzing changes...${NC}"
COMPARE_BRANCH="${1:-main}"

# Check if compare branch exists
if ! git rev-parse --verify "$COMPARE_BRANCH" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Branch '$COMPARE_BRANCH' not found, trying 'develop'...${NC}"
    COMPARE_BRANCH="develop"
    if ! git rev-parse --verify "$COMPARE_BRANCH" >/dev/null 2>&1; then
        echo -e "${RED}❌ Neither 'main' nor 'develop' branch found${NC}"
        COMPARE_BRANCH=""
    fi
fi

if [ -n "$COMPARE_BRANCH" ]; then
    FILES_CHANGED=$(git diff "$COMPARE_BRANCH" --shortstat 2>/dev/null | awk '{print $1}' || echo "0")
    INSERTIONS=$(git diff "$COMPARE_BRANCH" --shortstat 2>/dev/null | awk '{print $4}' || echo "0")
    DELETIONS=$(git diff "$COMPARE_BRANCH" --shortstat 2>/dev/null | awk '{print $6}' || echo "0")
else
    FILES_CHANGED="N/A"
    INSERTIONS="N/A"
    DELETIONS="N/A"
fi

if [ -z "$FILES_CHANGED" ] || [ "$FILES_CHANGED" = "0" ]; then
    echo -e "${YELLOW}⚠️  No changes detected compared to $COMPARE_BRANCH${NC}"
    FILES_CHANGED="0"
    INSERTIONS="0"
    DELETIONS="0"
fi

# Count specific file types (use tr to ensure no newlines in output)
if [ -n "$COMPARE_BRANCH" ]; then
    DOCKERFILE_CHANGES=$(git diff "$COMPARE_BRANCH" --name-only 2>/dev/null | grep -c "Dockerfile" 2>/dev/null | tr -d '\n' || echo "0")
    COMPOSE_CHANGES=$(git diff "$COMPARE_BRANCH" --name-only 2>/dev/null | grep -c "docker-compose" 2>/dev/null | tr -d '\n' || echo "0")
    SCRIPT_CHANGES=$(git diff "$COMPARE_BRANCH" --name-only 2>/dev/null | grep -c "\.sh$" 2>/dev/null | tr -d '\n' || echo "0")
    DOC_CHANGES=$(git diff "$COMPARE_BRANCH" --name-only 2>/dev/null | grep -c "\.md$" 2>/dev/null | tr -d '\n' || echo "0")
    YAML_CHANGES=$(git diff "$COMPARE_BRANCH" --name-only 2>/dev/null | grep -c "\.ya\?ml$" 2>/dev/null | tr -d '\n' || echo "0")
else
    DOCKERFILE_CHANGES="N/A"
    COMPOSE_CHANGES="N/A"
    SCRIPT_CHANGES="N/A"
    DOC_CHANGES="N/A"
    YAML_CHANGES="N/A"
fi

echo -e "${GREEN}✓ Change analysis complete${NC}"
echo "  Files changed: $FILES_CHANGED"
echo "  Insertions: $INSERTIONS"
echo "  Deletions: $DELETIONS"
echo "  Dockerfiles: $DOCKERFILE_CHANGES"
echo "  Compose files: $COMPOSE_CHANGES"
echo "  Scripts: $SCRIPT_CHANGES"
echo "  Documentation: $DOC_CHANGES"
echo ""

# Read spec files for context
if [ -n "$SPEC_DIR" ]; then
    SPEC_FILE="$SPEC_DIR/spec.md"
    TASKS_FILE="$SPEC_DIR/tasks.md"
    PLAN_FILE="$SPEC_DIR/plan.md"
fi

# Generate PR description
if [ -n "$SPEC_DIR" ]; then
    PR_FILE="$SPEC_DIR/pr-description.md"
else
    PR_FILE="pr-description.md"
fi

echo -e "${CYAN}✍️  Generating PR description: $PR_FILE${NC}"

# Start building the PR description
cat > "$PR_FILE" << EOF
## Description

EOF

# Extract description from spec.md if available
if [ -n "$SPEC_DIR" ] && [ -f "$SPEC_FILE" ]; then
    # Get the summary or overview section (macOS compatible - avoid head -n -1)
    DESCRIPTION=$(sed -n '/^## Summary$/,/^## /p' "$SPEC_FILE" 2>/dev/null | tail -n +2 | sed '$d' | sed '/^$/d' | head -n 5)
    if [ -z "$DESCRIPTION" ]; then
        DESCRIPTION=$(sed -n '/^## Overview$/,/^## /p' "$SPEC_FILE" 2>/dev/null | tail -n +2 | sed '$d' | sed '/^$/d' | head -n 5)
    fi
    if [ -n "$DESCRIPTION" ]; then
        echo "$DESCRIPTION" >> "$PR_FILE"
    else
        echo "This PR implements feature #$FEATURE_ID: $SPEC_NAME" >> "$PR_FILE"
    fi
else
    echo "This PR implements changes for branch: \`$CURRENT_BRANCH\`" >> "$PR_FILE"
fi

echo "" >> "$PR_FILE"

# Add type of change (infrastructure-focused) - AUTO-CHECK based on file types
# Determine which checkboxes to check based on changed files
DOCKER_CHECK="[ ]"
INFRA_CHECK="[ ]"
SERVICE_CHECK="[ ]"
SECURITY_CHECK="[ ]"
DOC_CHECK="[ ]"
VALIDATION_CHECK="[ ]"
PERF_CHECK="[ ]"
BUG_CHECK="[ ]"

if [ "$DOCKERFILE_CHANGES" != "0" ] && [ "$DOCKERFILE_CHANGES" != "N/A" ]; then
    DOCKER_CHECK="[x]"
fi
if [ "$COMPOSE_CHANGES" != "0" ] && [ "$COMPOSE_CHANGES" != "N/A" ]; then
    INFRA_CHECK="[x]"
fi
if [ "$YAML_CHANGES" != "0" ] && [ "$YAML_CHANGES" != "N/A" ]; then
    INFRA_CHECK="[x]"
fi
if [ "$DOC_CHANGES" != "0" ] && [ "$DOC_CHANGES" != "N/A" ]; then
    DOC_CHECK="[x]"
fi
if [ "$SCRIPT_CHANGES" != "0" ] && [ "$SCRIPT_CHANGES" != "N/A" ]; then
    # Check if scripts are in validate/ directory
    if [ -n "$COMPARE_BRANCH" ]; then
        VALIDATE_SCRIPTS=$(git diff "$COMPARE_BRANCH" --name-only 2>/dev/null | grep -c "validate" 2>/dev/null | tr -d '\n' || echo "0")
        if [ "$VALIDATE_SCRIPTS" != "0" ]; then
            VALIDATION_CHECK="[x]"
        fi
    fi
fi

# Check for security-related changes
if [ -n "$COMPARE_BRANCH" ]; then
    SECURITY_FILES=$(git diff "$COMPARE_BRANCH" --name-only 2>/dev/null | grep -ciE "security|secret|auth|kratos" 2>/dev/null | tr -d '\n' || echo "0")
    if [ "$SECURITY_FILES" != "0" ]; then
        SECURITY_CHECK="[x]"
    fi
fi

cat >> "$PR_FILE" << EOF
## Type of Change

- $DOCKER_CHECK 🐳 Docker/Container changes
- $INFRA_CHECK 🔧 Infrastructure configuration
- $SERVICE_CHECK 📦 New service or component
- $SECURITY_CHECK 🔒 Security improvement
- $DOC_CHECK 📚 Documentation update
- $VALIDATION_CHECK 🧪 Validation/Testing scripts
- $PERF_CHECK ⚡ Performance optimization
- $BUG_CHECK 🐛 Bug fix

EOF

# Add related issue
cat >> "$PR_FILE" << EOF
## Related Issue

Relates to feature #$FEATURE_ID - \`$SPEC_NAME\`

EOF

# Add changes section
cat >> "$PR_FILE" << 'EOF'
## Changes Made

EOF

# Extract completed tasks from tasks.md
if [ -n "$SPEC_DIR" ] && [ -f "$TASKS_FILE" ]; then
    # Count phases and tasks (ensure no newlines in output)
    TOTAL_PHASES=$(grep -c '^## Phase' "$TASKS_FILE" 2>/dev/null | tr -d '\n' || echo "0")
    COMPLETED_TASKS=$(grep -c '^\- \[[Xx]\]' "$TASKS_FILE" 2>/dev/null | tr -d '\n' || echo "0")
    TOTAL_TASKS=$(grep -c '^\- \[' "$TASKS_FILE" 2>/dev/null | tr -d '\n' || echo "0")

    cat >> "$PR_FILE" << EOF
### Implementation Summary

| Metric | Value |
|--------|-------|
| Tasks Completed | $COMPLETED_TASKS of $TOTAL_TASKS |
| Phases | $TOTAL_PHASES |
| Files Changed | $FILES_CHANGED |
| Dockerfiles Modified | $DOCKERFILE_CHANGES |
| Scripts Added/Modified | $SCRIPT_CHANGES |
| Documentation Files | $DOC_CHANGES |

EOF

    # Extract phase summaries
    echo "### Completed Work by Phase" >> "$PR_FILE"
    echo "" >> "$PR_FILE"

    grep -E '^## Phase' "$TASKS_FILE" 2>/dev/null | head -n 10 | while read -r line; do
        phase_name="${line#\#\# }"
        echo "- **$phase_name**" >> "$PR_FILE"
    done
    echo "" >> "$PR_FILE"
fi

# Add file changes summary
cat >> "$PR_FILE" << EOF
### Files Changed Summary

\`\`\`
$FILES_CHANGED files changed
+$INSERTIONS insertions
-$DELETIONS deletions
\`\`\`

#### By Category
| Category | Count |
|----------|-------|
| Dockerfiles | $DOCKERFILE_CHANGES |
| Docker Compose | $COMPOSE_CHANGES |
| Shell Scripts | $SCRIPT_CHANGES |
| Documentation | $DOC_CHANGES |
| YAML Configs | $YAML_CHANGES |

EOF

# Add testing section
cat >> "$PR_FILE" << 'EOF'
## Testing

- [ ] Docker builds complete successfully
- [ ] Compose stack starts without errors
- [ ] Health checks pass for all services
- [ ] Validation scripts run successfully
- [ ] Documentation is accurate

### Validation Commands

```bash
# Build base images
make build-base-images

# Run validation suite
./scripts/validate/validate-all.sh

# Test Docker Compose
make up-dev && make health
```

EOF

# Add checklist
cat >> "$PR_FILE" << 'EOF'
## Checklist

### Code Quality
- [ ] Shell scripts pass shellcheck
- [ ] Dockerfiles pass hadolint
- [ ] YAML files are valid
- [ ] No secrets committed

### Documentation
- [ ] README files updated where needed
- [ ] SERVICE.MD updated if services changed
- [ ] Architecture docs updated if structure changed

### Security
- [ ] No credentials in code
- [ ] Docker images use non-root users
- [ ] Base images use pinned versions

EOF

# Add infrastructure-specific notes
cat >> "$PR_FILE" << 'EOF'
## Infrastructure Notes

### Breaking Changes
<!-- List any breaking changes that require migration -->
- None

### Migration Steps
<!-- Steps needed to adopt these changes -->
1. Pull latest changes
2. Run `make build` to rebuild images
3. Run `make up-dev` to start services

### Rollback Procedure
<!-- How to rollback if issues occur -->
1. `make down`
2. `git checkout main`
3. `make up-dev`

EOF

# Add footer
cat >> "$PR_FILE" << EOF

---

**Ready for Review**

**Branch**: \`$CURRENT_BRANCH\`
**Base**: \`$COMPARE_BRANCH\`
**Spec Directory**: \`$SPEC_DIR\`
**Generated**: $(date '+%Y-%m-%d %H:%M:%S')

---
*Generated by A.R.C. Platform PR Generator*
EOF

echo -e "${GREEN}✅ PR description generated successfully!${NC}"
echo ""
echo -e "${BLUE}📄 File location: ${YELLOW}$PR_FILE${NC}"
echo ""
echo -e "${CYAN}📊 Statistics:${NC}"
echo "  ✓ $FILES_CHANGED files changed (+$INSERTIONS/-$DELETIONS)"
echo "  ✓ $DOCKERFILE_CHANGES Dockerfile(s)"
echo "  ✓ $SCRIPT_CHANGES script(s)"
echo "  ✓ $DOC_CHANGES documentation file(s)"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Review and customize: ${YELLOW}$PR_FILE${NC}"
echo "  2. Check the 'Type of Change' boxes"
echo "  3. Verify the checklist items"
echo "  4. Create PR: ${GREEN}gh pr create --body-file $PR_FILE${NC}"
echo ""
echo -e "${GREEN}Done!${NC}"
