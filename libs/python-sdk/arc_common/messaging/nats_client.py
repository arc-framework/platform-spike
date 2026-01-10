"""
NATS client wrapper for A.R.C. agent event publishing and subscribing.

Purpose: Simplify NATS JetStream interactions for agent services
Subjects: Defined in docs/architecture/NATS-SUBJECTS.md
"""

import asyncio
import json
import logging
from datetime import datetime
from typing import Any, Callable, Dict, Optional
from uuid import uuid4

import nats
from nats.aio.client import Client as NATS
from nats.js.api import StreamConfig
from nats.js.client import JetStreamContext

logger = logging.getLogger(__name__)


class NATSAgentClient:
    """
    NATS client for A.R.C. agent event publishing and subscribing.
    
    Features:
    - Automatic connection management with reconnection
    - JSON message serialization/deserialization
    - Trace ID injection for distributed tracing
    - Error handling and logging
    - Subject validation against A.R.C. schema
    
    Example:
        client = NATSAgentClient("nats://localhost:4222")
        await client.connect()
        
        # Publish event
        await client.publish_agent_event(
            subject="agent.voice.track.published",
            data={"room_name": "room-123", "track_sid": "TR_abc"},
            trace_id="550e8400-e29b-41d4-a716-446655440000"
        )
        
        # Subscribe to events
        async def handler(msg):
            print(f"Received: {msg}")
        
        await client.subscribe("agent.brain.request", handler)
    """

    # Valid A.R.C. subject prefixes (from nats-subjects.md)
    VALID_SUBJECT_PREFIXES = [
        "agent.voice.",
        "agent.brain.",
        "agent.tts.",
        "agent.stt.",
        "system.health.",
        "system.service.",
    ]

    def __init__(
        self,
        servers: str = "nats://localhost:4222",
        service_name: str = "unknown",
        max_reconnect_attempts: int = 10,
    ):
        """
        Initialize NATS client.
        
        Args:
            servers: NATS server URL(s)
            service_name: Name of the service using this client (for logging)
            max_reconnect_attempts: Maximum number of reconnection attempts
        """
        self.servers = servers if isinstance(servers, list) else [servers]
        self.service_name = service_name
        self.max_reconnect_attempts = max_reconnect_attempts

        self.nc: Optional[NATS] = None
        self.js: Optional[JetStreamContext] = None
        self._connected = False

    async def connect(self):
        """Connect to NATS server with automatic reconnection"""
        if self._connected:
            logger.warning(f"{self.service_name}: Already connected to NATS")
            return

        try:
            self.nc = await nats.connect(
                servers=self.servers,
                name=self.service_name,
                max_reconnect_attempts=self.max_reconnect_attempts,
                reconnect_time_wait=2,  # seconds
                error_cb=self._error_callback,
                disconnected_cb=self._disconnected_callback,
                reconnected_cb=self._reconnected_callback,
            )

            # Get JetStream context
            self.js = self.nc.jetstream()

            self._connected = True
            logger.info(
                f"{self.service_name}: Connected to NATS at {self.servers}"
            )

        except Exception as e:
            logger.error(
                f"{self.service_name}: Failed to connect to NATS: {e}"
            )
            raise

    async def disconnect(self):
        """Gracefully disconnect from NATS"""
        if self.nc and self._connected:
            await self.nc.drain()
            await self.nc.close()
            self._connected = False
            logger.info(f"{self.service_name}: Disconnected from NATS")

    async def _error_callback(self, error):
        """Handle NATS errors"""
        logger.error(f"{self.service_name}: NATS error: {error}")

    async def _disconnected_callback(self):
        """Handle NATS disconnection"""
        logger.warning(f"{self.service_name}: Disconnected from NATS")
        self._connected = False

    async def _reconnected_callback(self):
        """Handle NATS reconnection"""
        logger.info(f"{self.service_name}: Reconnected to NATS")
        self._connected = True

    def _validate_subject(self, subject: str):
        """
        Validate subject against A.R.C. schema.
        
        Raises:
            ValueError: If subject doesn't match A.R.C. naming convention
        """
        if not any(
            subject.startswith(prefix) for prefix in self.VALID_SUBJECT_PREFIXES
        ):
            raise ValueError(
                f"Invalid subject: {subject}. Must start with one of: "
                f"{self.VALID_SUBJECT_PREFIXES}"
            )

    def _create_message_envelope(
        self,
        data: Dict[str, Any],
        trace_id: Optional[str] = None,
        event_type: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Create standardized message envelope with metadata.
        
        Args:
            data: Payload data
            trace_id: Optional trace ID for distributed tracing
            event_type: Optional event type (extracted from subject if not provided)
        
        Returns:
            Message envelope with timestamp, trace_id, and payload
        """
        envelope = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "trace_id": trace_id or str(uuid4()),
            "service": self.service_name,
        }

        if event_type:
            envelope["event_type"] = event_type

        # Merge data into envelope
        envelope.update(data)

        return envelope

    async def publish(
        self,
        subject: str,
        data: Dict[str, Any],
        trace_id: Optional[str] = None,
        event_type: Optional[str] = None,
    ):
        """
        Publish message to NATS subject.
        
        Args:
            subject: NATS subject (e.g., "agent.voice.track.published")
            data: Message payload (will be JSON serialized)
            trace_id: Optional trace ID for distributed tracing
            event_type: Optional event type
        
        Example:
            await client.publish(
                subject="agent.voice.session.started",
                data={"user_id": "user-123", "session_id": "session-456"},
                trace_id="550e8400-e29b-41d4-a716-446655440000"
            )
        """
        if not self._connected:
            raise ConnectionError(f"{self.service_name}: Not connected to NATS")

        self._validate_subject(subject)

        # Create message envelope
        envelope = self._create_message_envelope(data, trace_id, event_type)

        # Serialize to JSON
        message_bytes = json.dumps(envelope).encode("utf-8")

        try:
            await self.nc.publish(subject, message_bytes)
            logger.debug(
                f"{self.service_name}: Published to {subject}: {envelope.get('event_type', 'message')}"
            )
        except Exception as e:
            logger.error(
                f"{self.service_name}: Failed to publish to {subject}: {e}"
            )
            raise

    async def subscribe(
        self,
        subject: str,
        callback: Callable,
        queue: Optional[str] = None,
    ):
        """
        Subscribe to NATS subject with message handler.
        
        Args:
            subject: NATS subject or wildcard pattern (e.g., "agent.voice.>")
            callback: Async callback function(msg_data: dict)
            queue: Optional queue group name for load balancing
        
        Example:
            async def handle_brain_request(msg_data):
                user_input = msg_data.get("user_input")
                print(f"Processing: {user_input}")
            
            await client.subscribe("agent.brain.request", handle_brain_request)
        """
        if not self._connected:
            raise ConnectionError(f"{self.service_name}: Not connected to NATS")

        async def message_handler(msg):
            try:
                # Parse JSON payload
                data = json.loads(msg.data.decode("utf-8"))

                # Extract trace_id for logging
                trace_id = data.get("trace_id", "unknown")

                logger.debug(
                    f"{self.service_name}: Received on {msg.subject} "
                    f"(trace_id: {trace_id})"
                )

                # Call user callback
                await callback(data)

            except json.JSONDecodeError as e:
                logger.error(
                    f"{self.service_name}: Invalid JSON in message on {msg.subject}: {e}"
                )
            except Exception as e:
                logger.error(
                    f"{self.service_name}: Error processing message on {msg.subject}: {e}"
                )

        try:
            if queue:
                await self.nc.subscribe(subject, queue=queue, cb=message_handler)
                logger.info(
                    f"{self.service_name}: Subscribed to {subject} (queue: {queue})"
                )
            else:
                await self.nc.subscribe(subject, cb=message_handler)
                logger.info(
                    f"{self.service_name}: Subscribed to {subject}"
                )
        except Exception as e:
            logger.error(
                f"{self.service_name}: Failed to subscribe to {subject}: {e}"
            )
            raise

    # Convenience methods for common agent events

    async def publish_track_published(
        self,
        room_name: str,
        room_sid: str,
        participant_sid: str,
        participant_identity: str,
        track_sid: str,
        track_kind: str = "audio",
        metadata: Optional[Dict] = None,
        trace_id: Optional[str] = None,
    ):
        """Publish agent.voice.track.published event"""
        await self.publish(
            subject="agent.voice.track.published",
            data={
                "event": "track_published",
                "room_name": room_name,
                "room_sid": room_sid,
                "participant_sid": participant_sid,
                "participant_identity": participant_identity,
                "track_sid": track_sid,
                "track_kind": track_kind,
                "track_source": "microphone",
                "metadata": metadata or {},
            },
            trace_id=trace_id,
            event_type="track_published",
        )

    async def publish_session_started(
        self,
        user_id: str,
        session_id: str,
        room_name: str,
        room_sid: str,
        participant_sid: str,
        agent_id: str = "arc-scarlett-voice",
        trace_id: Optional[str] = None,
    ):
        """Publish agent.voice.session.started event"""
        await self.publish(
            subject="agent.voice.session.started",
            data={
                "event": "session_started",
                "user_id": user_id,
                "session_id": session_id,
                "room_name": room_name,
                "room_sid": room_sid,
                "participant_sid": participant_sid,
                "agent_id": agent_id,
            },
            trace_id=trace_id,
            event_type="session_started",
        )

    async def publish_brain_request(
        self,
        request_id: str,
        user_id: str,
        session_id: str,
        conversation_id: str,
        turn_index: int,
        user_input: str,
        context: Optional[Dict] = None,
        constraints: Optional[Dict] = None,
        trace_id: Optional[str] = None,
    ):
        """Publish agent.brain.request event"""
        await self.publish(
            subject="agent.brain.request",
            data={
                "request_id": request_id,
                "user_id": user_id,
                "session_id": session_id,
                "conversation_id": conversation_id,
                "turn_index": turn_index,
                "user_input": user_input,
                "context": context or {},
                "constraints": constraints or {
                    "max_tokens": 150,
                    "temperature": 0.7,
                    "timeout_ms": 2000,
                },
            },
            trace_id=trace_id,
            event_type="brain_request",
        )

    async def publish_heartbeat(
        self,
        status: str = "healthy",
        metrics: Optional[Dict] = None,
    ):
        """Publish system.health.heartbeat event"""
        await self.publish(
            subject="system.health.heartbeat",
            data={
                "service": self.service_name,
                "status": status,
                "metrics": metrics or {},
            },
            event_type="heartbeat",
        )
