#!/usr/bin/env bash
# Verify all A.R.C. services have complete label sets

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  🏷️  A.R.C. LABEL VERIFICATION"
echo "════════════════════════════════════════════════════════════"
echo ""

REQUIRED_LABELS=("codename" "role" "tech" "swappable")
FILES=(
    "deployments/docker/docker-compose.core.yml"
    "deployments/docker/docker-compose.observability.yml"
    "deployments/docker/docker-compose.security.yml"
    "deployments/docker/docker-compose.services.yml"
    "deployments/docker/docker-compose.production.yml"
)

TOTAL_ISSUES=0

for file in "${FILES[@]}"; do
    echo "📄 Checking: $(basename $file)"
    
    # Find all service definitions (codenames)
    SERVICES=$(grep -E "arc.service.codename=" "$file" | sed 's/.*codename=//' | tr -d '"' | sort -u)
    
    if [ -z "$SERVICES" ]; then
        echo "   ⚠️  No services with codenames found"
        echo ""
        continue
    fi
    
    for service in $SERVICES; do
        MISSING=()
        
        # Check each required label
        for label in "${REQUIRED_LABELS[@]}"; do
            if ! grep -q "arc.service.$label=$service" "$file" && \
               ! grep -A 3 "arc.service.codename=$service" "$file" | grep -q "arc.service.$label="; then
                MISSING+=("$label")
            fi
        done
        
        if [ ${#MISSING[@]} -eq 0 ]; then
            echo "   ✅ $service (complete)"
        else
            echo "   ❌ $service (missing: ${MISSING[*]})"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        fi
    done
    
    echo ""
done

echo "════════════════════════════════════════════════════════════"
if [ $TOTAL_ISSUES -eq 0 ]; then
    echo "  ✅ All services have complete label sets!"
else
    echo "  ⚠️  Found $TOTAL_ISSUES service(s) with incomplete labels"
fi
echo "════════════════════════════════════════════════════════════"
echo ""

exit $TOTAL_ISSUES
