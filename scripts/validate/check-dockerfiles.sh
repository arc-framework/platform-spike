#!/bin/bash
# ==============================================================================
# A.R.C. Platform - Dockerfile Linting Script
# ==============================================================================
# Purpose: Lint all Dockerfiles using hadolint
# Usage: ./scripts/validate/check-dockerfiles.sh [--json] [--fix]
# Exit: 0=pass, 1=fail, 2=error
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HADOLINT_CONFIG="$REPO_ROOT/.hadolint.yaml"
OUTPUT_FORMAT="tty"
FAILED=0
PASSED=0
SKIPPED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--json] [--help]"
            echo ""
            echo "Options:"
            echo "  --json    Output results in JSON format"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 2
            ;;
    esac
done

# Check if hadolint is installed
if ! command -v hadolint &> /dev/null; then
    echo -e "${RED}❌ hadolint is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  brew install hadolint          # macOS"
    echo "  apt-get install hadolint       # Debian/Ubuntu"
    echo "  docker pull hadolint/hadolint  # Docker"
    exit 2
fi

# Header
if [ "$OUTPUT_FORMAT" = "tty" ]; then
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          A.R.C. Dockerfile Linter (hadolint)                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
fi

# Find all Dockerfiles
cd "$REPO_ROOT"
DOCKERFILES=$(find . -name "Dockerfile" -type f \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/vendor/*" \
    | sort)

if [ -z "$DOCKERFILES" ]; then
    echo -e "${YELLOW}No Dockerfiles found${NC}"
    exit 0
fi

# JSON output array
JSON_RESULTS="["
FIRST_JSON=true

# Lint each Dockerfile
while IFS= read -r dockerfile; do
    if [ "$OUTPUT_FORMAT" = "tty" ]; then
        echo -e "${BLUE}Linting:${NC} $dockerfile"
    fi

    # Build hadolint command
    HADOLINT_CMD="hadolint"
    if [ -f "$HADOLINT_CONFIG" ]; then
        HADOLINT_CMD="$HADOLINT_CMD --config $HADOLINT_CONFIG"
    fi

    # Run hadolint
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        RESULT=$($HADOLINT_CMD --format json "$dockerfile" 2>&1) || true

        if [ "$FIRST_JSON" = true ]; then
            FIRST_JSON=false
        else
            JSON_RESULTS="$JSON_RESULTS,"
        fi
        JSON_RESULTS="$JSON_RESULTS{\"file\":\"$dockerfile\",\"results\":$RESULT}"
    else
        if $HADOLINT_CMD "$dockerfile" 2>&1; then
            echo -e "  ${GREEN}✓ Passed${NC}"
            ((PASSED++)) || true
        else
            echo -e "  ${RED}✗ Failed${NC}"
            ((FAILED++)) || true
        fi
    fi

    echo ""
done <<< "$DOCKERFILES"

# Close JSON array
JSON_RESULTS="$JSON_RESULTS]"

# Output results
if [ "$OUTPUT_FORMAT" = "json" ]; then
    echo "$JSON_RESULTS"
else
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  ${GREEN}Passed:${NC}  $PASSED"
    echo -e "  ${RED}Failed:${NC}  $FAILED"
    echo -e "  ${YELLOW}Skipped:${NC} $SKIPPED"
    echo ""

    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}❌ Dockerfile linting failed${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ All Dockerfiles passed linting${NC}"
        exit 0
    fi
fi
