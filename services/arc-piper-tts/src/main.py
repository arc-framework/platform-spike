"""
A.R.C. Piper TTS Service

FastAPI service for text-to-speech synthesis using Piper neural TTS.

Endpoints:
- POST /tts - Convert text to speech (returns WAV audio)
- GET /health - Health check endpoint
"""

import io
import logging
import os
import wave
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response, StreamingResponse
from piper import PiperVoice
from pydantic import BaseModel, Field

from arc_common.observability import init_otel, get_otel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Global TTS model
piper_voice: Optional[PiperVoice] = None


class TTSRequest(BaseModel):
    """Text-to-speech request"""
    text: str = Field(..., min_length=1, max_length=5000, description="Text to synthesize")
    
    class Config:
        json_schema_extra = {
            "example": {
                "text": "Hello! How can I help you today?"
            }
        }


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    service: str
    model_loaded: bool
    model_name: str


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    global piper_voice
    
    # Startup: Load TTS model
    logger.info("Starting arc-piper-tts service...")
    
    # Initialize OpenTelemetry
    otel = init_otel(
        service_name="arc-piper-tts",
        otel_endpoint=os.getenv("OTEL_ENDPOINT", "http://localhost:4317"),
        environment=os.getenv("ENVIRONMENT", "development")
    )
    logger.info("OpenTelemetry initialized")
    
    # Load Piper voice model
    model_path = Path("/app/models/en_US-lessac-medium.onnx")
    if not model_path.exists():
        # Fallback for local development
        model_path = Path("models/en_US-lessac-medium.onnx")
    
    if model_path.exists():
        logger.info(f"Loading Piper model from {model_path}...")
        piper_voice = PiperVoice.load(str(model_path))
        logger.info("Piper model loaded successfully")
    else:
        logger.error(f"Piper model not found at {model_path}")
        logger.error("Service will start but TTS will fail until model is available")
    
    yield
    
    # Shutdown: Cleanup
    logger.info("Shutting down arc-piper-tts service...")
    otel.shutdown()


# Create FastAPI app
app = FastAPI(
    title="A.R.C. Piper TTS Service",
    description="Neural text-to-speech synthesis using Piper",
    version="0.1.0",
    lifespan=lifespan
)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Health check endpoint for container orchestration.
    
    Returns service status and model availability.
    """
    return HealthResponse(
        status="healthy" if piper_voice is not None else "degraded",
        service="arc-piper-tts",
        model_loaded=piper_voice is not None,
        model_name="en_US-lessac-medium" if piper_voice else "none"
    )


@app.post("/tts")
async def text_to_speech(request: TTSRequest):
    """
    Convert text to speech and return WAV audio.
    
    Args:
        request: TTSRequest with text to synthesize
    
    Returns:
        StreamingResponse with WAV audio (audio/wav)
    
    Raises:
        HTTPException: 503 if model not loaded, 500 on synthesis error
    """
    if piper_voice is None:
        raise HTTPException(
            status_code=503,
            detail="TTS model not loaded. Service is starting or model file is missing."
        )
    
    otel = get_otel()
    
    with otel.trace_span("tts_synthesis", {"text_length": len(request.text)}) as span:
        try:
            logger.info(f"Synthesizing text (length: {len(request.text)} chars)")
            
            # Synthesize speech
            with otel.trace_span("piper_synthesize"):
                audio_data = []
                for audio_chunk in piper_voice.synthesize_stream_raw(request.text):
                    audio_data.extend(audio_chunk)
            
            # Convert to numpy array
            audio_array = np.array(audio_data, dtype=np.int16)
            
            # Record metrics
            duration_seconds = len(audio_array) / piper_voice.config.sample_rate
            span.set_attribute("audio_duration_seconds", duration_seconds)
            span.set_attribute("audio_samples", len(audio_array))
            span.set_attribute("sample_rate", piper_voice.config.sample_rate)
            
            otel.record_histogram(
                "tts.audio.duration",
                duration_seconds * 1000,  # Convert to ms
                {"model": "piper_lessac_medium"}
            )
            
            # Create WAV file in memory
            wav_buffer = io.BytesIO()
            with wave.open(wav_buffer, "wb") as wav_file:
                wav_file.setnchannels(1)  # Mono
                wav_file.setsampwidth(2)  # 16-bit
                wav_file.setframerate(piper_voice.config.sample_rate)
                wav_file.writeframes(audio_array.tobytes())
            
            wav_buffer.seek(0)
            
            logger.info(
                f"TTS synthesis complete: {duration_seconds:.2f}s audio, "
                f"{len(request.text)} chars input"
            )
            
            otel.increment_counter("tts.requests.success")
            
            return StreamingResponse(
                wav_buffer,
                media_type="audio/wav",
                headers={
                    "Content-Disposition": "attachment; filename=speech.wav",
                    "X-Audio-Duration": str(duration_seconds),
                    "X-Sample-Rate": str(piper_voice.config.sample_rate)
                }
            )
            
        except Exception as e:
            logger.error(f"TTS synthesis failed: {e}", exc_info=True)
            otel.record_error("tts_synthesis_error", str(e))
            otel.increment_counter("tts.requests.failed", attributes={"error": type(e).__name__})
            
            raise HTTPException(
                status_code=500,
                detail=f"TTS synthesis failed: {str(e)}"
            )


@app.get("/")
async def root():
    """Root endpoint with service info"""
    return {
        "service": "arc-piper-tts",
        "version": "0.1.0",
        "model": "en_US-lessac-medium (Piper)",
        "endpoints": {
            "health": "/health",
            "tts": "/tts (POST)"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
