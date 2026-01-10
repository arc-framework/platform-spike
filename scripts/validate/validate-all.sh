#!/bin/bash
# ==============================================================================
# A.R.C. Platform - Validation Orchestrator
# ==============================================================================
# Task: T056
# Purpose: Run all validation checks and report results
# Usage: ./scripts/validate/validate-all.sh [--strict] [--json] [--quick]
# Exit: 0=all pass, 1=errors found
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

# Parse arguments
STRICT=false
JSON_OUTPUT=false
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --strict)
            STRICT=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--strict] [--json] [--quick]"
            echo ""
            echo "Run all validation checks for the A.R.C. platform."
            echo ""
            echo "Options:"
            echo "  --strict    Treat warnings as errors"
            echo "  --json      Output results as JSON"
            echo "  --quick     Run only fast checks (skip hadolint/trivy)"
            echo ""
            echo "Validations Run:"
            echo "  1. Directory structure (check-structure.py)"
            echo "  2. SERVICE.MD registry (check-service-registry.py)"
            echo "  3. Dockerfile standards (check-dockerfile-standards.py)"
            echo "  4. Dockerfile linting (hadolint) [unless --quick]"
            echo "  5. Docker compose validation"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "$REPO_ROOT"

# Track results
declare -A RESULTS
TOTAL_ERRORS=0
TOTAL_WARNINGS=0

# Helper function to run a validation
run_validation() {
    local name="$1"
    local command="$2"
    local description="$3"

    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}🔍 $description${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    fi

    # Add strict flag if needed
    if [ "$STRICT" = true ]; then
        command="$command --strict"
    fi

    # Run the command and capture exit code
    set +e
    if [ "$JSON_OUTPUT" = true ]; then
        output=$($command --json 2>&1)
        exit_code=$?
    else
        $command
        exit_code=$?
    fi
    set -e

    if [ $exit_code -eq 0 ]; then
        RESULTS["$name"]="pass"
        if [ "$JSON_OUTPUT" = false ]; then
            echo ""
            echo -e "${GREEN}✅ $name: PASSED${NC}"
        fi
    else
        RESULTS["$name"]="fail"
        ((TOTAL_ERRORS++))
        if [ "$JSON_OUTPUT" = false ]; then
            echo ""
            echo -e "${RED}❌ $name: FAILED${NC}"
        fi
    fi

    if [ "$JSON_OUTPUT" = false ]; then
        echo ""
    fi

    return $exit_code
}

# Header
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          A.R.C. Platform - Validation Suite                       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Repository:${NC} $REPO_ROOT"
    echo -e "${BLUE}Mode:${NC} $([ "$STRICT" = true ] && echo "Strict" || echo "Normal")"
    echo -e "${BLUE}Quick:${NC} $([ "$QUICK_MODE" = true ] && echo "Yes" || echo "No")"
    echo ""
fi

# Run validations
FAILED=false

# 1. Directory Structure
if ! run_validation "structure" "python3 $SCRIPT_DIR/check-structure.py" "Validating directory structure..."; then
    FAILED=true
fi

# 2. SERVICE.MD Registry
if ! run_validation "service_registry" "python3 $SCRIPT_DIR/check-service-registry.py" "Validating SERVICE.MD registry..."; then
    FAILED=true
fi

# 3. Dockerfile Standards (A.R.C. specific)
if ! run_validation "dockerfile_standards" "python3 $SCRIPT_DIR/check-dockerfile-standards.py" "Validating Dockerfile standards..."; then
    FAILED=true
fi

# 4. Hadolint (unless quick mode)
if [ "$QUICK_MODE" = false ]; then
    if command -v hadolint >/dev/null 2>&1; then
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}🔍 Running hadolint...${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
        fi

        hadolint_failed=false
        while IFS= read -r dockerfile; do
            if [ "$JSON_OUTPUT" = false ]; then
                echo -e "${BLUE}Linting:${NC} $dockerfile"
            fi
            if ! hadolint "$dockerfile" 2>&1; then
                hadolint_failed=true
            fi
        done < <(find . -name "Dockerfile" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)

        if [ "$hadolint_failed" = true ]; then
            RESULTS["hadolint"]="fail"
            FAILED=true
            ((TOTAL_ERRORS++))
            if [ "$JSON_OUTPUT" = false ]; then
                echo ""
                echo -e "${RED}❌ hadolint: FAILED${NC}"
            fi
        else
            RESULTS["hadolint"]="pass"
            if [ "$JSON_OUTPUT" = false ]; then
                echo ""
                echo -e "${GREEN}✅ hadolint: PASSED${NC}"
            fi
        fi
        echo ""
    else
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${YELLOW}⚠️  hadolint not installed - skipping${NC}"
            echo ""
        fi
        RESULTS["hadolint"]="skipped"
    fi
fi

# 5. Docker Compose Validation
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔍 Validating Docker Compose files...${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
fi

compose_dir="$REPO_ROOT/deployments/docker"
compose_failed=false

if [ -d "$compose_dir" ]; then
    for compose_file in "$compose_dir"/docker-compose*.yml; do
        if [ -f "$compose_file" ]; then
            if [ "$JSON_OUTPUT" = false ]; then
                echo -e "${BLUE}Validating:${NC} $(basename "$compose_file")"
            fi
            if ! docker compose -f "$compose_file" config >/dev/null 2>&1; then
                compose_failed=true
                if [ "$JSON_OUTPUT" = false ]; then
                    echo -e "${RED}  ✗ Invalid${NC}"
                fi
            else
                if [ "$JSON_OUTPUT" = false ]; then
                    echo -e "${GREEN}  ✓ Valid${NC}"
                fi
            fi
        fi
    done
fi

if [ "$compose_failed" = true ]; then
    RESULTS["compose"]="fail"
    FAILED=true
    ((TOTAL_ERRORS++))
    if [ "$JSON_OUTPUT" = false ]; then
        echo ""
        echo -e "${RED}❌ compose: FAILED${NC}"
    fi
else
    RESULTS["compose"]="pass"
    if [ "$JSON_OUTPUT" = false ]; then
        echo ""
        echo -e "${GREEN}✅ compose: PASSED${NC}"
    fi
fi

# Summary
if [ "$JSON_OUTPUT" = true ]; then
    # JSON output
    echo "{"
    echo "  \"valid\": $([ "$FAILED" = true ] && echo "false" || echo "true"),"
    echo "  \"results\": {"
    first=true
    for key in "${!RESULTS[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        printf "    \"%s\": \"%s\"" "$key" "${RESULTS[$key]}"
    done
    echo ""
    echo "  },"
    echo "  \"total_errors\": $TOTAL_ERRORS"
    echo "}"
else
    # Text summary
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                        Validation Summary                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    for key in "${!RESULTS[@]}"; do
        result="${RESULTS[$key]}"
        if [ "$result" = "pass" ]; then
            echo -e "  ${GREEN}✓${NC} $key"
        elif [ "$result" = "fail" ]; then
            echo -e "  ${RED}✗${NC} $key"
        else
            echo -e "  ${YELLOW}○${NC} $key (skipped)"
        fi
    done

    echo ""

    if [ "$FAILED" = true ]; then
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                    ❌ VALIDATION FAILED                           ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Fix the errors above and run again.${NC}"
        echo -e "${YELLOW}See docs/guides/VALIDATION-FAILURES.md for help.${NC}"
    else
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    ✅ ALL VALIDATIONS PASSED                      ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    fi
fi

# Exit with appropriate code
if [ "$FAILED" = true ]; then
    exit 1
fi
exit 0
