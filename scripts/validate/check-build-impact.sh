#!/bin/bash
# ==============================================================================
# A.R.C. Platform - Build Impact Analysis Script
# ==============================================================================
# Purpose: Determine which services need rebuilding when files change
# Usage: ./scripts/validate/check-build-impact.sh [FILE_OR_DIR]
# Exit: 0=success (outputs affected services)
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
CHANGED_PATH="${1:-}"
QUIET=false

if [ "$CHANGED_PATH" = "--help" ] || [ "$CHANGED_PATH" = "-h" ]; then
    echo "Usage: $0 [FILE_OR_DIR]"
    echo ""
    echo "Analyzes which services need rebuilding when a file or directory changes."
    echo ""
    echo "Arguments:"
    echo "  FILE_OR_DIR    Path to changed file or directory (optional)"
    echo "                 If not provided, analyzes git diff"
    echo ""
    echo "Examples:"
    echo "  $0 .docker/base/python-ai/Dockerfile"
    echo "  $0 services/arc-sherlock-brain/"
    echo "  $0 libs/python-sdk/"
    echo "  $0                                      # Analyze git changes"
    exit 0
fi

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          A.R.C. Build Impact Analyzer                             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd "$REPO_ROOT"

# Get list of changed files
if [ -n "$CHANGED_PATH" ]; then
    # Single file/directory provided
    if [ -d "$CHANGED_PATH" ]; then
        CHANGED_FILES=$(find "$CHANGED_PATH" -type f -name "*.py" -o -name "*.go" -o -name "Dockerfile" -o -name "requirements.txt" -o -name "go.mod" 2>/dev/null || echo "$CHANGED_PATH")
    else
        CHANGED_FILES="$CHANGED_PATH"
    fi
    echo -e "${BLUE}Analyzing:${NC} $CHANGED_PATH"
else
    # Use git diff to find changed files
    CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || git diff --name-only 2>/dev/null || echo "")
    if [ -z "$CHANGED_FILES" ]; then
        CHANGED_FILES=$(git diff --staged --name-only 2>/dev/null || echo "")
    fi
    echo -e "${BLUE}Analyzing:${NC} git changes"
fi

echo ""

if [ -z "$CHANGED_FILES" ]; then
    echo -e "${YELLOW}No changes detected${NC}"
    exit 0
fi

# Initialize affected services
declare -A AFFECTED_SERVICES
REBUILD_ALL=false

# Analyze each changed file
while IFS= read -r file; do
    [ -z "$file" ] && continue

    echo -e "${BLUE}Checking:${NC} $file"

    # Base image changes -> rebuild all dependent services
    if [[ "$file" == .docker/base/* ]]; then
        echo -e "  ${RED}→ Base image change - affects all dependent services${NC}"

        if [[ "$file" == *python-ai* ]]; then
            # Python base image - affects all Python services
            for service in services/arc-*/; do
                if [ -f "$service/requirements.txt" ]; then
                    service_name=$(basename "$service")
                    AFFECTED_SERVICES["$service_name"]=1
                    echo -e "  ${YELLOW}  → $service_name${NC}"
                fi
            done
        elif [[ "$file" == *go-infra* ]]; then
            # Go base image - affects all Go services
            for service in services/*/; do
                if [ -f "$service/go.mod" ]; then
                    service_name=$(basename "$service")
                    AFFECTED_SERVICES["$service_name"]=1
                    echo -e "  ${YELLOW}  → $service_name${NC}"
                fi
            done
            # Also check utilities
            if [ -d "services/utilities/raymond" ]; then
                AFFECTED_SERVICES["raymond"]=1
                echo -e "  ${YELLOW}  → raymond${NC}"
            fi
        fi

    # Service-specific changes
    elif [[ "$file" == services/* ]]; then
        # Extract service name
        service_name=$(echo "$file" | cut -d'/' -f2)
        if [ "$service_name" = "utilities" ]; then
            service_name=$(echo "$file" | cut -d'/' -f3)
        fi
        AFFECTED_SERVICES["$service_name"]=1
        echo -e "  ${YELLOW}→ Service: $service_name${NC}"

    # Library changes -> rebuild services using the library
    elif [[ "$file" == libs/* ]]; then
        echo -e "  ${RED}→ Library change - affects services using this library${NC}"

        if [[ "$file" == libs/python-sdk/* ]]; then
            # Python SDK - affects all Python services
            for service in services/arc-*/; do
                if [ -f "$service/requirements.txt" ]; then
                    service_name=$(basename "$service")
                    AFFECTED_SERVICES["$service_name"]=1
                    echo -e "  ${YELLOW}  → $service_name${NC}"
                fi
            done
        elif [[ "$file" == libs/go-sdk/* ]]; then
            # Go SDK - affects all Go services
            for service in services/*/; do
                if [ -f "$service/go.mod" ]; then
                    service_name=$(basename "$service")
                    AFFECTED_SERVICES["$service_name"]=1
                    echo -e "  ${YELLOW}  → $service_name${NC}"
                fi
            done
        fi

    # Docker compose changes
    elif [[ "$file" == deployments/docker/* ]]; then
        echo -e "  ${YELLOW}→ Compose configuration change${NC}"
        # Doesn't require rebuild, but may need redeploy

    # Core infrastructure changes
    elif [[ "$file" == core/* ]]; then
        core_service=$(echo "$file" | cut -d'/' -f2-3 | tr '/' '-')
        AFFECTED_SERVICES["core-$core_service"]=1
        echo -e "  ${YELLOW}→ Core: $core_service${NC}"

    # Plugin changes
    elif [[ "$file" == plugins/* ]]; then
        plugin_service=$(echo "$file" | cut -d'/' -f2-3 | tr '/' '-')
        AFFECTED_SERVICES["plugin-$plugin_service"]=1
        echo -e "  ${YELLOW}→ Plugin: $plugin_service${NC}"

    else
        echo -e "  ${GREEN}→ No rebuild impact${NC}"
    fi

done <<< "$CHANGED_FILES"

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Build Impact Summary${NC}"
echo ""

if [ ${#AFFECTED_SERVICES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ No services need rebuilding${NC}"
else
    echo -e "${YELLOW}Services that need rebuilding:${NC}"
    for service in "${!AFFECTED_SERVICES[@]}"; do
        echo "  • $service"
    done
    echo ""
    echo -e "${BLUE}Total:${NC} ${#AFFECTED_SERVICES[@]} service(s)"
    echo ""
    echo -e "${CYAN}Rebuild commands:${NC}"

    # Generate rebuild commands
    for service in "${!AFFECTED_SERVICES[@]}"; do
        if [[ "$service" == base-* ]]; then
            echo "  docker build -t arc-$service:local .docker/base/${service#base-}/"
        elif [[ "$service" == core-* ]] || [[ "$service" == plugin-* ]]; then
            echo "  # $service uses upstream image (no local build)"
        else
            echo "  docker build -t arc-$service:local services/$service/"
        fi
    done
fi

echo ""
