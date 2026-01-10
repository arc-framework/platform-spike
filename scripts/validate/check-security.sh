#!/bin/bash
# ==============================================================================
# A.R.C. Platform - Security Scanning Script
# ==============================================================================
# Purpose: Scan Docker images for vulnerabilities using trivy
# Usage: ./scripts/validate/check-security.sh [--severity HIGH,CRITICAL] [--json]
# Exit: 0=pass, 1=vulnerabilities found, 2=error
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
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
OUTPUT_FORMAT="table"
SCAN_TYPE="image"
FAILED=0
PASSED=0
TOTAL_VULNS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --severity)
            SEVERITY="$2"
            shift 2
            ;;
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --filesystem|--fs)
            SCAN_TYPE="fs"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --severity LEVEL   Comma-separated severity levels (default: HIGH,CRITICAL)"
            echo "  --json             Output results in JSON format"
            echo "  --filesystem       Scan filesystem instead of images"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Scan all arc-* images for HIGH,CRITICAL"
            echo "  $0 --severity MEDIUM         # Include MEDIUM severity"
            echo "  $0 --filesystem              # Scan Dockerfiles in filesystem"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 2
            ;;
    esac
done

# Check if trivy is installed
if ! command -v trivy &> /dev/null; then
    echo -e "${RED}❌ trivy is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  brew install trivy              # macOS"
    echo "  apt-get install trivy           # Debian/Ubuntu"
    echo "  docker pull aquasec/trivy       # Docker"
    exit 2
fi

# Header
if [ "$OUTPUT_FORMAT" = "table" ]; then
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          A.R.C. Security Scanner (trivy)                          ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Severity:${NC} $SEVERITY"
    echo -e "${BLUE}Scan Type:${NC} $SCAN_TYPE"
    echo ""
fi

# JSON output array
JSON_RESULTS="["
FIRST_JSON=true

if [ "$SCAN_TYPE" = "fs" ]; then
    # Filesystem scan - scan Dockerfiles
    if [ "$OUTPUT_FORMAT" = "table" ]; then
        echo -e "${CYAN}Scanning filesystem for vulnerabilities...${NC}"
        echo ""
    fi

    cd "$REPO_ROOT"

    if [ "$OUTPUT_FORMAT" = "json" ]; then
        trivy fs --severity "$SEVERITY" --format json . 2>/dev/null
    else
        if trivy fs --severity "$SEVERITY" . 2>/dev/null; then
            echo -e "${GREEN}✅ No vulnerabilities found${NC}"
        else
            echo -e "${RED}❌ Vulnerabilities found${NC}"
            FAILED=1
        fi
    fi
else
    # Image scan - scan all arc-* images
    IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -E "^arc-" | grep -v "<none>" || true)

    if [ -z "$IMAGES" ]; then
        if [ "$OUTPUT_FORMAT" = "table" ]; then
            echo -e "${YELLOW}No arc-* images found to scan${NC}"
            echo ""
            echo "Build images first with:"
            echo "  make build-base-images"
            echo "  make build-services"
        fi
        exit 0
    fi

    if [ "$OUTPUT_FORMAT" = "table" ]; then
        echo -e "${CYAN}Found images to scan:${NC}"
        echo "$IMAGES" | while read -r img; do
            echo "  • $img"
        done
        echo ""
    fi

    # Scan each image
    while IFS= read -r image; do
        [ -z "$image" ] && continue

        if [ "$OUTPUT_FORMAT" = "table" ]; then
            echo -e "${BLUE}Scanning:${NC} $image"
        fi

        # Run trivy
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            RESULT=$(trivy image --severity "$SEVERITY" --format json "$image" 2>/dev/null) || true

            if [ "$FIRST_JSON" = true ]; then
                FIRST_JSON=false
            else
                JSON_RESULTS="$JSON_RESULTS,"
            fi
            JSON_RESULTS="$JSON_RESULTS{\"image\":\"$image\",\"results\":$RESULT}"
        else
            if trivy image --severity "$SEVERITY" "$image" 2>/dev/null; then
                echo -e "  ${GREEN}✓ No vulnerabilities${NC}"
                ((PASSED++)) || true
            else
                echo -e "  ${RED}✗ Vulnerabilities found${NC}"
                ((FAILED++)) || true
            fi
        fi

        echo ""
    done <<< "$IMAGES"
fi

# Close JSON array
JSON_RESULTS="$JSON_RESULTS]"

# Output results
if [ "$OUTPUT_FORMAT" = "json" ]; then
    echo "$JSON_RESULTS"
else
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  ${GREEN}Clean:${NC}      $PASSED"
    echo -e "  ${RED}Vulnerable:${NC} $FAILED"
    echo ""

    if [ "$FAILED" -gt 0 ]; then
        echo -e "${RED}❌ Security scan found vulnerabilities${NC}"
        echo ""
        echo "To fix:"
        echo "  1. Update base images to latest versions"
        echo "  2. Rebuild affected services"
        echo "  3. Re-run this scan"
        exit 1
    else
        echo -e "${GREEN}✅ All images passed security scan${NC}"
        exit 0
    fi
fi
