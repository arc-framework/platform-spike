#!/bin/bash
# ==============================================================================
# A.R.C. Platform - Build Time Tracking Script
# ==============================================================================
# Purpose: Build all services and record build times for performance tracking
# Usage: ./scripts/validate/track-build-times.sh [--cold|--warm] [--json]
# Exit: 0=success, 1=build failure
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
REPORTS_DIR="$REPO_ROOT/reports"

# Parse arguments
BUILD_TYPE="warm"
OUTPUT_FORMAT="text"
SERVICES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --cold)
            BUILD_TYPE="cold"
            shift
            ;;
        --warm)
            BUILD_TYPE="warm"
            shift
            ;;
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--cold|--warm] [--json] [SERVICE...]"
            echo ""
            echo "Build services and track build times."
            echo ""
            echo "Options:"
            echo "  --cold    Clear Docker cache before building"
            echo "  --warm    Use existing cache (default)"
            echo "  --json    Output results as JSON"
            echo ""
            echo "Arguments:"
            echo "  SERVICE   Specific service(s) to build (default: all)"
            echo ""
            echo "Examples:"
            echo "  $0                           # Warm build all services"
            echo "  $0 --cold                    # Cold build all services"
            echo "  $0 arc-sherlock-brain        # Build specific service"
            echo "  $0 --json > report.json      # Output as JSON"
            exit 0
            ;;
        *)
            SERVICES+=("$1")
            shift
            ;;
    esac
done

# Initialize results
declare -A BUILD_TIMES
declare -A BUILD_STATUS
declare -A IMAGE_SIZES
TOTAL_START=$(date +%s)

# Find services to build
if [ ${#SERVICES[@]} -eq 0 ]; then
    # Build all services with Dockerfiles
    while IFS= read -r dockerfile; do
        service_dir=$(dirname "$dockerfile")
        service_name=$(basename "$service_dir")
        # Handle utilities subdirectory
        if [[ "$service_dir" == *"/utilities/"* ]]; then
            service_name=$(basename "$service_dir")
        fi
        SERVICES+=("$service_name")
    done < <(find "$REPO_ROOT/services" -name "Dockerfile" -type f 2>/dev/null)
fi

# Header
if [ "$OUTPUT_FORMAT" = "text" ]; then
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          A.R.C. Build Time Tracker                                ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Build Type:${NC} $BUILD_TYPE"
    echo -e "${BLUE}Services:${NC}   ${#SERVICES[@]}"
    echo ""
fi

# Clear cache for cold builds
if [ "$BUILD_TYPE" = "cold" ]; then
    if [ "$OUTPUT_FORMAT" = "text" ]; then
        echo -e "${YELLOW}Clearing Docker build cache...${NC}"
    fi
    docker builder prune -af --filter "until=0s" 2>/dev/null || true
fi

# Enable BuildKit
export DOCKER_BUILDKIT=1

# Build each service
for service in "${SERVICES[@]}"; do
    # Find the Dockerfile
    dockerfile=""
    context=""

    if [ -f "$REPO_ROOT/services/$service/Dockerfile" ]; then
        dockerfile="$REPO_ROOT/services/$service/Dockerfile"
        context="$REPO_ROOT/services/$service"
    elif [ -f "$REPO_ROOT/services/utilities/$service/Dockerfile" ]; then
        dockerfile="$REPO_ROOT/services/utilities/$service/Dockerfile"
        context="$REPO_ROOT/services/utilities/$service"
    else
        if [ "$OUTPUT_FORMAT" = "text" ]; then
            echo -e "${YELLOW}⚠️  Skipping $service: Dockerfile not found${NC}"
        fi
        BUILD_STATUS[$service]="skipped"
        continue
    fi

    if [ "$OUTPUT_FORMAT" = "text" ]; then
        echo -e "${BLUE}Building:${NC} $service"
        printf "  %-30s" "Build time:"
    fi

    # Record start time
    start_time=$(date +%s.%N)

    # Build the image
    image_tag="arc-$service:build-test"

    # Special handling for piper (builds from repo root)
    if [ "$service" = "arc-piper-tts" ]; then
        context="$REPO_ROOT"
    fi

    if docker build -t "$image_tag" -f "$dockerfile" "$context" >/dev/null 2>&1; then
        BUILD_STATUS[$service]="success"

        # Record end time
        end_time=$(date +%s.%N)
        build_time=$(echo "$end_time - $start_time" | bc)
        BUILD_TIMES[$service]=$build_time

        # Get image size
        size=$(docker images "$image_tag" --format "{{.Size}}" 2>/dev/null || echo "unknown")
        IMAGE_SIZES[$service]=$size

        if [ "$OUTPUT_FORMAT" = "text" ]; then
            printf "${GREEN}%.2fs${NC}\n" "$build_time"
            printf "  %-30s %s\n" "Image size:" "$size"
        fi

        # Cleanup test image
        docker rmi "$image_tag" >/dev/null 2>&1 || true
    else
        BUILD_STATUS[$service]="failed"
        BUILD_TIMES[$service]=0
        IMAGE_SIZES[$service]="N/A"

        if [ "$OUTPUT_FORMAT" = "text" ]; then
            printf "${RED}FAILED${NC}\n"
        fi
    fi

    if [ "$OUTPUT_FORMAT" = "text" ]; then
        echo ""
    fi
done

# Calculate totals
TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))

# Count results
success_count=0
failed_count=0
for service in "${SERVICES[@]}"; do
    if [ "${BUILD_STATUS[$service]:-}" = "success" ]; then
        ((success_count++))
    elif [ "${BUILD_STATUS[$service]:-}" = "failed" ]; then
        ((failed_count++))
    fi
done

# Output results
if [ "$OUTPUT_FORMAT" = "json" ]; then
    # JSON output
    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"build_type\": \"$BUILD_TYPE\","
    echo "  \"total_time_seconds\": $TOTAL_TIME,"
    echo "  \"success_count\": $success_count,"
    echo "  \"failed_count\": $failed_count,"
    echo "  \"services\": {"

    first=true
    for service in "${SERVICES[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        printf "    \"%s\": {\n" "$service"
        printf "      \"status\": \"%s\",\n" "${BUILD_STATUS[$service]:-skipped}"
        printf "      \"build_time_seconds\": %s,\n" "${BUILD_TIMES[$service]:-0}"
        printf "      \"image_size\": \"%s\"\n" "${IMAGE_SIZES[$service]:-N/A}"
        printf "    }"
    done

    echo ""
    echo "  }"
    echo "}"
else
    # Text summary
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Build Summary${NC}"
    echo ""
    echo -e "  ${GREEN}✓ Successful:${NC} $success_count"
    echo -e "  ${RED}✗ Failed:${NC}     $failed_count"
    echo -e "  ${BLUE}Total time:${NC}   ${TOTAL_TIME}s"
    echo ""

    # Performance targets
    echo -e "${CYAN}Performance Targets${NC}"
    echo ""

    for service in "${SERVICES[@]}"; do
        if [ "${BUILD_STATUS[$service]:-}" = "success" ]; then
            time=${BUILD_TIMES[$service]}
            size=${IMAGE_SIZES[$service]}

            # Check against targets (60s for warm builds)
            if [ "$BUILD_TYPE" = "warm" ]; then
                target=60
            else
                target=300
            fi

            time_int=${time%.*}
            if [ "$time_int" -le "$target" ]; then
                time_status="${GREEN}✓${NC}"
            else
                time_status="${RED}✗${NC}"
            fi

            printf "  %s %-25s %6.1fs (target: <${target}s)  Size: %s\n" \
                "$time_status" "$service" "$time" "$size"
        fi
    done

    echo ""

    # Save report
    mkdir -p "$REPORTS_DIR"
    report_file="$REPORTS_DIR/build-times-$(date +%Y%m%d-%H%M%S).json"

    # Generate JSON report
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
        echo "  \"build_type\": \"$BUILD_TYPE\","
        echo "  \"total_time_seconds\": $TOTAL_TIME,"
        echo "  \"success_count\": $success_count,"
        echo "  \"failed_count\": $failed_count,"
        echo "  \"services\": {"

        first=true
        for service in "${SERVICES[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            printf "    \"%s\": {\n" "$service"
            printf "      \"status\": \"%s\",\n" "${BUILD_STATUS[$service]:-skipped}"
            printf "      \"build_time_seconds\": %s,\n" "${BUILD_TIMES[$service]:-0}"
            printf "      \"image_size\": \"%s\"\n" "${IMAGE_SIZES[$service]:-N/A}"
            printf "    }"
        done

        echo ""
        echo "  }"
        echo "}"
    } > "$report_file"

    echo -e "${GREEN}Report saved:${NC} $report_file"
fi

# Exit with failure if any builds failed
if [ "$failed_count" -gt 0 ]; then
    exit 1
fi
