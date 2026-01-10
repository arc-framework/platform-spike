"""
Sherlock LLM Plugin for LiveKit Agents SDK
Calls arc-sherlock-brain via NATS for reasoning
"""

import os
import json
import asyncio
from typing import Optional, AsyncIterator

from livekit.agents import llm
import nats
from nats.aio.client import Client as NATSClient
import structlog

logger = structlog.get_logger()

# ==============================================================================
# Sherlock LLM Plugin
# ==============================================================================

class SherlockLLM(llm.LLM):
    """
    Custom LLM plugin that delegates reasoning to arc-sherlock-brain via NATS.

    This plugin integrates with LiveKit's VoicePipelineAgent to provide
    conversational AI powered by LangGraph and pgvector memory.
    """

    def __init__(
        self,
        nats_url: Optional[str] = None,
        timeout: float = 5.0,
        user_id: str = "default_user"
    ):
        """
        Initialize Sherlock LLM plugin.

        Args:
            nats_url: NATS server URL (defaults to NATS_URL env var)
            timeout: NATS request timeout in seconds
            user_id: User identifier for conversation context
        """
        super().__init__()
        self.nats_url = nats_url or os.getenv("NATS_URL", "nats://arc-flash-pulse:4222")
        self.timeout = timeout
        self.user_id = user_id
        self.nc: Optional[NATSClient] = None

    async def connect(self):
        """Connect to NATS server."""
        if not self.nc:
            self.nc = await nats.connect(self.nats_url)
            logger.info("sherlock_llm.nats_connected", url=self.nats_url)

    async def disconnect(self):
        """Disconnect from NATS server."""
        if self.nc:
            await self.nc.drain()
            await self.nc.close()
            self.nc = None
            logger.info("sherlock_llm.nats_disconnected")

    async def chat(
        self,
        chat_ctx: llm.ChatContext,
        fnc_ctx: Optional[llm.FunctionContext] = None,
        temperature: Optional[float] = None,
        n: Optional[int] = None
    ) -> "llm.LLMStream":
        """
        Non-streaming chat (required by LLM interface).

        Args:
            chat_ctx: Chat context with message history
            fnc_ctx: Function calling context (not used)
            temperature: Temperature parameter (not used - brain decides)
            n: Number of completions (not used)

        Returns:
            LLMStream with single response
        """
        # Get latest user message
        user_message = self._extract_latest_message(chat_ctx)

        logger.info(
            "sherlock_llm.chat_request",
            user_id=self.user_id,
            message_length=len(user_message)
        )

        # Call arc-sherlock-brain via NATS
        try:
            response_text = await self._call_brain(user_message)
        except Exception as e:
            logger.error("sherlock_llm.chat_error", error=str(e))
            response_text = "I apologize, but I'm having trouble processing your request right now."

        # Create LLMStream with response
        return SherlockLLMStream(response_text, user_message)

    async def astream_chat(
        self,
        chat_ctx: llm.ChatContext,
        fnc_ctx: Optional[llm.FunctionContext] = None,
        temperature: Optional[float] = None,
        n: Optional[int] = None
    ) -> AsyncIterator["llm.LLMStream"]:
        """
        Streaming chat (preferred for voice agents).

        Args:
            chat_ctx: Chat context with message history
            fnc_ctx: Function calling context (not used)
            temperature: Temperature parameter (not used)
            n: Number of completions (not used)

        Yields:
            LLMStream chunks (single chunk for now - brain doesn't stream yet)
        """
        stream = await self.chat(chat_ctx, fnc_ctx, temperature, n)
        yield stream

    def _extract_latest_message(self, chat_ctx: llm.ChatContext) -> str:
        """
        Extract the latest user message from chat context.

        Args:
            chat_ctx: Chat context

        Returns:
            Latest user message text
        """
        if not chat_ctx.messages:
            return ""

        # Get last message
        last_msg = chat_ctx.messages[-1]

        # Extract content (handle different message types)
        if hasattr(last_msg, "content"):
            return last_msg.content
        elif isinstance(last_msg, dict) and "content" in last_msg:
            return last_msg["content"]
        else:
            return str(last_msg)

    async def _call_brain(self, text: str) -> str:
        """
        Call arc-sherlock-brain via NATS request-reply.

        Args:
            text: User message text

        Returns:
            AI-generated response text

        Raises:
            Exception: If NATS request fails or times out
        """
        if not self.nc:
            await self.connect()

        # Build request payload
        request_payload = {
            "user_id": self.user_id,
            "text": text
        }

        logger.info(
            "sherlock_llm.nats_request",
            subject="brain.request",
            user_id=self.user_id,
            text_length=len(text)
        )

        # Send request with timeout
        try:
            response_msg = await self.nc.request(
                subject="brain.request",
                payload=json.dumps(request_payload).encode(),
                timeout=self.timeout
            )

            # Parse response
            response_data = json.loads(response_msg.data.decode())

            # Check for errors
            if "error" in response_data:
                raise Exception(f"Brain error: {response_data['error']}")

            response_text = response_data.get("text", "")
            latency_ms = response_data.get("latency_ms", 0)

            logger.info(
                "sherlock_llm.nats_response",
                user_id=self.user_id,
                response_length=len(response_text),
                latency_ms=latency_ms
            )

            return response_text

        except asyncio.TimeoutError:
            logger.error("sherlock_llm.nats_timeout", timeout=self.timeout)
            raise Exception(f"Brain request timed out after {self.timeout}s")


# ==============================================================================
# LLM Stream Implementation
# ==============================================================================

class SherlockLLMStream(llm.LLMStream):
    """
    LLM stream for Sherlock responses.

    Currently returns a single chunk (non-streaming).
    Future: Implement true streaming when brain supports it.
    """

    def __init__(self, response_text: str, request_text: str):
        """
        Initialize LLM stream.

        Args:
            response_text: AI-generated response
            request_text: Original user message
        """
        super().__init__(
            llm=None,  # Not needed for this implementation
            fnc_ctx=None,
            chat_ctx=llm.ChatContext()
        )
        self.response_text = response_text
        self.request_text = request_text

    async def __anext__(self) -> llm.ChatChunk:
        """
        Return next chunk of response.

        Returns:
            ChatChunk with response text

        Raises:
            StopAsyncIteration: When stream is complete
        """
        if not hasattr(self, "_yielded"):
            self._yielded = True
            return llm.ChatChunk(
                choices=[
                    llm.Choice(
                        delta=llm.ChoiceDelta(
                            role="assistant",
                            content=self.response_text
                        )
                    )
                ]
            )
        else:
            raise StopAsyncIteration

    def __aiter__(self):
        """Return async iterator."""
        return self


# ==============================================================================
# Testing / Development
# ==============================================================================

if __name__ == "__main__":
    async def test_sherlock_llm():
        """Quick test of Sherlock LLM plugin."""
        llm_plugin = SherlockLLM(user_id="test_user")
        await llm_plugin.connect()

        # Create test chat context
        chat_ctx = llm.ChatContext()
        chat_ctx.messages.append(
            llm.ChatMessage(role="user", content="Hello, tell me about yourself!")
        )

        # Test chat
        stream = await llm_plugin.chat(chat_ctx)
        async for chunk in stream:
            print(f"Response: {chunk.choices[0].delta.content}")

        await llm_plugin.disconnect()
        print("✓ Sherlock LLM test complete")

    asyncio.run(test_sherlock_llm())
