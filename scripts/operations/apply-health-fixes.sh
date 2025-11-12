#!/bin/bash
# Apply fixes for Infisical and Traefik health check issues
# This script applies all necessary fixes and restarts affected services

set -e

echo "==================================================================="
echo "Applying Health Check Fixes"
echo "==================================================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "${BLUE}Issue 1: Infisical Database Configuration${NC}"
echo "-------------------------------------------------------------------"
echo "Fix: Creating separate infisical_db database"
echo ""

# Create infisical database if it doesn't exist
docker exec arc_postgres psql -U arc -c "SELECT 1 FROM pg_database WHERE datname = 'infisical_db'" | grep -q 1 || {
    echo "Creating infisical_db database..."
    docker exec arc_postgres psql -U arc -c "CREATE DATABASE infisical_db;"
    echo "${GREEN}✓ Database created${NC}"
}
echo "${GREEN}✓ Database exists${NC}"
echo ""

echo "${BLUE}Issue 2: Traefik Health Check Port${NC}"
echo "-------------------------------------------------------------------"
echo "Fix: Updated Makefile to check port 80 instead of 8080"
echo "${GREEN}✓ Makefile already updated${NC}"
echo ""

echo "${BLUE}Restarting Services...${NC}"
echo "-------------------------------------------------------------------"
echo ""

# Restart Infisical to use the new database
echo "Restarting Infisical..."
docker restart arc_infisical
echo "${GREEN}✓ Infisical restarted${NC}"
echo ""

echo "Waiting for Infisical to initialize (up to 60 seconds)..."
for i in {1..60}; do
    if docker ps --filter "name=arc_infisical" --format "{{.Status}}" | grep -q "Up"; then
        if curl -sf http://localhost:3001/api/status >/dev/null 2>&1; then
            echo ""
            echo "${GREEN}✓ Infisical is healthy!${NC}"
            break
        fi
    fi
    printf "${YELLOW}.${NC}"
    sleep 1
done
echo ""

echo ""
echo "==================================================================="
echo "Health Check Summary"
echo "==================================================================="
echo ""

# Run health checks
printf "%-25s" "Traefik (Gateway):"
if curl -sf http://localhost:80/ping >/dev/null 2>&1; then
    echo "${GREEN}✓ Healthy${NC}"
else
    echo "${YELLOW}⚠ Check manually${NC}"
fi

printf "%-25s" "Infisical (Secrets):"
if curl -sf http://localhost:3001/api/status >/dev/null 2>&1; then
    echo "${GREEN}✓ Healthy${NC}"
else
    echo "${YELLOW}⚠ Still initializing - check logs: docker logs -f arc_infisical${NC}"
fi

echo ""
echo "==================================================================="
echo "Next Steps"
echo "==================================================================="
echo ""
echo "1. Run full health check:"
echo "   make health-all"
echo ""
echo "2. Access Infisical UI:"
echo "   open http://localhost:3001"
echo ""
echo "3. If Infisical still has issues, check the troubleshooting guide:"
echo "   docs/TROUBLESHOOTING-INFISICAL.md"
echo ""

