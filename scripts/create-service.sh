#!/usr/bin/env bash
# ==============================================================================
# A.R.C. Platform - Service Generator
# ==============================================================================
# Purpose: Scaffold a new service with all required files
# Usage: ./scripts/create-service.sh --name arc-analytics --tier services --lang python
# Exit: 0=success, 1=error
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults
SERVICE_NAME=""
SERVICE_TIER="services"
SERVICE_LANG="python"
SERVICE_CODENAME=""
SERVICE_DESCRIPTION=""
DRY_RUN=false

# Usage
usage() {
    echo "Usage: $0 --name <name> [options]"
    echo ""
    echo "Scaffold a new A.R.C. service with all required files."
    echo ""
    echo "Required:"
    echo "  --name <name>       Service name (e.g., arc-analytics, arc-stark-analyst)"
    echo ""
    echo "Options:"
    echo "  --tier <tier>       Service tier: core, plugins, services (default: services)"
    echo "  --lang <lang>       Language: python, go (default: python)"
    echo "  --codename <name>   Codename for the service (e.g., stark, jarvis)"
    echo "  --desc <text>       Short description of the service"
    echo "  --dry-run           Show what would be created without creating"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --name arc-stark-analyst --lang python --codename stark"
    echo "  $0 --name arc-vision-agent --tier services --lang python --codename vision"
    echo "  $0 --name arc-metrics-exporter --tier plugins --lang go"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --tier)
            SERVICE_TIER="$2"
            shift 2
            ;;
        --lang)
            SERVICE_LANG="$2"
            shift 2
            ;;
        --codename)
            SERVICE_CODENAME="$2"
            shift 2
            ;;
        --desc)
            SERVICE_DESCRIPTION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$SERVICE_NAME" ]; then
    echo -e "${RED}Error: --name is required${NC}"
    echo "Use --help for usage information."
    exit 1
fi

# Validate tier
case "$SERVICE_TIER" in
    core|plugins|services)
        ;;
    *)
        echo -e "${RED}Error: Invalid tier '$SERVICE_TIER'. Must be: core, plugins, or services${NC}"
        exit 1
        ;;
esac

# Validate language
case "$SERVICE_LANG" in
    python|go)
        ;;
    *)
        echo -e "${RED}Error: Invalid language '$SERVICE_LANG'. Must be: python or go${NC}"
        exit 1
        ;;
esac

# Extract codename from name if not provided
if [ -z "$SERVICE_CODENAME" ]; then
    # Try to extract from arc-{codename}-{function} pattern
    if [[ "$SERVICE_NAME" =~ ^arc-([a-z]+)-.*$ ]]; then
        SERVICE_CODENAME="${BASH_REMATCH[1]}"
    else
        SERVICE_CODENAME="${SERVICE_NAME#arc-}"
    fi
fi

# Set default description if not provided
if [ -z "$SERVICE_DESCRIPTION" ]; then
    SERVICE_DESCRIPTION="A.R.C. $SERVICE_NAME service"
fi

# Determine service directory
SERVICE_DIR="$REPO_ROOT/$SERVICE_TIER/$SERVICE_NAME"

# Check if service already exists
if [ -d "$SERVICE_DIR" ]; then
    echo -e "${RED}Error: Service directory already exists: $SERVICE_DIR${NC}"
    exit 1
fi

# Header
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          A.R.C. Platform - Service Generator                      ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Service Name:${NC}     $SERVICE_NAME"
echo -e "${BLUE}Tier:${NC}             $SERVICE_TIER"
echo -e "${BLUE}Language:${NC}         $SERVICE_LANG"
echo -e "${BLUE}Codename:${NC}         $SERVICE_CODENAME"
echo -e "${BLUE}Description:${NC}      $SERVICE_DESCRIPTION"
echo -e "${BLUE}Directory:${NC}        $SERVICE_DIR"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would create the following structure:${NC}"
    echo ""
fi

# Create directory structure
create_dir() {
    local dir="$1"
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${BLUE}mkdir${NC} $dir"
    else
        mkdir -p "$dir"
        echo -e "  ${GREEN}✓${NC} Created: $dir"
    fi
}

# Create file
create_file() {
    local file="$1"
    local content="$2"
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${BLUE}create${NC} $file"
    else
        echo "$content" > "$file"
        echo -e "  ${GREEN}✓${NC} Created: $file"
    fi
}

# Generate Python Dockerfile
generate_python_dockerfile() {
    cat << 'EOF'
# ==============================================================================
# A.R.C. Platform - Python Service Dockerfile
# ==============================================================================
# Constitution Compliance: Security by Default (Principle VIII)
# Generated by: scripts/create-service.sh
# ==============================================================================

# Build stage
FROM ghcr.io/arc/base-python-ai:3.11-alpine3.19 AS builder

WORKDIR /build

# Install dependencies (cached layer)
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -r requirements.txt

# Production stage
FROM ghcr.io/arc/base-python-ai:3.11-alpine3.19

# Copy dependencies from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy application code
WORKDIR /app
COPY src/ ./src/

# Security: Create non-root user (Constitution VIII)
RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser && \
    chown -R arcuser:arcuser /app

# Switch to non-root user
USER arcuser

# Health check (Constitution VII)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://localhost:8000/health || exit 1

# OCI Labels
LABEL org.opencontainers.image.title="SERVICE_NAME_PLACEHOLDER" \
      org.opencontainers.image.description="SERVICE_DESC_PLACEHOLDER" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      arc.service.codename="CODENAME_PLACEHOLDER" \
      arc.service.tier="TIER_PLACEHOLDER"

# Default port
EXPOSE 8000

# Run the application
CMD ["python", "-m", "src.main"]
EOF
}

# Generate Go Dockerfile
generate_go_dockerfile() {
    cat << 'EOF'
# ==============================================================================
# A.R.C. Platform - Go Service Dockerfile
# ==============================================================================
# Constitution Compliance: Security by Default (Principle VIII)
# Generated by: scripts/create-service.sh
# ==============================================================================

# Build stage
FROM golang:1.21-alpine3.19 AS builder

WORKDIR /build

# Install dependencies (cached layer)
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# Build the application
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o app ./cmd/main.go

# Production stage
FROM alpine:3.19

# Install ca-certificates for HTTPS
RUN apk add --no-cache ca-certificates wget

# Copy the binary
COPY --from=builder /build/app /app

# Security: Create non-root user (Constitution VIII)
RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser

# Switch to non-root user
USER arcuser

# Health check (Constitution VII)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:8080/health || exit 1

# OCI Labels
LABEL org.opencontainers.image.title="SERVICE_NAME_PLACEHOLDER" \
      org.opencontainers.image.description="SERVICE_DESC_PLACEHOLDER" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      arc.service.codename="CODENAME_PLACEHOLDER" \
      arc.service.tier="TIER_PLACEHOLDER"

# Default port
EXPOSE 8080

# Run the application
ENTRYPOINT ["/app"]
EOF
}

# Generate README
generate_readme() {
    local lang="$1"
    local port="8000"
    [ "$lang" = "go" ] && port="8080"

    cat << EOF
# $SERVICE_NAME

**Codename:** $SERVICE_CODENAME
**Tier:** $SERVICE_TIER
**Language:** $SERVICE_LANG

## Description

$SERVICE_DESCRIPTION

## Quick Start

### Prerequisites

- Docker 24.0+
- Make

### Build

\`\`\`bash
# Build the image
docker build -t $SERVICE_NAME:local .

# Or use make from repo root
make build-$SERVICE_NAME
\`\`\`

### Run

\`\`\`bash
# Run with Docker
docker run -p $port:$port $SERVICE_NAME:local

# Check health
curl http://localhost:$port/health
\`\`\`

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| \`PORT\` | Service port | $port |
| \`LOG_LEVEL\` | Logging level | info |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| \`/health\` | GET | Health check |
| \`/ready\` | GET | Readiness check |

## Development

\`\`\`bash
# Install dependencies
$([ "$lang" = "python" ] && echo "pip install -r requirements.txt" || echo "go mod download")

# Run locally
$([ "$lang" = "python" ] && echo "python -m src.main" || echo "go run cmd/main.go")

# Run tests
$([ "$lang" = "python" ] && echo "pytest tests/" || echo "go test ./...")
\`\`\`

## Related Documentation

- [Docker Standards](../../docs/standards/DOCKER-STANDARDS.md)
- [Service Categorization](../../docs/architecture/SERVICE-CATEGORIZATION.md)
- [SERVICE.MD](../../SERVICE.MD)
EOF
}

# Generate Python source files
generate_python_source() {
    # __init__.py
    create_file "$SERVICE_DIR/src/__init__.py" '"""'"$SERVICE_NAME"' - '"$SERVICE_DESCRIPTION"'."""

__version__ = "1.0.0"
'

    # main.py
    create_file "$SERVICE_DIR/src/main.py" '"""'"$SERVICE_NAME"' - Main entry point."""

import logging
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO").upper())
logger = logging.getLogger(__name__)


class HealthHandler(BaseHTTPRequestHandler):
    """Simple health check handler."""

    def do_GET(self):
        """Handle GET requests."""
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'"'"'"'{"status": "healthy", "service": "'"$SERVICE_NAME"'"}'"'"'"')
        elif self.path == "/ready":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'"'"'"'{"status": "ready"}'"'"'"')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        """Override to use Python logging."""
        logger.info("%s - %s", self.address_string(), format % args)


def main():
    """Run the service."""
    port = int(os.getenv("PORT", "8000"))
    server = HTTPServer(("0.0.0.0", port), HealthHandler)
    logger.info("Starting '"$SERVICE_NAME"' on port %d", port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
'

    # requirements.txt
    create_file "$SERVICE_DIR/requirements.txt" '# '"$SERVICE_NAME"' dependencies
# Add your dependencies here
'
}

# Generate Go source files
generate_go_source() {
    # go.mod
    create_file "$SERVICE_DIR/go.mod" "module github.com/arc-framework/$SERVICE_NAME

go 1.21
"

    # go.sum (empty initially)
    create_file "$SERVICE_DIR/go.sum" ""

    # cmd/main.go
    create_file "$SERVICE_DIR/cmd/main.go" 'package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

type HealthResponse struct {
	Status  string `json:"status"`
	Service string `json:"service,omitempty"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(HealthResponse{
		Status:  "healthy",
		Service: "'"$SERVICE_NAME"'",
	})
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(HealthResponse{Status: "ready"})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/ready", readyHandler)

	log.Printf("Starting '"$SERVICE_NAME"' on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
'
}

# Generate .dockerignore
generate_dockerignore() {
    local lang="$1"
    if [ "$lang" = "python" ]; then
        cat << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
.pytest_cache/
.mypy_cache/
.ruff_cache/
*.egg-info/
dist/
build/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Environment
.env
.env.*
*.local

# Testing
tests/
htmlcov/
.coverage

# Documentation
*.md
!README.md
docs/

# Git
.git/
.github/
.gitignore
EOF
    else
        cat << 'EOF'
# Go
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*_test.go
vendor/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Environment
.env
.env.*

# Documentation
*.md
!README.md
docs/

# Git
.git/
.github/
.gitignore
EOF
    fi
}

# Create the service
echo -e "${CYAN}Creating service structure...${NC}"
echo ""

# Create directories
create_dir "$SERVICE_DIR"
[ "$SERVICE_LANG" = "python" ] && create_dir "$SERVICE_DIR/src"
[ "$SERVICE_LANG" = "go" ] && create_dir "$SERVICE_DIR/cmd"

# Generate Dockerfile
if [ "$DRY_RUN" = false ]; then
    if [ "$SERVICE_LANG" = "python" ]; then
        generate_python_dockerfile | \
            sed "s/SERVICE_NAME_PLACEHOLDER/$SERVICE_NAME/g" | \
            sed "s/SERVICE_DESC_PLACEHOLDER/$SERVICE_DESCRIPTION/g" | \
            sed "s/CODENAME_PLACEHOLDER/$SERVICE_CODENAME/g" | \
            sed "s/TIER_PLACEHOLDER/$SERVICE_TIER/g" > "$SERVICE_DIR/Dockerfile"
    else
        generate_go_dockerfile | \
            sed "s/SERVICE_NAME_PLACEHOLDER/$SERVICE_NAME/g" | \
            sed "s/SERVICE_DESC_PLACEHOLDER/$SERVICE_DESCRIPTION/g" | \
            sed "s/CODENAME_PLACEHOLDER/$SERVICE_CODENAME/g" | \
            sed "s/TIER_PLACEHOLDER/$SERVICE_TIER/g" > "$SERVICE_DIR/Dockerfile"
    fi
    echo -e "  ${GREEN}✓${NC} Created: $SERVICE_DIR/Dockerfile"
else
    echo -e "  ${BLUE}create${NC} $SERVICE_DIR/Dockerfile"
fi

# Generate README
if [ "$DRY_RUN" = false ]; then
    generate_readme "$SERVICE_LANG" > "$SERVICE_DIR/README.md"
    echo -e "  ${GREEN}✓${NC} Created: $SERVICE_DIR/README.md"
else
    echo -e "  ${BLUE}create${NC} $SERVICE_DIR/README.md"
fi

# Generate .dockerignore
if [ "$DRY_RUN" = false ]; then
    generate_dockerignore "$SERVICE_LANG" > "$SERVICE_DIR/.dockerignore"
    echo -e "  ${GREEN}✓${NC} Created: $SERVICE_DIR/.dockerignore"
else
    echo -e "  ${BLUE}create${NC} $SERVICE_DIR/.dockerignore"
fi

# Generate source files
if [ "$SERVICE_LANG" = "python" ]; then
    generate_python_source
else
    generate_go_source
fi

echo ""

# Summary
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] No files were created.${NC}"
    echo -e "${YELLOW}Run without --dry-run to create the service.${NC}"
else
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ✅ SERVICE CREATED                             ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo ""
    echo "  1. Add your service to SERVICE.MD:"
    echo "     | $SERVICE_NAME | \`$SERVICE_NAME\` | CORE | \`./$SERVICE_TIER/$SERVICE_NAME\` | **$SERVICE_CODENAME** | $SERVICE_DESCRIPTION |"
    echo ""
    echo "  2. Add to docker-compose.services.yml (if applicable)"
    echo ""
    echo "  3. Build and test:"
    echo "     cd $SERVICE_DIR"
    echo "     docker build -t $SERVICE_NAME:local ."
    echo "     docker run -p $([ "$SERVICE_LANG" = "python" ] && echo "8000:8000" || echo "8080:8080") $SERVICE_NAME:local"
    echo ""
    echo "  4. Run validation:"
    echo "     ./scripts/validate/validate-all.sh"
    echo ""
fi
