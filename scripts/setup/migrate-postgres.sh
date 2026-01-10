#!/usr/bin/env bash
# ==============================================================================
# A.R.C. Platform - PostgreSQL Migration Runner
# ==============================================================================
# Purpose: Run database migrations with pgvector validation
# Usage: ./scripts/setup/migrate-postgres.sh [--rollback]
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="${POSTGRES_CONTAINER:-arc-oracle-sql}"
DB_NAME="${POSTGRES_DB:-arc_db}"
DB_USER="${POSTGRES_USER:-arc}"
MIGRATION_DIR="core/persistence/postgres/migrations"

# Script directory (for resolving paths)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================================================
# Validation Functions
# ==============================================================================

check_container() {
    log_info "Checking if PostgreSQL container is running..."
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "PostgreSQL container '${CONTAINER_NAME}' is not running"
        log_info "Start it with: make health-core"
        exit 1
    fi
    log_success "Container is running"
}

check_pgvector() {
    log_info "Checking pgvector extension availability..."
    
    local result
    result=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT count(*) FROM pg_available_extensions WHERE name='vector';")
    
    if [[ "$result" != "1" ]]; then
        log_error "pgvector extension is not available"
        log_info "Install it in the Dockerfile or init script"
        exit 1
    fi
    
    log_success "pgvector extension is available"
}

install_pgvector() {
    log_info "Installing pgvector extension..."
    
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c \
        "CREATE EXTENSION IF NOT EXISTS vector;" || {
        log_error "Failed to install pgvector extension"
        exit 1
    }
    
    # Verify installation
    local version
    version=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT extversion FROM pg_extension WHERE extname='vector';")
    
    if [[ -z "$version" ]]; then
        log_error "pgvector installation verification failed"
        exit 1
    fi
    
    log_success "pgvector extension installed (version: $version)"
}

# ==============================================================================
# Migration Functions
# ==============================================================================

list_migrations() {
    log_info "Available migrations in $MIGRATION_DIR:"
    
    cd "$REPO_ROOT"
    
    if [[ ! -d "$MIGRATION_DIR" ]]; then
        log_error "Migration directory not found: $MIGRATION_DIR"
        exit 1
    fi
    
    local count=0
    while IFS= read -r -d '' file; do
        echo "  - $(basename "$file")"
        ((count++))
    done < <(find "$MIGRATION_DIR" -name "*.sql" -type f -print0 | sort -z)
    
    log_info "Found $count migration file(s)"
}

run_migration() {
    local migration_file="$1"
    local filename
    filename=$(basename "$migration_file")
    
    log_info "Running migration: $filename"
    
    # Copy migration file to container
    docker cp "$migration_file" "${CONTAINER_NAME}:/tmp/${filename}"
    
    # Execute migration
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -f "/tmp/${filename}" || {
        log_error "Migration failed: $filename"
        return 1
    }
    
    # Clean up temp file
    docker exec "$CONTAINER_NAME" rm "/tmp/${filename}"
    
    log_success "Migration completed: $filename"
}

run_all_migrations() {
    log_info "Running all migrations..."
    
    cd "$REPO_ROOT"
    
    local success_count=0
    local fail_count=0
    
    while IFS= read -r -d '' file; do
        if run_migration "$file"; then
            ((success_count++))
        else
            ((fail_count++))
            log_error "Stopping migration process due to error"
            break
        fi
    done < <(find "$MIGRATION_DIR" -name "*.sql" -type f -print0 | sort -z)
    
    echo ""
    log_info "Migration Summary:"
    log_success "  Successful: $success_count"
    if [[ $fail_count -gt 0 ]]; then
        log_error "  Failed: $fail_count"
        exit 1
    fi
}

verify_schema() {
    log_info "Verifying agents schema..."
    
    # Check if schema exists
    local schema_exists
    schema_exists=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT count(*) FROM information_schema.schemata WHERE schema_name='agents';")
    
    if [[ "$schema_exists" != "1" ]]; then
        log_error "agents schema not found"
        return 1
    fi
    
    # Check if conversations table exists
    local table_exists
    table_exists=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT count(*) FROM information_schema.tables WHERE table_schema='agents' AND table_name='conversations';")
    
    if [[ "$table_exists" != "1" ]]; then
        log_error "agents.conversations table not found"
        return 1
    fi
    
    # Check if sessions table exists
    table_exists=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT count(*) FROM information_schema.tables WHERE table_schema='agents' AND table_name='sessions';")
    
    if [[ "$table_exists" != "1" ]]; then
        log_error "agents.sessions table not found"
        return 1
    fi
    
    # Check for vector column
    local vector_column
    vector_column=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT data_type FROM information_schema.columns WHERE table_schema='agents' AND table_name='conversations' AND column_name='embedding';")
    
    if [[ "$vector_column" != "USER-DEFINED" ]]; then
        log_warning "embedding column type unexpected: $vector_column (expected: USER-DEFINED for vector type)"
    fi
    
    log_success "Schema verification passed"
    
    # Display table info
    echo ""
    log_info "agents.conversations columns:"
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c \
        "\d agents.conversations" | grep -E "Column|Type|embedding|user_id|session_id"
    
    echo ""
    log_info "agents.sessions columns:"
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c \
        "\d agents.sessions" | grep -E "Column|Type|room_name|user_id|status"
}

show_stats() {
    log_info "Database statistics:"
    
    docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
        FROM pg_tables
        WHERE schemaname = 'agents'
        ORDER BY tablename;
    "
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      A.R.C. PostgreSQL Migration Runner (Task T016)       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Pre-flight checks
    check_container
    check_pgvector
    install_pgvector
    
    echo ""
    list_migrations
    
    echo ""
    read -p "$(echo -e ${YELLOW}Run all migrations? [y/N]:${NC} )" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Migration cancelled by user"
        exit 0
    fi
    
    echo ""
    run_all_migrations
    
    echo ""
    verify_schema
    
    echo ""
    show_stats
    
    echo ""
    log_success "✓ All migrations completed successfully!"
    echo ""
    log_info "Next steps:"
    echo "  1. Test conversation insert: docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c \"INSERT INTO agents.conversations (user_id, user_input, agent_response) VALUES ('test-user', 'Hello', 'Hi there!');\""
    echo "  2. Query conversations: docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c \"SELECT * FROM agents.conversations;\""
    echo "  3. Continue to Phase 2 Task T017 (NATS subjects documentation)"
}

# Handle script arguments
case "${1:-}" in
    --list)
        check_container
        list_migrations
        ;;
    --verify)
        check_container
        verify_schema
        ;;
    --stats)
        check_container
        show_stats
        ;;
    --help)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  (none)    Run all migrations interactively"
        echo "  --list    List available migrations"
        echo "  --verify  Verify schema after migration"
        echo "  --stats   Show database statistics"
        echo "  --help    Show this help message"
        ;;
    *)
        main
        ;;
esac
