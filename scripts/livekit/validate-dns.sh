#!/usr/bin/env bash
# ==============================================================================
# DNS Validation Check for LiveKit (T009)
# ==============================================================================
# Validates that livekit.arc.local resolves to 127.0.0.1
# Automatically adds entry if missing (requires sudo)
#
# Part of: A.R.C. Daredevil Real-Time Stack
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HOSTNAME="livekit.arc.local"
TARGET_IP="127.0.0.1"

echo "Checking DNS configuration for $HOSTNAME..."
echo ""

# Check if entry exists in /etc/hosts
if grep -q "$HOSTNAME" /etc/hosts 2>/dev/null; then
    # Check if it points to correct IP
    CURRENT_IP=$(grep "$HOSTNAME" /etc/hosts | awk '{print $1}' | head -1)
    
    if [[ "$CURRENT_IP" == "$TARGET_IP" ]]; then
        echo -e "${GREEN}✓ DNS entry exists and is correct${NC}"
        echo "  $TARGET_IP  $HOSTNAME"
        
        # Verify resolution
        if ping -c 1 -t 1 "$HOSTNAME" &>/dev/null; then
            echo -e "${GREEN}✓ Hostname resolves successfully${NC}"
        else
            echo -e "${YELLOW}⚠ Hostname exists but ping failed (may be normal)${NC}"
        fi
        exit 0
    else
        echo -e "${YELLOW}⚠ DNS entry exists but points to wrong IP${NC}"
        echo "  Current: $CURRENT_IP"
        echo "  Expected: $TARGET_IP"
        echo ""
        echo "Fix manually with:"
        echo "  sudo sed -i '' \"/$HOSTNAME/d\" /etc/hosts"
        echo "  echo \"$TARGET_IP  $HOSTNAME\" | sudo tee -a /etc/hosts"
        exit 1
    fi
else
    echo -e "${RED}✗ DNS entry missing${NC}"
    echo ""
    echo "Would you like to add it now? (requires sudo)"
    echo "  $TARGET_IP  $HOSTNAME"
    echo ""
    read -p "Add entry? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$TARGET_IP  $HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
        echo -e "${GREEN}✓ DNS entry added${NC}"
        
        # Verify
        if grep -q "$HOSTNAME" /etc/hosts; then
            echo -e "${GREEN}✓ Verification successful${NC}"
            echo ""
            echo "LiveKit should now be accessible at:"
            echo "  http://livekit.arc.local"
            echo "  ws://livekit.arc.local"
        else
            echo -e "${RED}✗ Verification failed${NC}"
            exit 1
        fi
    else
        echo "Add manually with:"
        echo "  echo \"$TARGET_IP  $HOSTNAME\" | sudo tee -a /etc/hosts"
        exit 1
    fi
fi
