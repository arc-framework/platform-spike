#!/usr/bin/env bash
# ==============================================================================
# A.R.C. Platform - Quickstart Scenario Verification
# ==============================================================================
# Task: T062
# Purpose: Verify that quickstart documentation commands work as expected
# Usage: ./scripts/validate/verify-quickstart.sh [--dry-run] [--json]
# Exit: 0=all pass, 1=failures found
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
DRY_RUN=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--json]"
            echo ""
            echo "Verify that quickstart documentation commands work as expected."
            echo ""
            echo "Options:"
            echo "  --dry-run   Only check commands exist, don't execute"
            echo "  --json      Output results as JSON"
            echo ""
            echo "Scenarios Tested:"
            echo "  1. Prerequisites check"
            echo "  2. Make targets exist"
            echo "  3. Dockerfile templates exist"
            echo "  4. Validation scripts work"
            echo "  5. Documentation links valid"
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
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
FAILED_CHECKS=""
JSON_RESULTS=""

# Helper function to add JSON result
add_json_result() {
    local name="$1"
    local status="$2"
    if [ -n "$JSON_RESULTS" ]; then
        JSON_RESULTS="$JSON_RESULTS,"
    fi
    JSON_RESULTS="$JSON_RESULTS\"$name\":\"$status\""
}

# Helper function to check file exists
check_file() {
    local name="$1"
    local path="$2"
    local description="$3"

    if [ "$JSON_OUTPUT" = false ]; then
        printf "  Checking: %s... " "$description"
    fi

    if [ -f "$path" ] || [ -d "$path" ]; then
        ((TOTAL_PASSED++)) || true
        add_json_result "$name" "passed"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${GREEN}✓${NC}"
        fi
        return 0
    else
        ((TOTAL_FAILED++)) || true
        add_json_result "$name" "failed"
        FAILED_CHECKS="$FAILED_CHECKS $name"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${RED}✗ (not found: $path)${NC}"
        fi
        return 1
    fi
}

# Helper function to check command exists
check_command() {
    local name="$1"
    local cmd="$2"
    local description="$3"

    if [ "$JSON_OUTPUT" = false ]; then
        printf "  Checking: %s... " "$description"
    fi

    if command -v "$cmd" >/dev/null 2>&1; then
        ((TOTAL_PASSED++)) || true
        add_json_result "$name" "passed"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${GREEN}✓${NC}"
        fi
        return 0
    else
        ((TOTAL_FAILED++)) || true
        add_json_result "$name" "failed"
        FAILED_CHECKS="$FAILED_CHECKS $name"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${RED}✗${NC}"
        fi
        return 1
    fi
}

# Helper function to check make target exists
check_make_target() {
    local target="$1"
    local name="make_$target"

    if [ "$JSON_OUTPUT" = false ]; then
        printf "  Checking: make %s... " "$target"
    fi

    if grep -qE "^${target}:|^\.PHONY:.*${target}" Makefile 2>/dev/null; then
        ((TOTAL_PASSED++)) || true
        add_json_result "$name" "passed"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${GREEN}✓${NC}"
        fi
        return 0
    else
        ((TOTAL_FAILED++)) || true
        add_json_result "$name" "failed"
        FAILED_CHECKS="$FAILED_CHECKS $name"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${RED}✗${NC}"
        fi
        return 1
    fi
}

# Helper function to run a scenario
run_scenario() {
    local name="$1"
    local description="$2"
    local command="$3"

    if [ "$JSON_OUTPUT" = false ]; then
        printf "  Running: %s... " "$description"
    fi

    if [ "$DRY_RUN" = true ]; then
        ((TOTAL_SKIPPED++)) || true
        add_json_result "$name" "skipped"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${YELLOW}[skipped]${NC}"
        fi
        return 0
    fi

    set +e
    output=$(eval "$command" 2>&1)
    exit_code=$?
    set -e

    if [ $exit_code -eq 0 ]; then
        ((TOTAL_PASSED++)) || true
        add_json_result "$name" "passed"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${GREEN}✓${NC}"
        fi
    else
        ((TOTAL_FAILED++)) || true
        add_json_result "$name" "failed"
        FAILED_CHECKS="$FAILED_CHECKS $name"
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${RED}✗${NC}"
        fi
    fi

    return 0
}

# Header
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       A.R.C. Platform - Quickstart Verification                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Repository:${NC} $REPO_ROOT"
    echo -e "${BLUE}Mode:${NC} $([ "$DRY_RUN" = true ] && echo "Dry Run" || echo "Full Test")"
    echo ""
fi

# ==============================================================================
# Scenario 1: Prerequisites Check
# ==============================================================================
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔧 Scenario 1: Prerequisites${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
fi

check_command "prereq_docker" "docker" "Docker installed" || true
check_command "prereq_make" "make" "Make installed" || true
check_command "prereq_python" "python3" "Python 3 installed" || true

if [ "$JSON_OUTPUT" = false ]; then
    echo ""
fi

# ==============================================================================
# Scenario 2: Core Files Exist
# ==============================================================================
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}📁 Scenario 2: Core Files Exist${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
fi

check_file "file_makefile" "Makefile" "Makefile" || true
check_file "file_env_example" ".env.example" ".env.example" || true
check_file "file_service_md" "SERVICE.MD" "SERVICE.MD" || true
check_file "file_readme" "README.md" "README.md" || true
check_file "file_hadolint" ".hadolint.yaml" ".hadolint.yaml" || true
check_file "file_precommit" ".pre-commit-config.yaml" ".pre-commit-config.yaml" || true

if [ "$JSON_OUTPUT" = false ]; then
    echo ""
fi

# ==============================================================================
# Scenario 3: Directory Structure
# ==============================================================================
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}📂 Scenario 3: Directory Structure${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
fi

check_file "dir_core" "core" "core/ directory" || true
check_file "dir_plugins" "plugins" "plugins/ directory" || true
check_file "dir_services" "services" "services/ directory" || true
check_file "dir_deployments" "deployments" "deployments/ directory" || true
check_file "dir_docs" "docs" "docs/ directory" || true
check_file "dir_scripts" "scripts" "scripts/ directory" || true
check_file "dir_docker" ".docker" ".docker/ directory" || true
check_file "dir_templates" ".templates" ".templates/ directory" || true

if [ "$JSON_OUTPUT" = false ]; then
    echo ""
fi

# ==============================================================================
# Scenario 4: Validation Scripts
# ==============================================================================
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔍 Scenario 4: Validation Scripts${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
fi

check_file "script_validate_all" "scripts/validate/validate-all.sh" "validate-all.sh" || true
check_file "script_check_structure" "scripts/validate/check-structure.py" "check-structure.py" || true
check_file "script_check_registry" "scripts/validate/check-service-registry.py" "check-service-registry.py" || true
check_file "script_check_dockerfile" "scripts/validate/check-dockerfile-standards.py" "check-dockerfile-standards.py" || true
check_file "script_check_security" "scripts/validate/check-security.sh" "check-security.sh" || true
check_file "script_check_links" "scripts/validate/check-doc-links.py" "check-doc-links.py" || true

if [ "$JSON_OUTPUT" = false ]; then
    echo ""
fi

# ==============================================================================
# Scenario 5: Make Targets
# ==============================================================================
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🎯 Scenario 5: Make Targets${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
fi

check_make_target "help" || true
check_make_target "up" || true
check_make_target "down" || true
check_make_target "build" || true
check_make_target "validate" || true

if [ "$JSON_OUTPUT" = false ]; then
    echo ""
fi

# ==============================================================================
# Scenario 6: Documentation
# ==============================================================================
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}📖 Scenario 6: Documentation${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
fi

check_file "doc_operations" "docs/OPERATIONS.md" "docs/OPERATIONS.md" || true
check_file "doc_docker_standards" "docs/standards/DOCKER-STANDARDS.md" "DOCKER-STANDARDS.md" || true
check_file "doc_validation_failures" "docs/guides/VALIDATION-FAILURES.md" "VALIDATION-FAILURES.md" || true
check_file "doc_security_scanning" "docs/guides/SECURITY-SCANNING.md" "SECURITY-SCANNING.md" || true
check_file "doc_build_optimization" "docs/guides/DOCKER-BUILD-OPTIMIZATION.md" "DOCKER-BUILD-OPTIMIZATION.md" || true

if [ "$JSON_OUTPUT" = false ]; then
    echo ""
fi

# ==============================================================================
# Scenario 7: Functional Tests (if not dry-run)
# ==============================================================================
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}⚡ Scenario 7: Functional Tests${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
fi

run_scenario "func_structure" "Structure validator" "python3 scripts/validate/check-structure.py --json >/dev/null 2>&1"
run_scenario "func_registry" "Service registry validator" "python3 scripts/validate/check-service-registry.py --json >/dev/null 2>&1"
run_scenario "func_dockerfile" "Dockerfile standards" "python3 scripts/validate/check-dockerfile-standards.py --json >/dev/null 2>&1"
run_scenario "func_doc_links" "Documentation links" "python3 scripts/validate/check-doc-links.py --json >/dev/null 2>&1"

if [ "$JSON_OUTPUT" = false ]; then
    echo ""
fi

# ==============================================================================
# Summary
# ==============================================================================
if [ "$JSON_OUTPUT" = true ]; then
    # JSON output
    echo "{"
    echo "  \"valid\": $([ $TOTAL_FAILED -eq 0 ] && echo "true" || echo "false"),"
    echo "  \"summary\": {"
    echo "    \"passed\": $TOTAL_PASSED,"
    echo "    \"failed\": $TOTAL_FAILED,"
    echo "    \"skipped\": $TOTAL_SKIPPED"
    echo "  },"
    echo "  \"results\": {$JSON_RESULTS}"
    echo "}"
else
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                     Verification Summary                          ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}✓ Passed:${NC}  $TOTAL_PASSED"
    echo -e "  ${RED}✗ Failed:${NC}  $TOTAL_FAILED"
    echo -e "  ${YELLOW}○ Skipped:${NC} $TOTAL_SKIPPED"
    echo ""

    if [ $TOTAL_FAILED -gt 0 ]; then
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                    ❌ VERIFICATION FAILED                         ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Failed Checks:${NC}$FAILED_CHECKS"
        echo ""
        echo -e "${YELLOW}Quickstart may not work correctly. Please fix the issues above.${NC}"
    else
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                    ✅ VERIFICATION PASSED                         ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}Quickstart documentation should work as expected!${NC}"
    fi
fi

# Exit with appropriate code
if [ $TOTAL_FAILED -gt 0 ]; then
    exit 1
fi
exit 0
