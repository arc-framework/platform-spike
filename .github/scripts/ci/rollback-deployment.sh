#!/bin/bash
#
# Rollback deployment to a previous version
#
# Usage:
#   ./rollback-deployment.sh --env production --version v1.0.0
#   ./rollback-deployment.sh --env staging --service arc-sherlock-brain --version v1.0.0
#   ./rollback-deployment.sh --env production --version v1.0.0 --dry-run
#
# Exit codes:
#   0: Rollback successful
#   1: Rollback failed
#   2: Configuration error

set -euo pipefail

# Default values
ENV=""
VERSION=""
SERVICE=""
DRY_RUN=false
WAIT_TIMEOUT=300
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --service)
            SERVICE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --timeout)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        --kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --env ENV          Environment (staging, production) [required]"
            echo "  --version VERSION  Version to rollback to (e.g., v1.0.0) [required]"
            echo "  --service SERVICE  Specific service to rollback (optional, all if omitted)"
            echo "  --dry-run          Show what would be done without making changes"
            echo "  --timeout SECONDS  Timeout for rollout wait (default: 300)"
            echo "  --kubeconfig PATH  Path to kubeconfig file"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

# Validate required arguments
if [ -z "$ENV" ]; then
    log_error "--env is required"
    exit 2
fi

if [ -z "$VERSION" ]; then
    log_error "--version is required"
    exit 2
fi

# Validate environment
case "$ENV" in
    staging|production)
        ;;
    *)
        log_error "Invalid environment: $ENV (must be staging or production)"
        exit 2
        ;;
esac

# Validate version format
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
    log_error "Invalid version format: $VERSION (expected vX.Y.Z)"
    exit 2
fi

echo "=========================================="
echo "A.R.C. Deployment Rollback"
echo "=========================================="
echo "Environment: $ENV"
echo "Target Version: $VERSION"
echo "Service: ${SERVICE:-all}"
echo "Dry Run: $DRY_RUN"
echo "=========================================="
echo ""

# Registry settings
REGISTRY="${GHCR_REGISTRY:-ghcr.io}"
IMAGE_PREFIX="${GITHUB_REPOSITORY:-arc-framework/platform-spike}"

# Namespace mapping
declare -A NAMESPACES=(
    ["staging"]="arc-staging"
    ["production"]="arc-production"
)
NAMESPACE="${NAMESPACES[$ENV]}"

# Service to deployment mapping
declare -A DEPLOYMENTS=(
    ["arc-sherlock-brain"]="brain-deployment"
    ["arc-heimdall-gateway"]="gateway-deployment"
    ["arc-jarvis-identity"]="identity-deployment"
    ["arc-mystique-flags"]="feature-flags-deployment"
    ["arc-oracle-postgres"]="postgres-statefulset"
    ["arc-quicksilver-cache"]="redis-deployment"
)

# Function to rollback a single service
rollback_service() {
    local service=$1
    local deployment="${DEPLOYMENTS[$service]:-$service-deployment}"
    local image="${REGISTRY}/${IMAGE_PREFIX}/${service}:${VERSION}"

    log_info "Rolling back $service to $VERSION..."
    log_info "  Deployment: $deployment"
    log_info "  Image: $image"

    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY RUN] Would execute:"
        echo "  kubectl set image deployment/$deployment $service=$image -n $NAMESPACE"
        echo "  kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=${WAIT_TIMEOUT}s"
        return 0
    fi

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        return 1
    fi

    # Set the image
    if ! kubectl set image "deployment/$deployment" "$service=$image" -n "$NAMESPACE" --kubeconfig="$KUBECONFIG_PATH" 2>/dev/null; then
        log_error "Failed to set image for $deployment"
        return 1
    fi

    log_info "Waiting for rollout to complete..."

    # Wait for rollout
    if kubectl rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout="${WAIT_TIMEOUT}s" --kubeconfig="$KUBECONFIG_PATH" 2>/dev/null; then
        log_success "$service rolled back successfully"
        return 0
    else
        log_error "$service rollback failed or timed out"
        return 1
    fi
}

# Function to verify service health after rollback
verify_health() {
    local service=$1
    local max_attempts=5
    local attempt=1

    log_info "Verifying $service health..."

    while [ $attempt -le $max_attempts ]; do
        # Get pod status
        local ready
        ready=$(kubectl get pods -l "app=$service" -n "$NAMESPACE" \
            --kubeconfig="$KUBECONFIG_PATH" \
            -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

        if [ "$ready" = "True" ]; then
            log_success "$service is healthy"
            return 0
        fi

        log_warning "$service not ready (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done

    log_error "$service health check failed after $max_attempts attempts"
    return 1
}

# Track results
ROLLBACK_SUCCESS=0
ROLLBACK_FAILED=0
FAILED_SERVICES=()

# Perform rollback
if [ -n "$SERVICE" ]; then
    # Single service rollback
    if rollback_service "$SERVICE"; then
        ROLLBACK_SUCCESS=$((ROLLBACK_SUCCESS + 1))
        if [ "$DRY_RUN" != true ]; then
            verify_health "$SERVICE" || log_warning "Health verification failed for $SERVICE"
        fi
    else
        ROLLBACK_FAILED=$((ROLLBACK_FAILED + 1))
        FAILED_SERVICES+=("$SERVICE")
    fi
else
    # All services rollback
    log_info "Rolling back all services..."
    echo ""

    for service in "${!DEPLOYMENTS[@]}"; do
        if rollback_service "$service"; then
            ROLLBACK_SUCCESS=$((ROLLBACK_SUCCESS + 1))
        else
            ROLLBACK_FAILED=$((ROLLBACK_FAILED + 1))
            FAILED_SERVICES+=("$service")
        fi
        echo ""
    done

    # Verify health for all services
    if [ "$DRY_RUN" != true ]; then
        log_info "Verifying health of all services..."
        for service in "${!DEPLOYMENTS[@]}"; do
            verify_health "$service" || log_warning "Health verification failed for $service"
        done
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "Rollback Summary"
echo "=========================================="
echo -e "Successful: ${GREEN}$ROLLBACK_SUCCESS${NC}"
echo -e "Failed: ${RED}$ROLLBACK_FAILED${NC}"

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo ""
    echo "Failed services:"
    for svc in "${FAILED_SERVICES[@]}"; do
        echo "  - $svc"
    done
fi

echo "=========================================="

# Generate JSON output for CI
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "rollback-success=$ROLLBACK_SUCCESS" >> "$GITHUB_OUTPUT"
    echo "rollback-failed=$ROLLBACK_FAILED" >> "$GITHUB_OUTPUT"
    echo "target-version=$VERSION" >> "$GITHUB_OUTPUT"
fi

# Exit code
if [ "$ROLLBACK_FAILED" -gt 0 ]; then
    log_error "Rollback completed with failures"
    exit 1
fi

log_success "Rollback completed successfully"
exit 0
