"""
Unit tests for Pulsar client wrapper.

Task: T028
Tests: PulsarAgentClient producer/consumer functionality
"""

import json
import pytest
from unittest.mock import MagicMock, patch

from arc_common.messaging import PulsarAgentClient


@pytest.fixture
def pulsar_client():
    """Create Pulsar client for testing"""
    return PulsarAgentClient(
        service_url="pulsar://localhost:6650", service_name="test-service"
    )


class TestPulsarAgentClient:
    """Tests for PulsarAgentClient"""

    def test_client_initialization(self, pulsar_client):
        """Test client initialization"""
        assert pulsar_client.service_name == "test-service"
        assert pulsar_client.service_url == "pulsar://localhost:6650"
        assert pulsar_client._connected is False

    @patch("arc_common.messaging.pulsar_client.pulsar.Client")
    def test_connect(self, mock_client_class, pulsar_client):
        """Test Pulsar connection"""
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client

        pulsar_client.connect()

        assert pulsar_client._connected is True
        assert pulsar_client.client == mock_client
        mock_client_class.assert_called_once()

    @patch("arc_common.messaging.pulsar_client.pulsar.Client")
    def test_disconnect(self, mock_client_class, pulsar_client):
        """Test Pulsar disconnection"""
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client

        pulsar_client.connect()
        pulsar_client.disconnect()

        assert pulsar_client._connected is False
        mock_client.close.assert_called_once()

    def test_create_message_envelope(self, pulsar_client):
        """Test message envelope creation"""
        data = {"conversation_id": "conv-123", "turn_index": 1}
        trace_id = "trace-456"

        envelope = pulsar_client._create_message_envelope(
            data, trace_id=trace_id, event_type="turn_completed"
        )

        assert envelope["trace_id"] == trace_id
        assert envelope["service"] == "test-service"
        assert envelope["event_type"] == "turn_completed"
        assert envelope["conversation_id"] == "conv-123"
        assert envelope["turn_index"] == 1
        assert "timestamp" in envelope

    @patch("arc_common.messaging.pulsar_client.pulsar.Client")
    def test_produce(self, mock_client_class, pulsar_client):
        """Test producing message to Pulsar topic"""
        mock_client = MagicMock()
        mock_producer = MagicMock()
        mock_producer.send.return_value = MagicMock()
        mock_client.create_producer.return_value = mock_producer
        mock_client_class.return_value = mock_client

        pulsar_client.connect()

        # Produce message
        msg_id = pulsar_client.produce(
            topic="persistent://arc/events/conversations",
            data={"conversation_id": "conv-123", "turn_index": 1},
            message_key="conv-123",
            trace_id="trace-789",
            event_type="turn_completed",
        )

        # Verify producer was created
        mock_client.create_producer.assert_called_once()

        # Verify send was called
        mock_producer.send.assert_called_once()
        call_kwargs = mock_producer.send.call_args[1]
        assert call_kwargs["partition_key"] == "conv-123"
        assert "trace_id" in call_kwargs["properties"]

    @patch("arc_common.messaging.pulsar_client.pulsar.Client")
    def test_produce_conversation_event(self, mock_client_class, pulsar_client):
        """Test convenience method for producing conversation event"""
        mock_client = MagicMock()
        mock_producer = MagicMock()
        mock_producer.send.return_value = MagicMock()
        mock_client.create_producer.return_value = mock_producer
        mock_client_class.return_value = mock_client

        pulsar_client.connect()

        # Produce conversation event
        msg_id = pulsar_client.produce_conversation_event(
            conversation_id="conv-456",
            event_type="turn_completed",
            data={"user_input": "Hello", "agent_response": "Hi"},
            trace_id="trace-111",
        )

        # Verify producer was created for correct topic
        mock_client.create_producer.assert_called_once()
        create_call_args = mock_client.create_producer.call_args[0]
        assert create_call_args[0] == "persistent://arc/events/conversations"

    @patch("arc_common.messaging.pulsar_client.pulsar.Client")
    def test_produce_analytics_event(self, mock_client_class, pulsar_client):
        """Test convenience method for producing analytics event"""
        mock_client = MagicMock()
        mock_producer = MagicMock()
        mock_producer.send.return_value = MagicMock()
        mock_client.create_producer.return_value = mock_producer
        mock_client_class.return_value = mock_client

        pulsar_client.connect()

        # Produce analytics event
        msg_id = pulsar_client.produce_analytics_event(
            metric_type="latency-metrics",
            data={"operation": "stt", "latency_ms": 125.5},
        )

        # Verify correct topic
        create_call_args = mock_client.create_producer.call_args[0]
        assert create_call_args[0] == "persistent://arc/analytics/latency-metrics"

    @patch("arc_common.messaging.pulsar_client.pulsar.Client")
    def test_produce_audit_log(self, mock_client_class, pulsar_client):
        """Test convenience method for producing audit log"""
        mock_client = MagicMock()
        mock_producer = MagicMock()
        mock_producer.send.return_value = MagicMock()
        mock_client.create_producer.return_value = mock_producer
        mock_client_class.return_value = mock_client

        pulsar_client.connect()

        # Produce audit log
        msg_id = pulsar_client.produce_audit_log(
            user_id="user-789",
            action="create",
            resource="conversation",
            data={"conversation_id": "conv-999"},
        )

        # Verify correct topic and message key
        create_call_args = mock_client.create_producer.call_args[0]
        assert create_call_args[0] == "persistent://arc/audit/logs"

        # Verify partition key is user_id
        send_call_kwargs = mock_producer.send.call_args[1]
        assert send_call_kwargs["partition_key"] == "user-789"

    @patch("arc_common.messaging.pulsar_client.pulsar.Client")
    def test_get_producer_caching(self, mock_client_class, pulsar_client):
        """Test producer caching for the same topic"""
        mock_client = MagicMock()
        mock_producer = MagicMock()
        mock_producer.send.return_value = MagicMock()
        mock_client.create_producer.return_value = mock_producer
        mock_client_class.return_value = mock_client

        pulsar_client.connect()

        # Produce to same topic twice
        topic = "persistent://arc/events/test"
        pulsar_client.produce(topic, {"test": "data1"})
        pulsar_client.produce(topic, {"test": "data2"})

        # Verify producer was only created once (cached)
        assert mock_client.create_producer.call_count == 1

    def test_produce_not_connected(self, pulsar_client):
        """Test producing when not connected raises error"""
        with pytest.raises(ConnectionError, match="Not connected to Pulsar"):
            pulsar_client.produce(
                topic="persistent://arc/events/test", data={"test": "data"}
            )

    @patch("arc_common.messaging.pulsar_client.pulsar.Client")
    def test_consume_setup(self, mock_client_class, pulsar_client):
        """Test consumer setup (without actual message loop)"""
        mock_client = MagicMock()
        mock_consumer = MagicMock()
        # Make receive() raise exception to exit loop immediately
        mock_consumer.receive.side_effect = Exception("Exit loop")
        mock_client.subscribe.return_value = mock_consumer
        mock_client_class.return_value = mock_client

        pulsar_client.connect()

        # Mock callback
        def callback(msg_data, msg):
            return True

        # Start consume (will exit immediately due to exception)
        try:
            pulsar_client.consume(
                topic="persistent://arc/events/test",
                subscription_name="test-subscription",
                callback=callback,
            )
        except Exception:
            pass

        # Verify consumer was created
        mock_client.subscribe.assert_called_once()
        call_args = mock_client.subscribe.call_args[0]
        assert call_args[0] == "persistent://arc/events/test"
        assert call_args[1] == "test-subscription"
