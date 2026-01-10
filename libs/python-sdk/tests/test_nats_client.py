"""
Unit tests for NATS client wrapper.

Tests: NATSAgentClient publish/subscribe functionality
"""

import asyncio
import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from arc_common.messaging import NATSAgentClient


@pytest.fixture
def nats_client():
    """Create NATS client for testing"""
    return NATSAgentClient(
        servers="nats://localhost:4222", service_name="test-service"
    )


@pytest.mark.asyncio
class TestNATSAgentClient:
    """Tests for NATSAgentClient"""

    async def test_client_initialization(self, nats_client):
        """Test client initialization"""
        assert nats_client.service_name == "test-service"
        assert nats_client.servers == ["nats://localhost:4222"]
        assert nats_client._connected is False

    @patch("arc_common.messaging.nats_client.nats.connect")
    async def test_connect(self, mock_connect, nats_client):
        """Test NATS connection"""
        mock_nc = AsyncMock()
        mock_js = MagicMock()
        mock_nc.jetstream.return_value = mock_js
        mock_connect.return_value = mock_nc

        await nats_client.connect()

        assert nats_client._connected is True
        assert nats_client.nc == mock_nc
        assert nats_client.js == mock_js
        mock_connect.assert_called_once()

    @patch("arc_common.messaging.nats_client.nats.connect")
    async def test_disconnect(self, mock_connect, nats_client):
        """Test NATS disconnection"""
        mock_nc = AsyncMock()
        mock_nc.jetstream.return_value = MagicMock()
        mock_connect.return_value = mock_nc

        await nats_client.connect()
        await nats_client.disconnect()

        assert nats_client._connected is False
        mock_nc.drain.assert_called_once()
        mock_nc.close.assert_called_once()

    def test_validate_subject_valid(self, nats_client):
        """Test subject validation with valid subjects"""
        # Should not raise
        nats_client._validate_subject("agent.voice.track.published")
        nats_client._validate_subject("agent.brain.request")
        nats_client._validate_subject("system.health.heartbeat")

    def test_validate_subject_invalid(self, nats_client):
        """Test subject validation with invalid subjects"""
        with pytest.raises(ValueError, match="Invalid subject"):
            nats_client._validate_subject("invalid.subject")

        with pytest.raises(ValueError, match="Invalid subject"):
            nats_client._validate_subject("random.topic")

    def test_create_message_envelope(self, nats_client):
        """Test message envelope creation"""
        data = {"user_id": "user-123", "message": "Hello"}
        trace_id = "550e8400-e29b-41d4-a716-446655440000"

        envelope = nats_client._create_message_envelope(
            data, trace_id=trace_id, event_type="test_event"
        )

        assert envelope["trace_id"] == trace_id
        assert envelope["service"] == "test-service"
        assert envelope["event_type"] == "test_event"
        assert envelope["user_id"] == "user-123"
        assert envelope["message"] == "Hello"
        assert "timestamp" in envelope

    @patch("arc_common.messaging.nats_client.nats.connect")
    async def test_publish(self, mock_connect, nats_client):
        """Test publishing message to NATS"""
        mock_nc = AsyncMock()
        mock_nc.jetstream.return_value = MagicMock()
        mock_connect.return_value = mock_nc

        await nats_client.connect()

        # Publish message
        await nats_client.publish(
            subject="agent.voice.session.started",
            data={"user_id": "user-123", "session_id": "session-456"},
            trace_id="trace-123",
        )

        # Verify publish was called
        mock_nc.publish.assert_called_once()
        call_args = mock_nc.publish.call_args
        assert call_args[0][0] == "agent.voice.session.started"

        # Verify message payload
        message_bytes = call_args[0][1]
        message_data = json.loads(message_bytes.decode("utf-8"))
        assert message_data["user_id"] == "user-123"
        assert message_data["session_id"] == "session-456"
        assert message_data["trace_id"] == "trace-123"

    @patch("arc_common.messaging.nats_client.nats.connect")
    async def test_subscribe(self, mock_connect, nats_client):
        """Test subscribing to NATS subject"""
        mock_nc = AsyncMock()
        mock_nc.jetstream.return_value = MagicMock()
        mock_connect.return_value = mock_nc

        await nats_client.connect()

        # Mock callback
        callback = AsyncMock()

        # Subscribe
        await nats_client.subscribe("agent.brain.request", callback)

        # Verify subscribe was called
        mock_nc.subscribe.assert_called_once()

    @patch("arc_common.messaging.nats_client.nats.connect")
    async def test_publish_track_published(self, mock_connect, nats_client):
        """Test convenience method for publishing track_published event"""
        mock_nc = AsyncMock()
        mock_nc.jetstream.return_value = MagicMock()
        mock_connect.return_value = mock_nc

        await nats_client.connect()

        # Publish track event
        await nats_client.publish_track_published(
            room_name="room-123",
            room_sid="RM_abc",
            participant_sid="PA_xyz",
            participant_identity="user-456",
            track_sid="TR_123",
            track_kind="audio",
        )

        # Verify publish was called
        mock_nc.publish.assert_called_once()
        call_args = mock_nc.publish.call_args
        assert call_args[0][0] == "agent.voice.track.published"

    @patch("arc_common.messaging.nats_client.nats.connect")
    async def test_publish_brain_request(self, mock_connect, nats_client):
        """Test convenience method for publishing brain request"""
        mock_nc = AsyncMock()
        mock_nc.jetstream.return_value = MagicMock()
        mock_connect.return_value = mock_nc

        await nats_client.connect()

        # Publish brain request
        await nats_client.publish_brain_request(
            request_id="req-123",
            user_id="user-456",
            session_id="session-789",
            conversation_id="conv-111",
            turn_index=1,
            user_input="What's the weather?",
            trace_id="trace-999",
        )

        # Verify publish was called
        mock_nc.publish.assert_called_once()
        call_args = mock_nc.publish.call_args
        assert call_args[0][0] == "agent.brain.request"

        # Verify payload
        message_bytes = call_args[0][1]
        message_data = json.loads(message_bytes.decode("utf-8"))
        assert message_data["user_input"] == "What's the weather?"
        assert message_data["turn_index"] == 1

    @patch("arc_common.messaging.nats_client.nats.connect")
    async def test_publish_heartbeat(self, mock_connect, nats_client):
        """Test convenience method for publishing heartbeat"""
        mock_nc = AsyncMock()
        mock_nc.jetstream.return_value = MagicMock()
        mock_connect.return_value = mock_nc

        await nats_client.connect()

        # Publish heartbeat
        await nats_client.publish_heartbeat(
            status="healthy", metrics={"cpu": 25.5, "memory": 512}
        )

        # Verify publish was called
        mock_nc.publish.assert_called_once()
        call_args = mock_nc.publish.call_args
        assert call_args[0][0] == "system.health.heartbeat"

    async def test_publish_not_connected(self, nats_client):
        """Test publishing when not connected raises error"""
        with pytest.raises(ConnectionError, match="Not connected to NATS"):
            await nats_client.publish(
                subject="agent.voice.test", data={"test": "data"}
            )
