# ==============================================================================
# Raymond - Go Utility Service
# Multi-stage build for minimal production image
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build
# ------------------------------------------------------------------------------
FROM golang:1.23-alpine3.19 AS builder

LABEL org.opencontainers.image.title="raymond (builder)" \
      org.opencontainers.image.description="Go utility service - build stage"

# Install build dependencies
RUN apk add --no-cache \
    ca-certificates \
    git \
    make

WORKDIR /app

# Copy go.mod and go.sum files to download dependencies
# This is done in a separate step to leverage Docker's layer caching
COPY go.mod go.sum ./

# Download dependencies with cache mount for faster rebuilds
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy the rest of the source code
COPY . .

# Build the Go application with cache mount for build cache
# CGO_ENABLED=0 creates a statically linked binary
# -ldflags="-w -s" strips debug information, reducing binary size
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux go build -a \
    -ldflags="-w -s -X main.version=1.0.0" \
    -o /app/raymond ./cmd/raymond

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM alpine:3.19

LABEL org.opencontainers.image.title="raymond" \
      org.opencontainers.image.description="Go utility service for A.R.C. Framework" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      arc.service.tier="utilities"

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    wget && \
    addgroup -g 1000 raymond && \
    adduser -D -u 1000 -G raymond raymond

# Copy the built binary from the 'builder' stage
COPY --from=builder /app/raymond /usr/local/bin/raymond

# Copy example config (can be overridden with volume mount)
COPY --chown=raymond:raymond config.example.yaml /etc/raymond/config.yaml

# Use non-root user
USER raymond

# Expose service port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=30s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1

# Command to run the executable
CMD ["raymond", "-config", "/etc/raymond/config.yaml"]
