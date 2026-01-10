# ==============================================================================
# arc-sherlock-brain Dockerfile
# Multi-stage build for LangGraph reasoning engine
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder (Install dependencies)
# ------------------------------------------------------------------------------
FROM python:3.11-alpine3.19 AS builder

LABEL org.opencontainers.image.title="arc-sherlock-brain (builder)" \
      org.opencontainers.image.description="LangGraph reasoning engine with pgvector memory - build stage" \
      arc.service.tier="services" \
      arc.service.category="reasoning"

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    gcc \
    g++ \
    musl-dev \
    postgresql-dev

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -r requirements.txt

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM python:3.11-alpine3.19

LABEL org.opencontainers.image.title="arc-sherlock-brain" \
      org.opencontainers.image.description="LangGraph reasoning engine with pgvector memory and NATS integration" \
      org.opencontainers.image.version="0.1.0" \
      arc.service.tier="services" \
      arc.service.category="reasoning" \
      arc.service.role="brain" \
      arc.monitoring.enabled="true" \
      arc.monitoring.type="otel"

WORKDIR /app

# Install runtime dependencies only
RUN apk add --no-cache \
    curl \
    libpq \
    libgomp \
    libstdc++

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Ensure Python packages are in PATH
ENV PATH=/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Create non-root user for security
RUN addgroup -g 1000 sherlock && \
    adduser -D -u 1000 -G sherlock sherlock && \
    chown -R sherlock:sherlock /app

USER sherlock

# Expose FastAPI port
EXPOSE 8000

# Health check for Docker
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

# Default command: Run FastAPI with Uvicorn
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]
