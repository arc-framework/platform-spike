#!/bin/bash
# Detect which services changed based on git diff
#
# This script compares two git refs and outputs a JSON array of
# services that have changes, suitable for use in GitHub Actions matrix.
#
# Usage:
#   ./detect-changed-services.sh <base_ref> <head_ref>
#   ./detect-changed-services.sh origin/main HEAD
#   ./detect-changed-services.sh ${{ github.event.pull_request.base.sha }} ${{ github.sha }}
#
# Output:
#   JSON object with 'services' array and metadata
#
# Example output:
#   {
#     "services": [
#       {"name": "arc-sherlock-brain", "path": "services/arc-sherlock-brain", "type": "service"},
#       {"name": "arc-scarlett-voice", "path": "services/arc-scarlett-voice", "type": "service"}
#     ],
#     "count": 2,
#     "all_changed": false
#   }

set -euo pipefail

# Default values
BASE_REF="${1:-origin/main}"
HEAD_REF="${2:-HEAD}"

# Service directories to check
SERVICE_DIRS=(
  "services"
  "core"
  "plugins"
)

# Files that trigger all services to rebuild
GLOBAL_TRIGGERS=(
  "docker-compose*.yml"
  "Makefile"
  ".github/workflows/*"
  "requirements*.txt"
  "pyproject.toml"
)

log_info() { echo "[INFO] $*" >&2; }
log_debug() { echo "[DEBUG] $*" >&2; }

# Get list of changed files
get_changed_files() {
  git diff --name-only "$BASE_REF" "$HEAD_REF" 2>/dev/null || {
    # If diff fails (e.g., shallow clone), list all files
    log_info "Git diff failed, assuming all files changed"
    find . -type f -name "*.py" -o -name "Dockerfile" -o -name "*.yml" | sed 's|^\./||'
  }
}

# Check if any global trigger files changed
check_global_triggers() {
  local changed_files="$1"

  for pattern in "${GLOBAL_TRIGGERS[@]}"; do
    if echo "$changed_files" | grep -qE "^${pattern//\*/.*}$"; then
      return 0  # Global trigger found
    fi
  done
  return 1  # No global triggers
}

# Extract service name from path
get_service_name() {
  local path="$1"
  basename "$path"
}

# Detect service type from path
get_service_type() {
  local path="$1"

  if [[ "$path" == services/* ]]; then
    echo "service"
  elif [[ "$path" == core/* ]]; then
    echo "core"
  elif [[ "$path" == plugins/* ]]; then
    echo "plugin"
  else
    echo "unknown"
  fi
}

# Find services with Dockerfiles
find_all_services() {
  local services=()

  for dir in "${SERVICE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      # Find directories containing Dockerfile
      while IFS= read -r -d '' dockerfile; do
        local service_path=$(dirname "$dockerfile")
        local service_name=$(get_service_name "$service_path")
        local service_type=$(get_service_type "$service_path")

        services+=("{\"name\": \"$service_name\", \"path\": \"$service_path\", \"type\": \"$service_type\"}")
      done < <(find "$dir" -name "Dockerfile" -print0 2>/dev/null)
    fi
  done

  echo "${services[@]}"
}

# Find changed services
find_changed_services() {
  local changed_files="$1"
  local services=()
  local seen_services=()

  for dir in "${SERVICE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      # Get unique service directories from changed files
      while IFS= read -r file; do
        # Check if file is in this service directory
        if [[ "$file" == "$dir/"* ]]; then
          # Extract the service path (e.g., services/arc-sherlock-brain)
          local service_path=$(echo "$file" | cut -d'/' -f1-2)

          # Skip if we've already processed this service
          if [[ " ${seen_services[*]} " =~ " ${service_path} " ]]; then
            continue
          fi

          # Check if it has a Dockerfile (is a buildable service)
          if [ -f "$service_path/Dockerfile" ]; then
            local service_name=$(get_service_name "$service_path")
            local service_type=$(get_service_type "$service_path")

            services+=("{\"name\": \"$service_name\", \"path\": \"$service_path\", \"type\": \"$service_type\"}")
            seen_services+=("$service_path")
          fi
        fi
      done <<< "$changed_files"
    fi
  done

  echo "${services[@]}"
}

# Main
main() {
  log_info "Detecting changed services..."
  log_info "Base ref: $BASE_REF"
  log_info "Head ref: $HEAD_REF"

  # Get changed files
  CHANGED_FILES=$(get_changed_files)
  CHANGED_COUNT=$(echo "$CHANGED_FILES" | grep -c . || echo "0")
  log_info "Found $CHANGED_COUNT changed files"

  # Check for global triggers
  ALL_CHANGED=false
  if check_global_triggers "$CHANGED_FILES"; then
    log_info "Global trigger detected - all services will be rebuilt"
    ALL_CHANGED=true
    SERVICES=$(find_all_services)
  else
    SERVICES=$(find_changed_services "$CHANGED_FILES")
  fi

  # Build JSON output
  if [ -z "$SERVICES" ]; then
    # No services changed
    OUTPUT='{"services": [], "count": 0, "all_changed": false}'
  else
    # Convert space-separated JSON objects to array
    SERVICE_ARRAY=$(echo "$SERVICES" | tr ' ' '\n' | grep -v '^$' | paste -sd ',' -)
    SERVICE_COUNT=$(echo "$SERVICES" | tr ' ' '\n' | grep -c . || echo "0")

    OUTPUT="{\"services\": [$SERVICE_ARRAY], \"count\": $SERVICE_COUNT, \"all_changed\": $ALL_CHANGED}"
  fi

  # Pretty print and output
  echo "$OUTPUT" | jq '.'
}

main "$@"
