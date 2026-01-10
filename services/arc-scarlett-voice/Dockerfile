# ==============================================================================
# arc-scarlett-voice Dockerfile
# LiveKit Voice Agent with Whisper STT, Sherlock LLM (NATS), and Piper TTS
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder (Install dependencies + download models)
# ------------------------------------------------------------------------------
FROM python:3.11-alpine3.19 AS builder

LABEL org.opencontainers.image.title="arc-scarlett-voice (builder)" \
      org.opencontainers.image.description="LiveKit voice agent - build stage" \
      arc.service.tier="services" \
      arc.service.category="voice-agent"

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    gcc \
    g++ \
    musl-dev \
    wget

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-warn-script-location -r requirements.txt

# Download Piper TTS model (en_US-lessac-medium, 22kHz, ~40MB)
RUN mkdir -p /build/models && \
    cd /build/models && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM python:3.11-alpine3.19

LABEL org.opencontainers.image.title="arc-scarlett-voice" \
      org.opencontainers.image.description="LiveKit voice agent with Whisper STT, Sherlock LLM (NATS), and embedded Piper TTS" \
      org.opencontainers.image.version="0.1.0" \
      arc.service.tier="services" \
      arc.service.category="voice-agent" \
      arc.service.role="realtime-interface" \
      arc.monitoring.enabled="true" \
      arc.monitoring.type="otel"

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    libgomp \
    libstdc++

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Copy Piper models from builder
COPY --from=builder /build/models /app/models

# Ensure Python packages are in PATH
ENV PATH=/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Copy application code
COPY src/ ./src/

# Create non-root user for security
RUN addgroup -g 1000 scarlett && \
    adduser -D -u 1000 -G scarlett scarlett && \
    chown -R scarlett:scarlett /app

USER scarlett

# Health check (basic process check - agent doesn't expose HTTP)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "python -m src.agent" || exit 1

# Default command: Run LiveKit agent
CMD ["python", "-m", "src.agent"]
