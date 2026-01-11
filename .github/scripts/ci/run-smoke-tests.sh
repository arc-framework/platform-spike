#!/bin/bash
#
# Run smoke tests against deployed services
#
# Usage:
#   ./run-smoke-tests.sh --env staging
#   ./run-smoke-tests.sh --env production --services "brain,gateway"
#   ./run-smoke-tests.sh --env staging --timeout 30 --output results.json
#
# Exit codes:
#   0: All tests passed
#   1: Some tests failed
#   2: Configuration error

set -euo pipefail

# Default values
ENV="staging"
TIMEOUT=10
OUTPUT=""
SERVICES=""
VERBOSE=false
BASE_URL=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --services)
            SERVICES="$2"
            shift 2
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --env ENV          Environment to test (staging, production)"
            echo "  --timeout SECONDS  HTTP timeout (default: 10)"
            echo "  --output FILE      Output JSON results file"
            echo "  --services LIST    Comma-separated service names to test"
            echo "  --base-url URL     Base URL override"
            echo "  --verbose          Show detailed output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

# Set base URL based on environment
if [ -z "$BASE_URL" ]; then
    case "$ENV" in
        staging)
            BASE_URL="https://staging.arc.example.com"
            ;;
        production)
            BASE_URL="https://arc.example.com"
            ;;
        local)
            BASE_URL="http://localhost:8080"
            ;;
        *)
            echo "Unknown environment: $ENV"
            exit 2
            ;;
    esac
fi

log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "$1"
    fi
}

log_result() {
    local name=$1
    local status=$2
    local duration=$3

    if [ "$status" = "pass" ]; then
        echo -e "${GREEN}✓${NC} $name (${duration}ms)"
    else
        echo -e "${RED}✗${NC} $name (${duration}ms)"
    fi
}

# Service health check endpoints
declare -A HEALTH_ENDPOINTS=(
    ["arc-sherlock-brain"]="/health"
    ["arc-heimdall-gateway"]="/api/http/routers"
    ["arc-jarvis-identity"]="/health/alive"
    ["arc-oracle-postgres"]="/health"
    ["arc-quicksilver-cache"]="/health"
    ["arc-watchtower-metrics"]="/-/healthy"
    ["arc-vision-dashboards"]="/api/health"
)

# Results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
RESULTS=()

# Run a single health check
run_health_check() {
    local service=$1
    local endpoint=$2
    local full_url="${BASE_URL}${endpoint}"

    local start_time=$(date +%s%3N)

    log "Testing: $service at $full_url"

    # Run curl with timeout
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        --connect-timeout 5 \
        "$full_url" 2>/dev/null || echo "000")

    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    TESTS_RUN=$((TESTS_RUN + 1))

    local status="fail"
    local message=""

    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        status="pass"
        message="OK"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$http_code" = "000" ]; then
        message="Connection failed or timeout"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        message="HTTP $http_code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    log_result "$service" "$status" "$duration"

    # Add to results
    RESULTS+=("{\"service\":\"$service\",\"endpoint\":\"$endpoint\",\"status\":\"$status\",\"http_code\":\"$http_code\",\"duration_ms\":$duration,\"message\":\"$message\"}")
}

# Run API smoke test
run_api_test() {
    local name=$1
    local method=$2
    local url=$3
    local expected_code=$4

    local start_time=$(date +%s%3N)

    log "API Test: $name - $method $url"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        --connect-timeout 5 \
        -X "$method" \
        "$url" 2>/dev/null || echo "000")

    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    TESTS_RUN=$((TESTS_RUN + 1))

    local status="fail"
    local message=""

    if [ "$http_code" = "$expected_code" ]; then
        status="pass"
        message="OK"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        message="Expected $expected_code, got $http_code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    log_result "$name" "$status" "$duration"

    RESULTS+=("{\"test\":\"$name\",\"method\":\"$method\",\"url\":\"$url\",\"status\":\"$status\",\"http_code\":\"$http_code\",\"expected\":\"$expected_code\",\"duration_ms\":$duration,\"message\":\"$message\"}")
}

echo "=========================================="
echo "A.R.C. Smoke Tests"
echo "=========================================="
echo "Environment: $ENV"
echo "Base URL: $BASE_URL"
echo "Timeout: ${TIMEOUT}s"
echo "=========================================="
echo ""

# Run health checks
echo "Running health checks..."
echo ""

if [ -n "$SERVICES" ]; then
    # Run specific services
    IFS=',' read -ra SERVICE_LIST <<< "$SERVICES"
    for service in "${SERVICE_LIST[@]}"; do
        service=$(echo "$service" | xargs)  # Trim whitespace
        if [ -n "${HEALTH_ENDPOINTS[$service]:-}" ]; then
            run_health_check "$service" "${HEALTH_ENDPOINTS[$service]}"
        else
            echo -e "${YELLOW}⚠${NC} Unknown service: $service"
        fi
    done
else
    # Run all services
    for service in "${!HEALTH_ENDPOINTS[@]}"; do
        run_health_check "$service" "${HEALTH_ENDPOINTS[$service]}"
    done
fi

echo ""

# Run API smoke tests
echo "Running API smoke tests..."
echo ""

run_api_test "Gateway - List routes" "GET" "${BASE_URL}/api/http/routers" "200"
run_api_test "Brain - Health" "GET" "${BASE_URL}/api/v1/health" "200"
run_api_test "Metrics - Ready" "GET" "${BASE_URL}/metrics/-/ready" "200"

echo ""
echo "=========================================="
echo "Results Summary"
echo "=========================================="
echo "Tests Run: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "=========================================="

# Generate JSON output
if [ -n "$OUTPUT" ]; then
    RESULTS_JSON=$(printf '%s\n' "${RESULTS[@]}" | jq -s '.')

    cat > "$OUTPUT" << EOF
{
  "environment": "$ENV",
  "base_url": "$BASE_URL",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "tests_run": $TESTS_RUN,
    "tests_passed": $TESTS_PASSED,
    "tests_failed": $TESTS_FAILED,
    "pass_rate": $(echo "scale=2; $TESTS_PASSED * 100 / $TESTS_RUN" | bc 2>/dev/null || echo "0")
  },
  "results": $RESULTS_JSON
}
EOF

    echo ""
    echo "Results written to: $OUTPUT"
fi

# Exit with appropriate code
if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi

exit 0
