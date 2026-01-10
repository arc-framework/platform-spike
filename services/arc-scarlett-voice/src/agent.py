"""
arc-scarlett-voice Agent
LiveKit VoicePipelineAgent with Whisper STT, Sherlock LLM (NATS), and Piper TTS
"""

import os
import asyncio
from typing import Optional

from livekit import rtc
from livekit.agents import JobContext, WorkerOptions, cli, llm
from livekit.agents.voice_assistant import VoiceAssistant
from livekit.plugins import whisper, silero
import structlog

from .plugins.sherlock_llm import SherlockLLM
from .plugins.piper_tts import PiperTTS
from .observability import init_telemetry, configure_logging

# Initialize logging and telemetry
configure_logging()
init_telemetry()

logger = structlog.get_logger()

# ==============================================================================
# Agent Configuration
# ==============================================================================

LIVEKIT_URL = os.getenv("LIVEKIT_URL", "ws://arc-daredevil-voice:7880")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")

WHISPER_MODEL = os.getenv("WHISPER_MODEL", "base")  # base, small, medium
PIPER_MODEL_PATH = os.getenv("PIPER_MODEL_PATH", "/app/models/en_US-lessac-medium.onnx")
NATS_URL = os.getenv("NATS_URL", "nats://arc-flash-pulse:4222")

# Validate required credentials
if not LIVEKIT_API_KEY or not LIVEKIT_API_SECRET:
    raise ValueError("LIVEKIT_API_KEY and LIVEKIT_API_SECRET must be set")

# ==============================================================================
# Agent Entry Point
# ==============================================================================

async def entrypoint(ctx: JobContext):
    """
    Agent entry point called when a participant joins a room.

    Args:
        ctx: Job context with room, participant info
    """
    logger.info(
        "agent.session_start",
        room=ctx.room.name,
        participant=ctx.participant.identity if ctx.participant else "unknown"
    )

    # Initialize plugins
    stt_plugin = whisper.STT(model=WHISPER_MODEL)
    llm_plugin = SherlockLLM(nats_url=NATS_URL, user_id=ctx.participant.identity)
    tts_plugin = PiperTTS(model_path=PIPER_MODEL_PATH)
    vad_plugin = silero.VAD.load()  # Voice activity detection

    # Connect LLM to NATS
    await llm_plugin.connect()

    logger.info(
        "agent.plugins_initialized",
        stt=WHISPER_MODEL,
        llm="sherlock-nats",
        tts="piper-onnx",
        vad="silero"
    )

    # Create voice assistant
    assistant = VoiceAssistant(
        vad=vad_plugin,
        stt=stt_plugin,
        llm=llm_plugin,
        tts=tts_plugin,
        chat_ctx=llm.ChatContext(),  # Start with empty context
    )

    # Start assistant
    assistant.start(ctx.room)

    logger.info("agent.assistant_started", room=ctx.room.name)

    # Listen for participant disconnection
    @ctx.room.on("participant_disconnected")
    def on_participant_disconnected(participant: rtc.Participant):
        if participant.identity == ctx.participant.identity:
            logger.info("agent.participant_disconnected", participant=participant.identity)
            asyncio.create_task(cleanup())

    # Cleanup on agent shutdown
    async def cleanup():
        """Cleanup resources when agent stops."""
        logger.info("agent.cleanup_start")
        await assistant.aclose()
        await llm_plugin.disconnect()
        logger.info("agent.cleanup_complete")

    # Register cleanup hook
    ctx.add_shutdown_callback(cleanup)

    # Keep agent running
    await asyncio.Future()  # Run forever


# ==============================================================================
# Worker Startup
# ==============================================================================

if __name__ == "__main__":
    """
    Run LiveKit agent worker.

    Usage:
        python -m src.agent
    """
    logger.info(
        "agent.worker_start",
        livekit_url=LIVEKIT_URL,
        whisper_model=WHISPER_MODEL,
        piper_model=PIPER_MODEL_PATH,
        nats_url=NATS_URL
    )

    # Start worker with LiveKit CLI
    cli.run_app(
        WorkerOptions(
            entrypoint_fnc=entrypoint,
            api_key=LIVEKIT_API_KEY,
            api_secret=LIVEKIT_API_SECRET,
            ws_url=LIVEKIT_URL
        )
    )
