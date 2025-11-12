#!/bin/bash
# Diagnostic script for Infisical and Traefik health issues

set -e

echo "==================================================================="
echo "ARC Platform Health Diagnostics"
echo "==================================================================="
echo ""

echo "1. Checking Infisical Status..."
echo "-------------------------------------------------------------------"
docker ps -a --filter "name=arc_infisical" --format "Status: {{.Status}}"
echo ""
echo "Infisical Logs (last 20 lines):"
docker logs arc_infisical 2>&1 | tail -20
echo ""

echo "2. Checking Traefik Status..."
echo "-------------------------------------------------------------------"
docker ps -a --filter "name=arc_traefik" --format "Status: {{.Status}}"
echo ""
echo "Traefik Health Check:"
docker inspect arc_traefik --format '{{.State.Health.Status}}' 2>/dev/null || echo "No health check defined"
echo ""
echo "Testing Traefik ping endpoint:"
curl -v http://localhost:8080/ping 2>&1 | grep -E "(Connected|HTTP|404|200)" || echo "Ping failed"
echo ""

echo "3. Checking Postgres Connection..."
echo "-------------------------------------------------------------------"
docker exec arc_postgres psql -U arc -d arc_db -c "\dt" 2>&1 | head -20
echo ""

echo "4. Testing Infisical API endpoint..."
echo "-------------------------------------------------------------------"
curl -v http://localhost:3001/api/status 2>&1 | grep -E "(Connected|HTTP|404|200)" || echo "API check failed"
echo ""

echo "==================================================================="
echo "Diagnostics Complete"
echo "==================================================================="

