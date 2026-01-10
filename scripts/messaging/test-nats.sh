#!/usr/bin/env bash
# ==============================================================================
# A.R.C. Platform - NATS Testing Script
# ==============================================================================
# Task: T019
# Purpose: Test NATS pub/sub functionality for agent communication
# Usage: ./scripts/messaging/test-nats.sh [--publish|--subscribe|--full]
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
NATS_HOST="${NATS_HOST:-localhost}"
NATS_PORT="${NATS_PORT:-4222}"
NATS_URL="nats://${NATS_HOST}:${NATS_PORT}"
CONTAINER_NAME="${NATS_CONTAINER:-arc-flash-pulse}"

# Test subjects (from docs/architecture/NATS-SUBJECTS.md)
SUBJECTS=(
    "agent.voice.track.published"
    "agent.voice.track.unpublished"
    "agent.voice.session.started"
    "agent.voice.session.ended"
    "agent.brain.request"
    "agent.brain.response"
    "agent.brain.error"
    "agent.tts.request"
    "agent.tts.completed"
    "system.health.heartbeat"
)

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_subject() {
    echo -e "${CYAN}[SUBJECT]${NC} $1"
}

# ==============================================================================
# Validation
# ==============================================================================

check_nats_connection() {
    log_info "Testing NATS connection at $NATS_URL..."
    
    if ! docker exec "$CONTAINER_NAME" nats server info > /dev/null 2>&1; then
        log_error "Cannot connect to NATS server"
        log_info "Ensure NATS is running: docker ps | grep arc-flash-pulse"
        exit 1
    fi
    
    log_success "NATS server is reachable"
}

show_server_info() {
    log_info "NATS Server Information:"
    docker exec "$CONTAINER_NAME" nats server info --json | jq -r '
        "  Server ID: \(.server_id)",
        "  Version: \(.version)",
        "  Uptime: \(.uptime)",
        "  Connections: \(.connections)",
        "  Subscriptions: \(.subscriptions)",
        "  Messages In: \(.in_msgs)",
        "  Messages Out: \(.out_msgs)",
        "  Bytes In: \(.in_bytes | tonumber / 1024 / 1024 | floor)MB",
        "  Bytes Out: \(.out_bytes | tonumber / 1024 / 1024 | floor)MB"
    ' 2>/dev/null || {
        log_warning "Could not parse JSON (jq not installed?), showing raw output:"
        docker exec "$CONTAINER_NAME" nats server info
    }
}

# ==============================================================================
# Test Data Generation
# ==============================================================================

generate_track_published_event() {
    cat <<EOF
{
  "event": "track_published",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "trace_id": "$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "room_name": "room-test-$(date +%s)",
  "room_sid": "RM_TestRoom$(date +%s)",
  "participant_sid": "PA_TestUser$(date +%s)",
  "participant_identity": "test-user-001",
  "track_sid": "TR_TestTrack$(date +%s)",
  "track_kind": "audio",
  "track_source": "microphone",
  "metadata": {
    "user_id": "test-user-001",
    "session_id": "test-session-$(date +%s)"
  }
}
EOF
}

generate_brain_request() {
    cat <<EOF
{
  "request_id": "req-$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "trace_id": "$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "user_id": "test-user-001",
  "session_id": "test-session-$(date +%s)",
  "conversation_id": "test-conv-001",
  "turn_index": 0,
  "user_input": "Hello, this is a test message",
  "context": {
    "previous_turns": [],
    "user_profile": {
      "location": "Test Location"
    }
  },
  "constraints": {
    "max_tokens": 150,
    "temperature": 0.7,
    "timeout_ms": 2000
  }
}
EOF
}

generate_brain_response() {
    cat <<EOF
{
  "request_id": "req-$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "trace_id": "$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "user_id": "test-user-001",
  "session_id": "test-session-$(date +%s)",
  "conversation_id": "test-conv-001",
  "turn_index": 0,
  "agent_response": "Hello! This is a test response from the agent.",
  "metadata": {
    "llm_model": "test-model",
    "tokens_used": 12,
    "reasoning_steps": 1,
    "confidence_score": 0.95
  },
  "performance": {
    "llm_latency_ms": 250,
    "total_processing_ms": 300
  }
}
EOF
}

generate_heartbeat() {
    cat <<EOF
{
  "service": "test-service",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "status": "healthy",
  "metrics": {
    "active_sessions": 0,
    "cpu_percent": 10.5,
    "memory_mb": 128,
    "goroutines": 12
  }
}
EOF
}

# ==============================================================================
# Publishing Tests
# ==============================================================================

test_publish_single() {
    local subject="$1"
    local message="$2"
    
    log_subject "Publishing to: $subject"
    
    # Publish message using NATS CLI inside container
    if echo "$message" | docker exec -i "$CONTAINER_NAME" nats pub "$subject" --stdin > /dev/null 2>&1; then
        log_success "Published successfully"
        return 0
    else
        log_error "Publish failed"
        return 1
    fi
}

test_publish_all() {
    log_info "Testing message publishing to all subjects..."
    echo ""
    
    local success=0
    local failed=0
    
    # Test agent.voice.track.published
    if test_publish_single "agent.voice.track.published" "$(generate_track_published_event)"; then
        ((success++))
    else
        ((failed++))
    fi
    echo ""
    
    # Test agent.brain.request
    if test_publish_single "agent.brain.request" "$(generate_brain_request)"; then
        ((success++))
    else
        ((failed++))
    fi
    echo ""
    
    # Test agent.brain.response
    if test_publish_single "agent.brain.response" "$(generate_brain_response)"; then
        ((success++))
    else
        ((failed++))
    fi
    echo ""
    
    # Test system.health.heartbeat
    if test_publish_single "system.health.heartbeat" "$(generate_heartbeat)"; then
        ((success++))
    else
        ((failed++))
    fi
    echo ""
    
    log_info "Publish Summary:"
    log_success "  Successful: $success"
    if [[ $failed -gt 0 ]]; then
        log_error "  Failed: $failed"
    fi
}

# ==============================================================================
# Subscription Tests
# ==============================================================================

test_subscribe() {
    local subject="$1"
    local duration="${2:-10}"
    
    log_subject "Subscribing to: $subject (for $duration seconds)"
    log_info "Waiting for messages... (press Ctrl+C to stop early)"
    echo ""
    
    # Subscribe using NATS CLI with timeout
    timeout "$duration" docker exec "$CONTAINER_NAME" nats sub "$subject" 2>/dev/null || {
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo ""
            log_info "Subscription timeout reached"
        else
            echo ""
            log_warning "Subscription interrupted"
        fi
    }
}

test_subscribe_wildcard() {
    local pattern="$1"
    local duration="${2:-10}"
    
    log_subject "Subscribing to wildcard: $pattern (for $duration seconds)"
    log_info "Waiting for messages... (press Ctrl+C to stop early)"
    echo ""
    
    timeout "$duration" docker exec "$CONTAINER_NAME" nats sub "$pattern" 2>/dev/null || {
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo ""
            log_info "Subscription timeout reached"
        else
            echo ""
            log_warning "Subscription interrupted"
        fi
    }
}

# ==============================================================================
# Round-trip Test
# ==============================================================================

test_roundtrip() {
    log_info "Testing publish/subscribe round-trip..."
    echo ""
    
    local subject="agent.voice.track.published"
    local test_message
    test_message=$(generate_track_published_event)
    
    log_info "Step 1: Starting subscriber in background..."
    timeout 5 docker exec "$CONTAINER_NAME" nats sub "$subject" > /tmp/nats-test-output.txt 2>&1 &
    local sub_pid=$!
    
    sleep 1
    
    log_info "Step 2: Publishing test message..."
    test_publish_single "$subject" "$test_message"
    
    sleep 2
    
    log_info "Step 3: Checking if message was received..."
    if grep -q "track_published" /tmp/nats-test-output.txt 2>/dev/null; then
        log_success "Round-trip test PASSED - message received"
        echo ""
        log_info "Received message excerpt:"
        grep "track_published" /tmp/nats-test-output.txt | head -1
    else
        log_error "Round-trip test FAILED - message not received"
    fi
    
    # Cleanup
    kill $sub_pid 2>/dev/null || true
    rm -f /tmp/nats-test-output.txt
}

# ==============================================================================
# Interactive Menu
# ==============================================================================

show_menu() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         A.R.C. NATS Testing Suite (Task T019)             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) Show server info"
    echo "2) Publish test messages to all subjects"
    echo "3) Subscribe to specific subject"
    echo "4) Subscribe to wildcard pattern"
    echo "5) Run round-trip test (pub/sub)"
    echo "6) Monitor all agent events (agent.>)"
    echo "7) Monitor all brain events (agent.brain.>)"
    echo "8) Exit"
    echo ""
}

interactive_mode() {
    while true; do
        show_menu
        read -p "$(echo -e ${YELLOW}Choose option [1-8]:${NC} )" choice
        echo ""
        
        case $choice in
            1)
                show_server_info
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                test_publish_all
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                echo "Available subjects:"
                for subject in "${SUBJECTS[@]}"; do
                    echo "  - $subject"
                done
                echo ""
                read -p "Enter subject name: " subject
                read -p "Duration in seconds [10]: " duration
                duration=${duration:-10}
                test_subscribe "$subject" "$duration"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                echo "Example patterns:"
                echo "  - agent.> (all agent events)"
                echo "  - agent.voice.> (all voice events)"
                echo "  - agent.brain.> (all brain events)"
                echo "  - *.*.error (all errors)"
                echo ""
                read -p "Enter wildcard pattern: " pattern
                read -p "Duration in seconds [10]: " duration
                duration=${duration:-10}
                test_subscribe_wildcard "$pattern" "$duration"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                test_roundtrip
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                test_subscribe_wildcard "agent.>" 30
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                test_subscribe_wildcard "agent.brain.>" 30
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
    done
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    check_nats_connection
    
    case "${1:-interactive}" in
        --publish)
            test_publish_all
            ;;
        --subscribe)
            local subject="${2:-agent.>}"
            local duration="${3:-30}"
            test_subscribe_wildcard "$subject" "$duration"
            ;;
        --roundtrip)
            test_roundtrip
            ;;
        --info)
            show_server_info
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (none)               Interactive menu"
            echo "  --publish            Publish test messages to all subjects"
            echo "  --subscribe [PATTERN] [DURATION]  Subscribe to subject pattern"
            echo "  --roundtrip          Test publish/subscribe round-trip"
            echo "  --info               Show NATS server info"
            echo "  --help               Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                          # Interactive mode"
            echo "  $0 --publish                # Publish test messages"
            echo "  $0 --subscribe 'agent.>' 30 # Monitor all agent events for 30s"
            echo "  $0 --roundtrip              # Test round-trip latency"
            ;;
        interactive|*)
            interactive_mode
            ;;
    esac
}

main "$@"
