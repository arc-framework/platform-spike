# Multi-stage Dockerfile for A.R.C. Piper TTS Service
# Stage 1: Builder - Download models and dependencies
FROM python:3.12-slim as builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download Piper TTS model
RUN mkdir -p /build/models && \
    cd /build/models && \
    wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx \
         -O en_US-lessac-medium.onnx && \
    wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json \
         -O en_US-lessac-medium.onnx.json

# Stage 2: Runtime
FROM python:3.12-slim

LABEL org.opencontainers.image.title="arc-piper-tts" \
      org.opencontainers.image.description="A.R.C. Text-to-Speech Service (Piper)" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      arc.service.role="tts" \
      arc.service.type="agent-utility"

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Copy models from builder
COPY --from=builder /build/models /app/models

# Copy A.R.C. Common SDK
COPY libs/python-sdk /libs/python-sdk

# Copy service code
COPY services/arc-piper-tts/requirements.txt .
COPY services/arc-piper-tts/src ./src

# Install Python dependencies
RUN pip install --no-cache-dir -e /libs/python-sdk && \
    pip install --no-cache-dir -r requirements.txt

# Create non-root user
RUN useradd -m -u 1000 arcuser && \
    chown -R arcuser:arcuser /app

USER arcuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health').raise_for_status()" || exit 1

# Expose port
EXPOSE 8000

# Run service
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
