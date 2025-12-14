"""
arc-sherlock-brain FastAPI Server
REST API + NATS worker for LangGraph reasoning engine
"""

import os
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import structlog

from .database import Database, check_database_health
from .graph import create_reasoning_graph, create_llm_client, invoke_reasoning_graph
from .nats_handler import NATSHandler
from .observability import init_telemetry, instrument_fastapi, configure_logging, BrainMetrics

# Initialize logging and telemetry on module load
configure_logging()
init_telemetry()

logger = structlog.get_logger()

# Initialize custom metrics
brain_metrics = BrainMetrics()

# ==============================================================================
# Global State (initialized in lifespan)
# ==============================================================================

db: Optional[Database] = None
graph = None
nats_handler: Optional[NATSHandler] = None

# ==============================================================================
# Lifespan Management
# ==============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan context manager.
    Initializes database, LangGraph, and NATS on startup, cleans up on shutdown.
    """
    global db, graph, nats_handler

    logger.info("brain.startup_begin")

    # Initialize database
    db = Database()
    await db.init_tables()
    logger.info("brain.database_ready")

    # Initialize LLM client and LangGraph
    llm_client = create_llm_client()
    graph = create_reasoning_graph(db, llm_client)
    logger.info("brain.langgraph_ready")

    # Initialize NATS handler (if enabled)
    enable_nats = os.getenv("ENABLE_NATS", "true").lower() == "true"
    if enable_nats:
        nats_handler = NATSHandler(graph, db)
        await nats_handler.connect()
        await nats_handler.subscribe()
        logger.info("brain.nats_ready")

    logger.info("brain.startup_complete", nats_enabled=enable_nats)

    yield  # Application runs here

    # Shutdown cleanup
    logger.info("brain.shutdown_begin")
    if nats_handler:
        await nats_handler.close()
    if db:
        await db.close()
    logger.info("brain.shutdown_complete")


# ==============================================================================
# FastAPI Application
# ==============================================================================

app = FastAPI(
    title="arc-sherlock-brain",
    description="LangGraph reasoning engine with pgvector memory and NATS integration",
    version="0.1.0",
    lifespan=lifespan
)

# Instrument FastAPI with OpenTelemetry
instrument_fastapi(app)

# ==============================================================================
# Request/Response Models
# ==============================================================================

class ChatRequest(BaseModel):
    """Request model for /chat endpoint."""
    user_id: str = Field(..., description="User identifier for conversation context")
    text: str = Field(..., description="User's message text", min_length=1)

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user123",
                "text": "What's the weather like today?"
            }
        }


class ChatResponse(BaseModel):
    """Response model for /chat endpoint."""
    user_id: str = Field(..., description="User identifier")
    text: str = Field(..., description="AI-generated response")
    latency_ms: int = Field(..., description="Processing latency in milliseconds")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user123",
                "text": "I don't have real-time weather data, but I can help you find...",
                "latency_ms": 650
            }
        }


class HealthResponse(BaseModel):
    """Response model for /health endpoint."""
    status: str = Field(..., description="Service health status")
    database: bool = Field(..., description="Database connectivity")
    nats: bool = Field(..., description="NATS connectivity")


# ==============================================================================
# API Endpoints
# ==============================================================================

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    """
    Process chat message through LangGraph reasoning engine.

    This endpoint is primarily for testing/debugging. In production, use NATS for lower latency.

    Args:
        request: ChatRequest with user_id and text

    Returns:
        ChatResponse with AI-generated response and latency

    Raises:
        HTTPException: If reasoning graph fails
    """
    import time
    start_time = time.time()

    if not db or not graph:
        raise HTTPException(status_code=503, detail="Service not initialized")

    try:
        logger.info(
            "api.chat_request",
            user_id=request.user_id,
            text_length=len(request.text)
        )

        # Record metrics
        brain_metrics.record_request(request.user_id)

        # Invoke LangGraph
        response_text = await invoke_reasoning_graph(
            graph, db, request.user_id, request.text
        )

        latency_ms = int((time.time() - start_time) * 1000)

        # Record latency metric
        brain_metrics.record_latency(latency_ms, request.user_id)

        logger.info(
            "api.chat_response",
            user_id=request.user_id,
            response_length=len(response_text),
            latency_ms=latency_ms
        )

        return ChatResponse(
            user_id=request.user_id,
            text=response_text,
            latency_ms=latency_ms
        )

    except Exception as e:
        brain_metrics.record_error(type(e).__name__)
        logger.error("api.chat_error", user_id=request.user_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Reasoning error: {str(e)}")


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    """
    Health check endpoint for Docker/Kubernetes readiness probes.

    Returns:
        HealthResponse with service status and component health
    """
    # Check database
    db_healthy = await check_database_health(db) if db else False

    # Check NATS (basic connectivity check)
    nats_healthy = nats_handler.nc.is_connected if nats_handler and nats_handler.nc else False

    # Overall status
    status = "healthy" if (db_healthy and nats_healthy) else "degraded"

    return HealthResponse(
        status=status,
        database=db_healthy,
        nats=nats_healthy
    )


@app.get("/")
async def root():
    """Root endpoint with service info."""
    return {
        "service": "arc-sherlock-brain",
        "version": "0.1.0",
        "description": "LangGraph reasoning engine with pgvector memory",
        "endpoints": {
            "chat": "POST /chat",
            "health": "GET /health"
        }
    }


# ==============================================================================
# Run Server (Development Mode)
# ==============================================================================

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,  # Hot reload for development
        log_level="info"
    )
