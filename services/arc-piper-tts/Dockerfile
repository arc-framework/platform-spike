# ==============================================================================
# A.R.C. Piper TTS Service
# Multi-stage build for minimal production image
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder - Download models and build dependencies
# ------------------------------------------------------------------------------
FROM python:3.12-alpine3.19 AS builder

LABEL org.opencontainers.image.title="arc-piper-tts (builder)" \
      org.opencontainers.image.description="TTS service - build stage"

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    wget

# Download Piper TTS model
RUN mkdir -p /build/models && \
    cd /build/models && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx \
         -O en_US-lessac-medium.onnx && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json \
         -O en_US-lessac-medium.onnx.json

# Copy and install Python dependencies
WORKDIR /build/app

# Copy A.R.C. Common SDK first
COPY libs/python-sdk /build/libs/python-sdk

# Copy service requirements
COPY services/arc-piper-tts/requirements.txt .

# Install Python dependencies with cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -e /build/libs/python-sdk && \
    pip install --user --no-warn-script-location -r requirements.txt

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM python:3.12-alpine3.19

LABEL org.opencontainers.image.title="arc-piper-tts" \
      org.opencontainers.image.description="A.R.C. Text-to-Speech Service (Piper)" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      arc.service.role="tts" \
      arc.service.type="agent-utility"

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    libsndfile

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Copy models from builder
COPY --from=builder /build/models /app/models

# Copy service code
COPY services/arc-piper-tts/src ./src

# Ensure Python packages are in PATH
ENV PATH=/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Create non-root user
RUN addgroup -g 1000 arcuser && \
    adduser -D -u 1000 -G arcuser arcuser && \
    chown -R arcuser:arcuser /app

USER arcuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Run service
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
