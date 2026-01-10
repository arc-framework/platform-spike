"""
arc-sherlock-brain NATS Handler
Async NATS subscriber for brain.request → brain.response pattern
"""

import os
import json
import asyncio
from typing import Optional

import nats
from nats.aio.client import Client as NATSClient
from nats.aio.msg import Msg
import structlog

from .database import Database
from .graph import StateGraph, invoke_reasoning_graph

logger = structlog.get_logger()

# ==============================================================================
# NATS Request Handler
# ==============================================================================

async def handle_brain_request(
    msg: Msg,
    graph: StateGraph,
    db: Database
):
    """
    Handle incoming NATS request on brain.request subject.

    Expected payload (JSON):
        {
            "user_id": "user123",
            "text": "What's the weather today?"
        }

    Response payload (JSON):
        {
            "user_id": "user123",
            "text": "AI-generated response...",
            "latency_ms": 650
        }

    Args:
        msg: NATS message
        graph: Compiled LangGraph state machine
        db: Database instance
    """
    import time
    start_time = time.time()

    try:
        # Parse request
        payload = json.loads(msg.data.decode())
        user_id = payload.get("user_id")
        text = payload.get("text")

        if not user_id or not text:
            raise ValueError("Missing required fields: user_id, text")

        logger.info(
            "nats.request_received",
            user_id=user_id,
            text_length=len(text),
            subject=msg.subject
        )

        # Invoke LangGraph reasoning
        response_text = await invoke_reasoning_graph(graph, db, user_id, text)

        # Calculate latency
        latency_ms = int((time.time() - start_time) * 1000)

        # Build response
        response_payload = {
            "user_id": user_id,
            "text": response_text,
            "latency_ms": latency_ms
        }

        # Reply to requester
        await msg.respond(json.dumps(response_payload).encode())

        logger.info(
            "nats.response_sent",
            user_id=user_id,
            response_length=len(response_text),
            latency_ms=latency_ms
        )

    except Exception as e:
        logger.error(
            "nats.request_error",
            error=str(e),
            subject=msg.subject
        )
        # Send error response
        error_payload = {
            "error": str(e),
            "latency_ms": int((time.time() - start_time) * 1000)
        }
        await msg.respond(json.dumps(error_payload).encode())


# ==============================================================================
# NATS Client Manager
# ==============================================================================

class NATSHandler:
    """
    NATS client lifecycle manager for brain service.
    """

    def __init__(
        self,
        graph: StateGraph,
        db: Database,
        nats_url: Optional[str] = None
    ):
        """
        Initialize NATS handler.

        Args:
            graph: Compiled LangGraph
            db: Database instance
            nats_url: NATS server URL (defaults to NATS_URL env var)
        """
        self.graph = graph
        self.db = db
        self.nats_url = nats_url or os.getenv("NATS_URL", "nats://arc-flash-pulse:4222")
        self.nc: Optional[NATSClient] = None
        self.subscription = None

    async def connect(self):
        """Connect to NATS server."""
        self.nc = await nats.connect(self.nats_url)
        logger.info("nats.connected", url=self.nats_url)

    async def subscribe(self):
        """Subscribe to brain.request subject."""
        if not self.nc:
            raise RuntimeError("NATS client not connected. Call connect() first.")

        # Define handler with injected dependencies
        async def message_handler(msg: Msg):
            await handle_brain_request(msg, self.graph, self.db)

        # Subscribe with handler
        self.subscription = await self.nc.subscribe(
            subject="brain.request",
            cb=message_handler
        )

        logger.info(
            "nats.subscribed",
            subject="brain.request",
            queue_group="sherlock_workers"
        )

    async def close(self):
        """Close NATS connection gracefully."""
        if self.subscription:
            await self.subscription.unsubscribe()
        if self.nc:
            await self.nc.drain()
            await self.nc.close()
        logger.info("nats.closed")

    async def run_forever(self):
        """
        Keep the NATS handler running indefinitely.
        Blocks until interrupted.
        """
        logger.info("nats.handler_running", subject="brain.request")
        try:
            # Keep alive (NATS subscriptions are async callbacks)
            while True:
                await asyncio.sleep(1)
        except asyncio.CancelledError:
            logger.info("nats.handler_cancelled")
            await self.close()


# ==============================================================================
# Main Entry Point (Standalone Mode)
# ==============================================================================

async def main():
    """
    Run NATS handler in standalone mode (without FastAPI).
    Useful for horizontal scaling brain workers.
    """
    from .database import Database
    from .graph import create_reasoning_graph, create_llm_client

    # Initialize components
    db = Database()
    await db.init_tables()

    llm_client = create_llm_client()
    graph = create_reasoning_graph(db, llm_client)

    # Start NATS handler
    handler = NATSHandler(graph, db)
    await handler.connect()
    await handler.subscribe()

    logger.info("brain.nats_worker_started", mode="standalone")

    # Run forever
    try:
        await handler.run_forever()
    except KeyboardInterrupt:
        logger.info("brain.shutdown_requested")
    finally:
        await handler.close()
        await db.close()


if __name__ == "__main__":
    """
    Run as standalone NATS worker:
        python -m src.nats_handler
    """
    asyncio.run(main())
