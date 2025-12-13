#!/usr/bin/env bash
# Inspect A.R.C. Service Labels
# Usage: ./scripts/inspect-service.sh <container-name-or-codename>

if [ -z "$1" ]; then
    echo "Usage: $0 <container-name-or-codename>"
    echo ""
    echo "Examples:"
    echo "  $0 arc-oracle-sql"
    echo "  $0 oracle"
    echo "  $0 daredevil"
    exit 1
fi

SEARCH="$1"

# Try exact container name first
CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "^$SEARCH$|$SEARCH" | head -1)

if [ -z "$CONTAINER" ]; then
    # Try searching by codename label
    CONTAINER=$(docker ps --filter "label=arc.service.codename=$SEARCH" --format "{{.Names}}" | head -1)
fi

if [ -z "$CONTAINER" ]; then
    echo "❌ No running container found matching '$SEARCH'"
    echo ""
    echo "Try: make roster"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  🦸 SERVICE INFO: $CONTAINER"
echo "════════════════════════════════════════════════════════════"
echo ""

# Extract all arc.service labels
docker inspect "$CONTAINER" --format '{{range $k, $v := .Config.Labels}}{{if eq (index (split $k ".") 0) "arc"}}{{printf "  %-25s %s\n" $k $v}}{{end}}{{end}}' | sort

echo ""
echo "────────────────────────────────────────────────────────────"
echo "  Status: $(docker inspect "$CONTAINER" --format '{{.State.Status}}')"
echo "  Image:  $(docker inspect "$CONTAINER" --format '{{.Config.Image}}')"
echo "════════════════════════════════════════════════════════════"
echo ""
