# ==============================================================================
# arc-scarlett-voice Dockerfile
# LiveKit Voice Agent with Whisper STT, Sherlock LLM (NATS), and Piper TTS
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder (Install dependencies + download models)
# ------------------------------------------------------------------------------
FROM python:3.11-slim AS builder

LABEL org.opencontainers.image.title="arc-scarlett-voice (builder)"
LABEL org.opencontainers.image.description="LiveKit voice agent - build stage"
LABEL arc.service.tier="services"
LABEL arc.service.category="voice-agent"

WORKDIR /build

# Install build dependencies (needed for faster-whisper and piper-tts)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Download Piper TTS model (en_US-lessac-medium, 22kHz, ~40MB)
RUN mkdir -p /build/models && \
    cd /build/models && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx && \
    wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM python:3.11-slim

LABEL org.opencontainers.image.title="arc-scarlett-voice"
LABEL org.opencontainers.image.description="LiveKit voice agent with Whisper STT, Sherlock LLM (NATS), and embedded Piper TTS"
LABEL org.opencontainers.image.version="0.1.0"
LABEL arc.service.tier="services"
LABEL arc.service.category="voice-agent"
LABEL arc.service.role="realtime-interface"
LABEL arc.monitoring.enabled="true"
LABEL arc.monitoring.type="otel"

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Copy Piper models from builder
COPY --from=builder /build/models /app/models

# Ensure Python packages are in PATH
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY src/ ./src/

# Create non-root user for security
RUN useradd -m -u 1000 scarlett && \
    chown -R scarlett:scarlett /app

USER scarlett

# Health check (basic process check - agent doesn't expose HTTP)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "python -m src.agent" || exit 1

# Default command: Run LiveKit agent
CMD ["python", "-m", "src.agent"]
