#!/usr/bin/env bash
# ==============================================================================
# A.R.C. Platform - Pulsar Testing Script
# ==============================================================================
# Purpose: Test Pulsar pub/sub functionality for durable event streaming
# Usage: ./scripts/messaging/test-pulsar.sh [--publish|--consume|--full]
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
PULSAR_HOST="${PULSAR_HOST:-localhost}"
PULSAR_PORT="${PULSAR_PORT:-6650}"
PULSAR_HTTP_PORT="${PULSAR_HTTP_PORT:-8080}"
PULSAR_URL="pulsar://${PULSAR_HOST}:${PULSAR_PORT}"
CONTAINER_NAME="${PULSAR_CONTAINER:-arc-strange-stream}"

# Test topics (from docs/architecture/PULSAR-TOPICS.md)
TENANT="arc"
NAMESPACES=("events" "analytics" "audit")
TOPICS=(
    "persistent://${TENANT}/events/conversation"
    "persistent://${TENANT}/events/agent-lifecycle"
    "persistent://${TENANT}/events/livekit-webhooks"
    "persistent://${TENANT}/analytics/session-metrics"
    "persistent://${TENANT}/analytics/agent-performance"
    "persistent://${TENANT}/audit/compliance-events"
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

log_topic() {
    echo -e "${CYAN}[TOPIC]${NC} $1"
}

# ==============================================================================
# Validation
# ==============================================================================

check_pulsar_connection() {
    log_info "Testing Pulsar connection at $PULSAR_URL..."
    
    if ! docker exec "$CONTAINER_NAME" bin/pulsar-admin brokers healthcheck > /dev/null 2>&1; then
        log_error "Cannot connect to Pulsar cluster"
        log_info "Ensure Pulsar is running: docker ps | grep arc-strange-stream"
        exit 1
    fi
    
    log_success "Pulsar cluster is healthy"
}

show_cluster_info() {
    log_info "Pulsar Cluster Information:"
    
    echo ""
    log_info "Brokers:"
    docker exec "$CONTAINER_NAME" bin/pulsar-admin brokers list arc-cluster 2>/dev/null || \
        log_warning "Could not list brokers"
    
    echo ""
    log_info "Tenants:"
    docker exec "$CONTAINER_NAME" bin/pulsar-admin tenants list 2>/dev/null || \
        log_warning "Could not list tenants"
    
    echo ""
    log_info "Namespaces:"
    docker exec "$CONTAINER_NAME" bin/pulsar-admin namespaces list "$TENANT" 2>/dev/null || \
        log_warning "Tenant '$TENANT' may not exist yet"
}

# ==============================================================================
# Setup Functions
# ==============================================================================

setup_tenant_and_namespaces() {
    log_info "Setting up tenant and namespaces..."
    
    # Create tenant
    if docker exec "$CONTAINER_NAME" bin/pulsar-admin tenants create "$TENANT" \
        --allowed-clusters arc-cluster 2>/dev/null; then
        log_success "Tenant '$TENANT' created"
    else
        log_warning "Tenant '$TENANT' already exists or creation failed"
    fi
    
    # Create namespaces
    for namespace in "${NAMESPACES[@]}"; do
        local full_namespace="${TENANT}/${namespace}"
        if docker exec "$CONTAINER_NAME" bin/pulsar-admin namespaces create "$full_namespace" 2>/dev/null; then
            log_success "Namespace '$full_namespace' created"
            
            # Set retention policy based on namespace
            case $namespace in
                events)
                    docker exec "$CONTAINER_NAME" bin/pulsar-admin namespaces set-retention \
                        "$full_namespace" --size 100G --time 30d 2>/dev/null
                    log_info "  Retention: 30 days, 100GB"
                    ;;
                analytics)
                    docker exec "$CONTAINER_NAME" bin/pulsar-admin namespaces set-retention \
                        "$full_namespace" --size 200G --time 90d 2>/dev/null
                    log_info "  Retention: 90 days, 200GB"
                    ;;
                audit)
                    docker exec "$CONTAINER_NAME" bin/pulsar-admin namespaces set-retention \
                        "$full_namespace" --size 500G --time 2555d 2>/dev/null  # ~7 years
                    log_info "  Retention: 7 years, 500GB"
                    ;;
            esac
        else
            log_warning "Namespace '$full_namespace' already exists or creation failed"
        fi
    done
}

# ==============================================================================
# Test Data Generation
# ==============================================================================

generate_conversation_event() {
    cat <<EOF
{
  "schema": "conversation-v1",
  "message_id": "msg-$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "event_type": "conversation_turn_completed",
  "conversation": {
    "id": "conv-test-$(date +%s)",
    "session_id": "session-test-$(date +%s)",
    "user_id": "test-user-001",
    "agent_id": "arc-scarlett-voice",
    "turn_index": 0
  },
  "user_message": {
    "text": "Hello, this is a test message",
    "audio_duration_ms": 1200,
    "stt_model": "whisper-large-v3",
    "stt_confidence": 0.98,
    "stt_latency_ms": 150
  },
  "agent_response": {
    "text": "Hello! This is a test response from the agent.",
    "llm_model": "gpt-4-turbo",
    "llm_tokens_used": 25,
    "llm_latency_ms": 450,
    "tts_model": "piper-en_US-lessac-medium",
    "tts_audio_duration_ms": 1500,
    "tts_latency_ms": 200
  },
  "performance": {
    "total_latency_ms": 800,
    "stt_latency_ms": 150,
    "llm_latency_ms": 450,
    "tts_latency_ms": 200
  }
}
EOF
}

generate_session_metrics() {
    cat <<EOF
{
  "schema": "session-metrics-v1",
  "message_id": "msg-$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "event_type": "session_ended",
  "session": {
    "id": "session-test-$(date +%s)",
    "user_id": "test-user-001",
    "agent_id": "arc-scarlett-voice",
    "room_name": "room-test-$(date +%s)",
    "duration_seconds": 300
  },
  "conversation_stats": {
    "total_turns": 12,
    "user_messages": 12,
    "agent_messages": 12,
    "avg_turn_length_words": 18,
    "total_tokens_used": 540
  },
  "performance_metrics": {
    "avg_latency_ms": 750,
    "p50_latency_ms": 700,
    "p95_latency_ms": 1200,
    "p99_latency_ms": 1500,
    "sla_compliance_percent": 95.5
  }
}
EOF
}

generate_lifecycle_event() {
    cat <<EOF
{
  "schema": "agent-lifecycle-v1",
  "message_id": "msg-$(uuidgen | tr '[:upper:]' '[:lower:]')",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "event_type": "service_started",
  "service": {
    "name": "arc-scarlett-voice",
    "instance_id": "test-instance-$(date +%s)",
    "version": "v1.0.0-test"
  },
  "event_details": {
    "type": "started",
    "reason": "test_execution",
    "current_state": "running"
  }
}
EOF
}

# ==============================================================================
# Publishing Tests
# ==============================================================================

test_publish_single() {
    local topic="$1"
    local message="$2"
    
    log_topic "Publishing to: $topic"
    
    # Publish using Pulsar CLI
    if echo "$message" | docker exec -i "$CONTAINER_NAME" bin/pulsar-client produce \
        "$topic" \
        --stdin \
        --messages - > /dev/null 2>&1; then
        log_success "Published successfully"
        return 0
    else
        log_error "Publish failed"
        return 1
    fi
}

test_publish_all() {
    log_info "Testing message publishing to all topics..."
    echo ""
    
    local success=0
    local failed=0
    
    # Test conversation event
    if test_publish_single "persistent://${TENANT}/events/conversation" "$(generate_conversation_event)"; then
        ((success++))
    else
        ((failed++))
    fi
    echo ""
    
    # Test session metrics
    if test_publish_single "persistent://${TENANT}/analytics/session-metrics" "$(generate_session_metrics)"; then
        ((success++))
    else
        ((failed++))
    fi
    echo ""
    
    # Test lifecycle event
    if test_publish_single "persistent://${TENANT}/events/agent-lifecycle" "$(generate_lifecycle_event)"; then
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
# Consumption Tests
# ==============================================================================

test_consume() {
    local topic="$1"
    local num_messages="${2:-10}"
    
    log_topic "Consuming from: $topic (max $num_messages messages)"
    log_info "Waiting for messages..."
    echo ""
    
    docker exec "$CONTAINER_NAME" bin/pulsar-client consume \
        "$topic" \
        --subscription-name "test-consumer-$(date +%s)" \
        --num-messages "$num_messages" \
        --subscription-type Shared 2>/dev/null || {
        log_warning "No messages available or consumption interrupted"
    }
}

test_peek() {
    local topic="$1"
    local num_messages="${2:-5}"
    
    log_topic "Peeking at: $topic (max $num_messages messages)"
    echo ""
    
    docker exec "$CONTAINER_NAME" bin/pulsar-admin topics peek-messages \
        "$topic" \
        --count "$num_messages" \
        --subscription "test-peek-$(date +%s)" 2>/dev/null || {
        log_warning "Could not peek messages (topic may not exist or be empty)"
    }
}

# ==============================================================================
# Topic Management
# ==============================================================================

list_topics() {
    log_info "Listing all topics in tenant '$TENANT':"
    echo ""
    
    for namespace in "${NAMESPACES[@]}"; do
        local full_namespace="${TENANT}/${namespace}"
        echo -e "${CYAN}Namespace: $full_namespace${NC}"
        docker exec "$CONTAINER_NAME" bin/pulsar-admin topics list "$full_namespace" 2>/dev/null || \
            log_warning "Could not list topics in $full_namespace"
        echo ""
    done
}

show_topic_stats() {
    local topic="$1"
    
    log_topic "Statistics for: $topic"
    echo ""
    
    docker exec "$CONTAINER_NAME" bin/pulsar-admin topics stats "$topic" 2>/dev/null || {
        log_error "Could not get stats for topic (may not exist)"
        return 1
    }
}

# ==============================================================================
# Round-trip Test
# ==============================================================================

test_roundtrip() {
    log_info "Testing publish/consume round-trip..."
    echo ""
    
    local topic="persistent://${TENANT}/events/conversation"
    local test_message
    test_message=$(generate_conversation_event)
    
    log_info "Step 1: Publishing test message..."
    if ! test_publish_single "$topic" "$test_message"; then
        log_error "Round-trip test FAILED - could not publish"
        return 1
    fi
    
    sleep 1
    
    log_info "Step 2: Consuming message..."
    if docker exec "$CONTAINER_NAME" bin/pulsar-client consume \
        "$topic" \
        --subscription-name "roundtrip-test-$(date +%s)" \
        --num-messages 1 \
        --subscription-type Exclusive 2>&1 | grep -q "conversation-v1"; then
        log_success "Round-trip test PASSED - message received"
    else
        log_error "Round-trip test FAILED - message not received"
    fi
}

# ==============================================================================
# Interactive Menu
# ==============================================================================

show_menu() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        A.R.C. Pulsar Testing Suite (Task T019)            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) Show cluster info"
    echo "2) Setup tenant and namespaces"
    echo "3) List all topics"
    echo "4) Publish test messages to all topics"
    echo "5) Consume from specific topic"
    echo "6) Peek at messages (non-destructive)"
    echo "7) Show topic statistics"
    echo "8) Run round-trip test (pub/consume)"
    echo "9) Exit"
    echo ""
}

interactive_mode() {
    while true; do
        show_menu
        read -p "$(echo -e ${YELLOW}Choose option [1-9]:${NC} )" choice
        echo ""
        
        case $choice in
            1)
                show_cluster_info
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                setup_tenant_and_namespaces
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                list_topics
                read -p "Press Enter to continue..."
                ;;
            4)
                test_publish_all
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo "Available topics:"
                for topic in "${TOPICS[@]}"; do
                    echo "  - $topic"
                done
                echo ""
                read -p "Enter topic URL: " topic
                read -p "Number of messages to consume [10]: " num_messages
                num_messages=${num_messages:-10}
                test_consume "$topic" "$num_messages"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                echo "Available topics:"
                for topic in "${TOPICS[@]}"; do
                    echo "  - $topic"
                done
                echo ""
                read -p "Enter topic URL: " topic
                read -p "Number of messages to peek [5]: " num_messages
                num_messages=${num_messages:-5}
                test_peek "$topic" "$num_messages"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                echo "Available topics:"
                for topic in "${TOPICS[@]}"; do
                    echo "  - $topic"
                done
                echo ""
                read -p "Enter topic URL: " topic
                show_topic_stats "$topic"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                test_roundtrip
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
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
    check_pulsar_connection
    
    case "${1:-interactive}" in
        --setup)
            setup_tenant_and_namespaces
            ;;
        --publish)
            test_publish_all
            ;;
        --consume)
            local topic="${2:-persistent://${TENANT}/events/conversation}"
            local num_messages="${3:-10}"
            test_consume "$topic" "$num_messages"
            ;;
        --list)
            list_topics
            ;;
        --stats)
            local topic="${2:-persistent://${TENANT}/events/conversation}"
            show_topic_stats "$topic"
            ;;
        --roundtrip)
            test_roundtrip
            ;;
        --info)
            show_cluster_info
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (none)                  Interactive menu"
            echo "  --setup                 Setup tenant and namespaces"
            echo "  --publish               Publish test messages to all topics"
            echo "  --consume [TOPIC] [NUM] Consume messages from topic"
            echo "  --list                  List all topics"
            echo "  --stats [TOPIC]         Show topic statistics"
            echo "  --roundtrip             Test publish/consume round-trip"
            echo "  --info                  Show cluster info"
            echo "  --help                  Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Interactive mode"
            echo "  $0 --setup                            # Create tenant/namespaces"
            echo "  $0 --publish                          # Publish test messages"
            echo "  $0 --consume 'persistent://arc/events/conversation' 5"
            echo "  $0 --roundtrip                        # Test round-trip"
            ;;
        interactive|*)
            interactive_mode
            ;;
    esac
}

main "$@"
