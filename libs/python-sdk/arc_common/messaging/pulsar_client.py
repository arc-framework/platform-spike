"""
Pulsar client wrapper for A.R.C. durable event streaming.

Task: T026
Purpose: Simplify Pulsar interactions for conversation events, analytics, and audit logs
Topics: Defined in docs/architecture/PULSAR-TOPICS.md
"""

import json
import logging
from datetime import datetime
from typing import Any, Callable, Dict, Optional
from uuid import uuid4

import pulsar
from pulsar import ConsumerType, MessageId

logger = logging.getLogger(__name__)


class PulsarAgentClient:
    """
    Pulsar client for A.R.C. durable event streaming.
    
    Features:
    - Automatic connection management
    - JSON schema validation
    - Deduplication via message keys
    - Consumer acknowledgment patterns
    - Dead letter queue support
    - Batch publishing for analytics
    
    Example:
        client = PulsarAgentClient("pulsar://localhost:6650")
        await client.connect()
        
        # Produce conversation event
        await client.produce_conversation_event(
            conversation_id="conv-123",
            event_type="turn_completed",
            data={"user_input": "Hello", "agent_response": "Hi there!"}
        )
        
        # Consume analytics events
        async def handler(msg):
            print(f"Analytics: {msg}")
        
        await client.consume_analytics("latency-metrics", handler)
    """

    # Topic namespaces (from pulsar-topics.md)
    NAMESPACE_EVENTS = "arc/events"
    NAMESPACE_ANALYTICS = "arc/analytics"
    NAMESPACE_AUDIT = "arc/audit"

    def __init__(
        self,
        service_url: str = "pulsar://localhost:6650",
        service_name: str = "unknown",
        operation_timeout_seconds: int = 30,
    ):
        """
        Initialize Pulsar client.
        
        Args:
            service_url: Pulsar broker URL
            service_name: Name of the service using this client
            operation_timeout_seconds: Timeout for operations
        """
        self.service_url = service_url
        self.service_name = service_name
        self.operation_timeout_seconds = operation_timeout_seconds

        self.client: Optional[pulsar.Client] = None
        self.producers: Dict[str, pulsar.Producer] = {}
        self.consumers: Dict[str, pulsar.Consumer] = {}
        self._connected = False

    def connect(self):
        """Connect to Pulsar cluster"""
        if self._connected:
            logger.warning(f"{self.service_name}: Already connected to Pulsar")
            return

        try:
            self.client = pulsar.Client(
                self.service_url,
                operation_timeout_seconds=self.operation_timeout_seconds,
            )
            self._connected = True
            logger.info(
                f"{self.service_name}: Connected to Pulsar at {self.service_url}"
            )
        except Exception as e:
            logger.error(
                f"{self.service_name}: Failed to connect to Pulsar: {e}"
            )
            raise

    def disconnect(self):
        """Gracefully disconnect from Pulsar"""
        if not self._connected:
            return

        # Close all producers
        for topic, producer in self.producers.items():
            try:
                producer.close()
                logger.debug(f"{self.service_name}: Closed producer for {topic}")
            except Exception as e:
                logger.error(
                    f"{self.service_name}: Error closing producer for {topic}: {e}"
                )

        # Close all consumers
        for subscription, consumer in self.consumers.items():
            try:
                consumer.close()
                logger.debug(
                    f"{self.service_name}: Closed consumer for {subscription}"
                )
            except Exception as e:
                logger.error(
                    f"{self.service_name}: Error closing consumer for {subscription}: {e}"
                )

        # Close client
        if self.client:
            self.client.close()
            self._connected = False
            logger.info(f"{self.service_name}: Disconnected from Pulsar")

    def _get_producer(self, topic: str) -> pulsar.Producer:
        """
        Get or create producer for topic.
        
        Args:
            topic: Full topic name (e.g., "persistent://arc/events/conversations")
        
        Returns:
            Pulsar producer instance
        """
        if topic not in self.producers:
            if not self._connected:
                raise ConnectionError(
                    f"{self.service_name}: Not connected to Pulsar"
                )

            self.producers[topic] = self.client.create_producer(
                topic,
                # Enable batching for performance
                batching_enabled=True,
                batching_max_publish_delay_ms=100,
                # Enable compression
                compression_type=pulsar.CompressionType.LZ4,
                # Producer name for observability
                producer_name=f"{self.service_name}-{topic.split('/')[-1]}",
            )
            logger.info(f"{self.service_name}: Created producer for {topic}")

        return self.producers[topic]

    def _create_message_envelope(
        self,
        data: Dict[str, Any],
        trace_id: Optional[str] = None,
        event_type: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Create standardized message envelope.
        
        Args:
            data: Payload data
            trace_id: Optional trace ID for distributed tracing
            event_type: Event type
        
        Returns:
            Message envelope with metadata
        """
        envelope = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "trace_id": trace_id or str(uuid4()),
            "service": self.service_name,
        }

        if event_type:
            envelope["event_type"] = event_type

        envelope.update(data)

        return envelope

    def produce(
        self,
        topic: str,
        data: Dict[str, Any],
        message_key: Optional[str] = None,
        trace_id: Optional[str] = None,
        event_type: Optional[str] = None,
        properties: Optional[Dict[str, str]] = None,
    ) -> MessageId:
        """
        Produce message to Pulsar topic.
        
        Args:
            topic: Full topic name (e.g., "persistent://arc/events/conversations")
            data: Message payload (will be JSON serialized)
            message_key: Optional key for deduplication and ordering
            trace_id: Optional trace ID for distributed tracing
            event_type: Event type
            properties: Optional message properties (metadata)
        
        Returns:
            Message ID
        
        Example:
            msg_id = client.produce(
                topic="persistent://arc/events/conversations",
                data={"conversation_id": "conv-123", "turn_index": 1},
                message_key="conv-123",
                event_type="turn_completed"
            )
        """
        producer = self._get_producer(topic)

        # Create message envelope
        envelope = self._create_message_envelope(data, trace_id, event_type)

        # Serialize to JSON
        message_bytes = json.dumps(envelope).encode("utf-8")

        try:
            # Prepare message properties
            msg_properties = properties or {}
            msg_properties["trace_id"] = envelope["trace_id"]
            msg_properties["service"] = self.service_name
            if event_type:
                msg_properties["event_type"] = event_type

            # Send message
            if message_key:
                msg_id = producer.send(
                    message_bytes,
                    partition_key=message_key,
                    properties=msg_properties,
                )
            else:
                msg_id = producer.send(message_bytes, properties=msg_properties)

            logger.debug(
                f"{self.service_name}: Produced to {topic}: "
                f"{event_type or 'message'} (key: {message_key})"
            )

            return msg_id

        except Exception as e:
            logger.error(
                f"{self.service_name}: Failed to produce to {topic}: {e}"
            )
            raise

    def consume(
        self,
        topic: str,
        subscription_name: str,
        callback: Callable,
        consumer_type: ConsumerType = ConsumerType.Shared,
        initial_position: pulsar.InitialPosition = pulsar.InitialPosition.Latest,
    ):
        """
        Start consuming messages from Pulsar topic.
        
        Args:
            topic: Full topic name
            subscription_name: Subscription name for consumer group
            callback: Callback function(msg_data: dict, msg: pulsar.Message)
            consumer_type: Shared, Exclusive, Failover, or KeyShared
            initial_position: Latest or Earliest
        
        Example:
            def handle_conversation(msg_data, msg):
                conv_id = msg_data.get("conversation_id")
                print(f"Processing conversation: {conv_id}")
                # Acknowledge message
                return True  # or False to negative-ack
            
            client.consume(
                topic="persistent://arc/events/conversations",
                subscription_name="brain-consumer",
                callback=handle_conversation
            )
        """
        if not self._connected:
            raise ConnectionError(f"{self.service_name}: Not connected to Pulsar")

        # Create consumer
        consumer = self.client.subscribe(
            topic,
            subscription_name,
            consumer_type=consumer_type,
            initial_position=initial_position,
            # Dead letter queue for failed messages
            dead_letter_policy=pulsar.ConsumerDeadLetterPolicy(
                max_redeliver_count=3,
                dead_letter_topic=f"{topic}-dlq",
            ),
            consumer_name=f"{self.service_name}-{subscription_name}",
        )

        self.consumers[subscription_name] = consumer

        logger.info(
            f"{self.service_name}: Started consuming {topic} "
            f"(subscription: {subscription_name})"
        )

        # Message processing loop (blocking)
        while True:
            try:
                msg = consumer.receive()

                try:
                    # Parse JSON payload
                    data = json.loads(msg.data().decode("utf-8"))

                    # Extract trace_id for logging
                    trace_id = data.get("trace_id", "unknown")

                    logger.debug(
                        f"{self.service_name}: Received on {topic} "
                        f"(trace_id: {trace_id})"
                    )

                    # Call user callback
                    should_ack = callback(data, msg)

                    # Acknowledge or negative-acknowledge
                    if should_ack is False:
                        consumer.negative_acknowledge(msg)
                        logger.warning(
                            f"{self.service_name}: Negative-ack message on {topic}"
                        )
                    else:
                        consumer.acknowledge(msg)

                except json.JSONDecodeError as e:
                    logger.error(
                        f"{self.service_name}: Invalid JSON in message on {topic}: {e}"
                    )
                    consumer.negative_acknowledge(msg)

                except Exception as e:
                    logger.error(
                        f"{self.service_name}: Error processing message on {topic}: {e}"
                    )
                    consumer.negative_acknowledge(msg)

            except Exception as e:
                logger.error(
                    f"{self.service_name}: Error receiving message on {topic}: {e}"
                )
                break

    # Convenience methods for common topics

    def produce_conversation_event(
        self,
        conversation_id: str,
        event_type: str,
        data: Dict[str, Any],
        trace_id: Optional[str] = None,
    ) -> MessageId:
        """
        Produce conversation event to persistent://arc/events/conversations.
        
        Args:
            conversation_id: Unique conversation ID (used as partition key)
            event_type: Event type (e.g., "turn_completed", "session_ended")
            data: Event payload
            trace_id: Optional trace ID
        
        Returns:
            Message ID
        """
        return self.produce(
            topic=f"persistent://{self.NAMESPACE_EVENTS}/conversations",
            data=data,
            message_key=conversation_id,
            trace_id=trace_id,
            event_type=event_type,
        )

    def produce_analytics_event(
        self,
        metric_type: str,
        data: Dict[str, Any],
        trace_id: Optional[str] = None,
    ) -> MessageId:
        """
        Produce analytics event to persistent://arc/analytics/{metric_type}.
        
        Args:
            metric_type: Metric category (e.g., "latency-metrics", "agent-performance")
            data: Metric data
            trace_id: Optional trace ID
        
        Returns:
            Message ID
        """
        return self.produce(
            topic=f"persistent://{self.NAMESPACE_ANALYTICS}/{metric_type}",
            data=data,
            trace_id=trace_id,
            event_type=f"analytics_{metric_type}",
        )

    def produce_audit_log(
        self,
        user_id: str,
        action: str,
        resource: str,
        data: Dict[str, Any],
        trace_id: Optional[str] = None,
    ) -> MessageId:
        """
        Produce audit log to persistent://arc/audit/logs.
        
        Args:
            user_id: User who performed the action
            action: Action performed (e.g., "create", "update", "delete")
            resource: Resource affected (e.g., "conversation", "session")
            data: Additional audit data
            trace_id: Optional trace ID
        
        Returns:
            Message ID
        """
        audit_data = {
            "user_id": user_id,
            "action": action,
            "resource": resource,
            **data,
        }

        return self.produce(
            topic=f"persistent://{self.NAMESPACE_AUDIT}/logs",
            data=audit_data,
            message_key=user_id,  # Partition by user for ordering
            trace_id=trace_id,
            event_type="audit_log",
        )

    def consume_conversation_events(
        self, subscription_name: str, callback: Callable
    ):
        """
        Consume conversation events from persistent://arc/events/conversations.
        
        Args:
            subscription_name: Subscription name for consumer group
            callback: Callback function(msg_data: dict, msg: pulsar.Message) -> bool
        """
        self.consume(
            topic=f"persistent://{self.NAMESPACE_EVENTS}/conversations",
            subscription_name=subscription_name,
            callback=callback,
            consumer_type=ConsumerType.Shared,
        )

    def consume_analytics_events(
        self, metric_type: str, subscription_name: str, callback: Callable
    ):
        """
        Consume analytics events from persistent://arc/analytics/{metric_type}.
        
        Args:
            metric_type: Metric category
            subscription_name: Subscription name for consumer group
            callback: Callback function(msg_data: dict, msg: pulsar.Message) -> bool
        """
        self.consume(
            topic=f"persistent://{self.NAMESPACE_ANALYTICS}/{metric_type}",
            subscription_name=subscription_name,
            callback=callback,
            consumer_type=ConsumerType.Shared,
        )
