# ==============================================================================
# A.R.C. Framework - OpenTelemetry Collector
# ==============================================================================
# Multi-stage build for health check utility and collector
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build the health_check utility
# ------------------------------------------------------------------------------
FROM golang:1.23-alpine AS health_checker

WORKDIR /src

# Copy only the health check source
COPY ./health_check/main.go .

# Initialize a minimal go.mod for this standalone program
RUN go mod init health_check

# Build a statically-linked, minimal binary
# CGO_ENABLED=0 for static linking, -w -s to strip debug info
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o /health_check .

# ------------------------------------------------------------------------------
# Stage 2: Final collector image
# ------------------------------------------------------------------------------
FROM otel/opentelemetry-collector-contrib:0.98.0

LABEL org.opencontainers.image.title="arc-otel-collector" \
      org.opencontainers.image.description="OpenTelemetry Collector for A.R.C. Framework" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      arc.service.layer="core" \
      arc.service.role="telemetry"

# Copy the compiled health_check binary from the first stage
COPY --from=health_checker /health_check /health_check

# The base image already sets up the entrypoint and user
