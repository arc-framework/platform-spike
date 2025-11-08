#!/usr/bin/env bash

# =============================================================================
# A.R.C. Framework - Secrets Validation Script
# =============================================================================
# Validates that all required secrets and passwords are set before deployment
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

echo "==================================================================="
echo "A.R.C. Framework - Secrets Validation"
echo "==================================================================="
echo ""

# Check if .env file exists
if [[ ! -f "${ENV_FILE}" ]]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo ""
    echo "Please create .env file from template:"
    echo "  cp .env.example .env"
    echo ""
    exit 1
fi

# Source the .env file
set -a
source "${ENV_FILE}"
set +a

ERRORS=0
WARNINGS=0

# Function to validate a variable is set and not a placeholder
validate_secret() {
    local var_name=$1
    local var_value=${!var_name:-}
    local placeholder_pattern=$2

    if [[ -z "${var_value}" ]]; then
        echo -e "${RED}✗ ${var_name} is not set${NC}"
        ((ERRORS++))
        return 1
    fi

    if [[ "${var_value}" =~ ${placeholder_pattern} ]]; then
        echo -e "${RED}✗ ${var_name} contains placeholder value${NC}"
        ((ERRORS++))
        return 1
    fi

    echo -e "${GREEN}✓ ${var_name} is set${NC}"
    return 0
}

# Function to validate minimum length
validate_length() {
    local var_name=$1
    local var_value=${!var_name:-}
    local min_length=$2

    if [[ ${#var_value} -lt ${min_length} ]]; then
        echo -e "${YELLOW}⚠ ${var_name} is shorter than recommended (${#var_value} < ${min_length} chars)${NC}"
        ((WARNINGS++))
        return 1
    fi

    return 0
}

echo "Validating required secrets..."
echo ""

# Validate PostgreSQL password
echo "PostgreSQL Database:"
validate_secret "POSTGRES_PASSWORD" "CHANGE_ME|postgres|password123"
if [[ $? -eq 0 ]]; then
    validate_length "POSTGRES_PASSWORD" 16
fi
echo ""

# Validate Infisical secrets
echo "Infisical Secrets Management:"
validate_secret "INFISICAL_ENCRYPTION_KEY" "CHANGE_ME|change-this"
if [[ $? -eq 0 ]]; then
    validate_length "INFISICAL_ENCRYPTION_KEY" 32
fi
validate_secret "INFISICAL_AUTH_SECRET" "CHANGE_ME|change-this"
if [[ $? -eq 0 ]]; then
    validate_length "INFISICAL_AUTH_SECRET" 32
fi
echo ""

# Validate Unleash tokens
echo "Unleash Feature Management:"
validate_secret "UNLEASH_API_TOKEN" "CHANGE_ME|unleash-insecure"
if [[ $? -eq 0 ]]; then
    validate_length "UNLEASH_API_TOKEN" 32
fi
validate_secret "UNLEASH_CLIENT_TOKEN" "CHANGE_ME|unleash-insecure"
if [[ $? -eq 0 ]]; then
    validate_length "UNLEASH_CLIENT_TOKEN" 32
fi
echo ""

# Validate Grafana password
echo "Grafana Observability:"
validate_secret "GRAFANA_ADMIN_PASSWORD" "CHANGE_ME|admin|password"
if [[ $? -eq 0 ]]; then
    validate_length "GRAFANA_ADMIN_PASSWORD" 16
fi
echo ""

# Validate Kratos secrets
echo "Kratos Identity & Authentication:"
validate_secret "KRATOS_SECRET_COOKIE" "CHANGE_ME|INSECURE"
if [[ $? -eq 0 ]]; then
    validate_length "KRATOS_SECRET_COOKIE" 32
fi
validate_secret "KRATOS_SECRET_CIPHER" "CHANGE_ME|NOT-SECURE"
if [[ $? -eq 0 ]]; then
    validate_length "KRATOS_SECRET_CIPHER" 32
fi
echo ""

# Summary
echo "==================================================================="
echo "Validation Summary"
echo "==================================================================="
echo ""

if [[ ${ERRORS} -eq 0 ]]; then
    echo -e "${GREEN}✓ All required secrets are properly configured${NC}"
else
    echo -e "${RED}✗ ${ERRORS} error(s) found - please fix before deployment${NC}"
fi

if [[ ${WARNINGS} -gt 0 ]]; then
    echo -e "${YELLOW}⚠ ${WARNINGS} warning(s) - consider using longer secrets${NC}"
fi

echo ""

if [[ ${ERRORS} -gt 0 ]]; then
    echo "To generate secure secrets, use these commands:"
    echo ""
    echo "  # For passwords (32 chars):"
    echo "  openssl rand -base64 32"
    echo ""
    echo "  # For tokens (64 hex chars):"
    echo "  openssl rand -hex 32"
    echo ""
    exit 1
fi

exit 0

