#!/bin/bash
# Validate all GitHub Actions workflow files with actionlint
#
# Usage:
#   ./validate-workflows.sh
#   ./validate-workflows.sh --fix  # Auto-fix where possible
#
# Exit codes:
#   0 - All workflows valid
#   1 - Validation errors found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if actionlint is installed
check_actionlint() {
    if ! command -v actionlint &> /dev/null; then
        log_error "actionlint is not installed"
        log_info "Install with: brew install actionlint (macOS)"
        log_info "Or download from: https://github.com/rhysd/actionlint/releases"
        exit 1
    fi
    log_info "Using actionlint: $(actionlint --version)"
}

# Check if shellcheck is installed (used by actionlint for shell scripts)
check_shellcheck() {
    if ! command -v shellcheck &> /dev/null; then
        log_warn "shellcheck not installed - some checks may be skipped"
    fi
}

# Validate workflows
validate_workflows() {
    local exit_code=0
    local workflow_count=0
    local error_count=0

    log_info "Validating workflows in: $WORKFLOWS_DIR"
    echo ""

    # Find all workflow files (excluding DEPRECATED)
    while IFS= read -r -d '' workflow; do
        workflow_count=$((workflow_count + 1))
        local relative_path="${workflow#$REPO_ROOT/}"

        # Skip DEPRECATED workflows
        if [[ "$workflow" == *"/DEPRECATED/"* ]]; then
            log_info "Skipping deprecated: $relative_path"
            continue
        fi

        # Run actionlint on each file
        if actionlint "$workflow" 2>&1; then
            echo -e "  ${GREEN}✓${NC} $relative_path"
        else
            echo -e "  ${RED}✗${NC} $relative_path"
            error_count=$((error_count + 1))
            exit_code=1
        fi
    done < <(find "$WORKFLOWS_DIR" -name "*.yml" -o -name "*.yaml" -print0 2>/dev/null | sort -z)

    echo ""
    log_info "Checked $workflow_count workflows"

    if [ $error_count -gt 0 ]; then
        log_error "Found errors in $error_count workflow(s)"
    else
        log_info "All workflows are valid"
    fi

    return $exit_code
}

# Validate composite actions
validate_actions() {
    local actions_dir="$REPO_ROOT/.github/actions"
    local action_count=0
    local error_count=0

    if [ ! -d "$actions_dir" ]; then
        log_info "No composite actions directory found"
        return 0
    fi

    log_info "Validating composite actions in: $actions_dir"
    echo ""

    for action_yml in "$actions_dir"/*/action.yml; do
        if [ -f "$action_yml" ]; then
            action_count=$((action_count + 1))
            local action_dir=$(dirname "$action_yml")
            local action_name=$(basename "$action_dir")

            # Basic YAML syntax check (actionlint doesn't validate action.yml directly)
            if python3 -c "import yaml; yaml.safe_load(open('$action_yml'))" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $action_name/action.yml"
            else
                echo -e "  ${RED}✗${NC} $action_name/action.yml (YAML syntax error)"
                error_count=$((error_count + 1))
            fi
        fi
    done

    echo ""
    log_info "Checked $action_count composite actions"

    if [ $error_count -gt 0 ]; then
        log_error "Found errors in $error_count action(s)"
        return 1
    fi

    return 0
}

# Main
main() {
    log_info "A.R.C. Workflow Validation"
    echo ""

    check_actionlint
    check_shellcheck
    echo ""

    local exit_code=0

    # Validate workflows
    if ! validate_workflows; then
        exit_code=1
    fi

    # Validate composite actions
    if ! validate_actions; then
        exit_code=1
    fi

    echo ""
    if [ $exit_code -eq 0 ]; then
        log_info "All validations passed!"
    else
        log_error "Validation failed - please fix errors above"
    fi

    exit $exit_code
}

main "$@"
