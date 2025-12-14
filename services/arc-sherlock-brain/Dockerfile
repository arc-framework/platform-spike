# ==============================================================================
# arc-sherlock-brain Dockerfile
# Multi-stage build for LangGraph reasoning engine
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder (Install dependencies)
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS builder

LABEL org.opencontainers.image.title="arc-sherlock-brain (builder)"
LABEL org.opencontainers.image.description="LangGraph reasoning engine with pgvector memory - build stage"
LABEL arc.service.tier="services"
LABEL arc.service.category="reasoning"

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM python:3.11-slim

LABEL org.opencontainers.image.title="arc-sherlock-brain"
LABEL org.opencontainers.image.description="LangGraph reasoning engine with pgvector memory and NATS integration"
LABEL org.opencontainers.image.version="0.1.0"
LABEL arc.service.tier="services"
LABEL arc.service.category="reasoning"
LABEL arc.service.role="brain"
LABEL arc.monitoring.enabled="true"
LABEL arc.monitoring.type="otel"

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Ensure Python packages are in PATH
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Create non-root user for security
RUN useradd -m -u 1000 sherlock && \
    chown -R sherlock:sherlock /app

USER sherlock

# Expose FastAPI port
EXPOSE 8000

# Health check for Docker
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command: Run FastAPI with Uvicorn
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]
