#!/usr/bin/env bash
# A.R.C. Service Roster - Show all services with their codenames and roles

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "                  🦸 A.R.C. SERVICE ROSTER 🦸"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Check if any containers are running
if ! docker ps --filter "label=arc.service.codename" --format "{{.ID}}" | grep -q .; then
    echo "⚠️  No A.R.C. services currently running."
    echo "   Run 'make up' to start the platform."
    echo ""
    exit 0
fi

# Show running services with their codenames and roles
docker ps --filter "label=arc.service.codename" \
    --format "table {{.Names}}\t{{.Label \"arc.service.codename\"}}\t{{.Label \"arc.service.role\"}}\t{{.Label \"arc.service.tech\"}}\t{{.Label \"arc.service.swappable\"}}\t{{.Status}}" \
    | awk 'BEGIN {FS="\t"; OFS="\t"}
    NR==1 {print "CONTAINER", "CODENAME", "ROLE", "TECH", "SWAP?", "STATUS"; print "───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"}
    NR>1 {printf "%-25s %-12s %-20s %-15s %-6s %s\n", $1, $2, $3, $4, $5, $6}'

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""
