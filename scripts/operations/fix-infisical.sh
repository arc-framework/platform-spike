#!/bin/bash
# Fix Infisical database issues
# This script creates the infisical_db database and restarts the service

set -e

echo "==================================================================="
echo "Fixing Infisical Database Issues"
echo "==================================================================="
echo ""

echo "Step 1: Creating infisical_db database..."
docker exec arc_postgres psql -U arc -c "CREATE DATABASE infisical_db;" 2>&1 || {
    echo "Database might already exist, checking..."
    docker exec arc_postgres psql -U arc -c "\l" | grep infisical_db && echo "✓ Database exists"
}
echo ""

echo "Step 2: Stopping Infisical container..."
docker stop arc_infisical 2>&1 || echo "Container already stopped"
echo ""

echo "Step 3: Removing Infisical container..."
docker rm arc_infisical 2>&1 || echo "Container already removed"
echo ""

echo "Step 4: Starting Infisical with new configuration..."
cd /Users/dgtalbug/Workspace/arc/platform-spike
docker-compose -f deployments/docker/docker-compose.base.yml -f deployments/docker/docker-compose.core.yml up -d arc_infisical
echo ""

echo "Step 5: Waiting for Infisical to initialize (this may take up to 60 seconds)..."
for i in {1..60}; do
    if docker ps | grep -q "arc_infisical.*Up"; then
        if curl -sf http://localhost:3001/api/status >/dev/null 2>&1; then
            echo ""
            echo "✓ Infisical is healthy and ready!"
            echo ""
            echo "You can now access Infisical at: http://localhost:3001"
            exit 0
        fi
    fi
    printf "."
    sleep 1
done

echo ""
echo ""
echo "⚠ Infisical is still starting up. Check status with:"
echo "  docker logs -f arc_infisical"
echo "  docker ps | grep infisical"
echo ""

