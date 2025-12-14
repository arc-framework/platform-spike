#!/usr/bin/env bash
# ==============================================================================
# LiveKit JWT Token Generation Utility (T008)
# ==============================================================================
# Generates JWT tokens for LiveKit room access with proper grants
# Usage: ./generate-token.sh <room_name> <participant_name> [grants]
#
# Part of: A.R.C. Daredevil Real-Time Stack
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables from project root .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# Check required environment variables
if [[ -z "${LIVEKIT_API_KEY:-}" ]] || [[ -z "${LIVEKIT_API_SECRET:-}" ]]; then
    echo -e "${RED}Error: LIVEKIT_API_KEY and LIVEKIT_API_SECRET must be set in .env${NC}"
    exit 1
fi

# Validate secret length (must be ≥32 characters)
if [[ ${#LIVEKIT_API_SECRET} -lt 32 ]]; then
    echo -e "${RED}Error: LIVEKIT_API_SECRET must be at least 32 characters${NC}"
    echo -e "${YELLOW}Current length: ${#LIVEKIT_API_SECRET} characters${NC}"
    echo ""
    echo "Generate a new secret with:"
    echo "  openssl rand -base64 32"
    exit 1
fi

# Parse arguments
ROOM_NAME="${1:-test-room}"
PARTICIPANT_NAME="${2:-user-$(date +%s)}"
CAN_PUBLISH="${3:-true}"
CAN_SUBSCRIBE="${4:-true}"
CAN_PUBLISH_DATA="${5:-true}"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is required but not installed${NC}"
    exit 1
fi

# Check if livekit Python SDK is installed
if ! python3 -c "import livekit.api" 2>/dev/null; then
    echo -e "${YELLOW}Installing livekit-api Python package...${NC}"
    pip3 install -q livekit-api || {
        echo -e "${RED}Error: Failed to install livekit-api${NC}"
        echo "Install manually with: pip3 install livekit-api"
        exit 1
    }
fi

# Generate token using Python
TOKEN=$(python3 <<EOF
from livekit import api
import os

api_key = os.getenv("LIVEKIT_API_KEY")
api_secret = os.getenv("LIVEKIT_API_SECRET")

token = api.AccessToken(api_key, api_secret)
token.with_identity("$PARTICIPANT_NAME")
token.with_name("$PARTICIPANT_NAME")
token.with_grants(api.VideoGrants(
    room_join=True,
    room="$ROOM_NAME",
    can_publish=$CAN_PUBLISH,
    can_subscribe=$CAN_SUBSCRIBE,
    can_publish_data=$CAN_PUBLISH_DATA,
))

print(token.to_jwt())
EOF
)

# Display results
echo -e "${GREEN}✓ LiveKit Token Generated${NC}"
echo ""
echo "Room Name:        $ROOM_NAME"
echo "Participant:      $PARTICIPANT_NAME"
echo "Permissions:"
echo "  - Publish:      $CAN_PUBLISH"
echo "  - Subscribe:    $CAN_SUBSCRIBE"
echo "  - Publish Data: $CAN_PUBLISH_DATA"
echo ""
echo "Token (expires in 1 hour):"
echo "$TOKEN"
echo ""
echo "Connect to LiveKit:"
echo "  URL:   ws://livekit.arc.local (or ws://localhost:7880)"
echo "  Token: $TOKEN"
echo ""

# Optionally copy to clipboard (macOS)
if command -v pbcopy &> /dev/null; then
    echo "$TOKEN" | pbcopy
    echo -e "${GREEN}✓ Token copied to clipboard${NC}"
fi
