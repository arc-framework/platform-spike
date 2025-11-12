#!/usr/bin/env bash

# =============================================================================
# A.R.C. Framework - Generate Secrets
# =============================================================================
# Generates secure random secrets and creates a .env file
# =============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"

echo "==================================================================="
echo "A.R.C. Framework - Generate Secrets"
echo "==================================================================="
echo ""

# Check if .env already exists
if [[ -f "${ENV_FILE}" ]]; then
    echo -e "${YELLOW}WARNING: .env file already exists!${NC}"
    echo ""
    read -p "Overwrite existing .env file? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Aborted. Existing .env file preserved."
        exit 0
    fi
    # Backup existing file
    cp "${ENV_FILE}" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓ Backed up existing .env file${NC}"
    echo ""
fi

# Check if .env.example exists
if [[ ! -f "${ENV_EXAMPLE}" ]]; then
    echo "ERROR: .env.example not found!"
    exit 1
fi

echo "Generating secure secrets..."
echo ""

# Generate secrets

# Core database password
# Use -hex for passwords to ensure they are URL-safe for connection strings.
POSTGRES_PASSWORD=$(openssl rand -hex 32)

# Secrets management (Infisical)
# Based on official documentation:
# ENCRYPTION_KEY must be a 16-byte hex string.
# AUTH_SECRET must be a 32-byte base64 string.
INFISICAL_ENCRYPTION_KEY=$(openssl rand -hex 16)
INFISICAL_AUTH_SECRET=$(openssl rand -base64 32 | tr -d '\n')

# Feature management (Unleash)
# API token for server-to-server communication and a client token for applications.
UNLEASH_API_TOKEN="*:*.$(openssl rand -hex 32)"
UNLEASH_CLIENT_TOKEN="*:*.$(openssl rand -hex 32)"

# Observability (Grafana)
# Initial admin password for the Grafana user interface.
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

# Identity & Authentication (Kratos)
# Secrets for securing session cookies and internal cryptographic operations.
KRATOS_SECRET_COOKIE=$(openssl rand -base64 32 | tr -d '\n')
KRATOS_SECRET_CIPHER=$(openssl rand -base64 32 | tr -d '\n')

# Create .env file
cat > "${ENV_FILE}" << EOF
# =============================================================================
# A.R.C. Framework - Environment Configuration
# =============================================================================
# Generated: $(date)
# WARNING: This file contains sensitive secrets - never commit to version control!
# =============================================================================

# -----------------------------------------------------------------------------
# Core Services - PostgreSQL Database
# -----------------------------------------------------------------------------
POSTGRES_USER=arc
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=arc_db

# -----------------------------------------------------------------------------
# Secrets Management - Infisical
# -----------------------------------------------------------------------------
INFISICAL_ENCRYPTION_KEY=${INFISICAL_ENCRYPTION_KEY}
INFISICAL_AUTH_SECRET="${INFISICAL_AUTH_SECRET}"
INFISICAL_SITE_URL=http://localhost:3001

# -----------------------------------------------------------------------------
# Feature Management - Unleash
# -----------------------------------------------------------------------------
UNLEASH_API_TOKEN=${UNLEASH_API_TOKEN}
UNLEASH_CLIENT_TOKEN=${UNLEASH_CLIENT_TOKEN}

# -----------------------------------------------------------------------------
# Observability - Grafana
# -----------------------------------------------------------------------------
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}

# -----------------------------------------------------------------------------
# Identity & Authentication - Kratos
# -----------------------------------------------------------------------------
KRATOS_SECRET_COOKIE=${KRATOS_SECRET_COOKIE}
KRATOS_SECRET_CIPHER=${KRATOS_SECRET_CIPHER}

# -----------------------------------------------------------------------------
# Application Services
# -----------------------------------------------------------------------------
SWISS_ARMY_PORT=8080
LOG_LEVEL=info

# -----------------------------------------------------------------------------
# OpenTelemetry Configuration (Optional Overrides)
# =============================================================================
# OTEL_EXPORTER_OTLP_ENDPOINT=arc_otel_collector:4317
# OTEL_EXPORTER_OTLP_INSECURE=true
EOF

echo -e "${GREEN}✓ Generated .env file with secure secrets${NC}"
echo ""
echo "==================================================================="
echo "Credentials Summary"
echo "==================================================================="
echo ""
echo -e "${BLUE}PostgreSQL:${NC}"
echo "  User: arc"
echo "  Password: ${POSTGRES_PASSWORD:0:10}..."
echo "  Database: arc_db"
echo ""
echo -e "${BLUE}Grafana:${NC}"
echo "  URL: http://localhost:3000"
echo "  User: admin"
echo "  Password: ${GRAFANA_ADMIN_PASSWORD:0:10}..."
echo ""
echo -e "${BLUE}Infisical:${NC}"
echo "  URL: http://localhost:3001"
echo "  Encryption Key: ${INFISICAL_ENCRYPTION_KEY:0:10}..."
echo ""
echo "==================================================================="
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "  • All credentials are stored in .env file"
echo "  • Keep this file secure and never commit it to version control"
echo "  • Full credentials can be viewed in: ${ENV_FILE}"
echo ""
echo "Next steps:"
echo "  1. Review the .env file"
echo "  2. Run: make up"
echo "  3. Access services using the credentials above"
echo ""
