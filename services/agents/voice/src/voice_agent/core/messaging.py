import os
import json
import asyncio
import pulsar

from ..models.schemas import VoiceInputSchema

# Load configuration from environment variables
PULSAR_URL = os.getenv("PULSAR_SERVICE_URL", "pulsar://localhost:6650")
INPUT_TOPIC = os.getenv("INPUT_TOPIC", "persistent://public/default/arc-agent-input")
OUTPUT_TOPIC = os.getenv("OUTPUT_TOPIC", "persistent://public/default/arc-agent-response")

# Global Pulsar client instance
try:
    client = pulsar.Client(PULSAR_URL)
except Exception as e:
    print(f"Could not connect to Pulsar. Please ensure it is running at {PULSAR_URL}. Error: {e}")
    client = None


class PulsarProducer:
    """A class to handle producing messages to a Pulsar topic."""
    def __init__(self):
        if not client:
            raise ConnectionError("Pulsar client is not available.")
        self._producer: pulsar.Producer = client.create_producer(INPUT_TOPIC)

    async def send_message(self, message: VoiceInputSchema):
        """Serializes the message and sends it to the input topic asynchronously."""
        data = message.model_dump_json().encode('utf-8')
        self._producer.send_async(data, None)
        print(f"Sent message for session: {message.session_id}")


class PulsarConsumer:
    """A class to handle consuming messages from a Pulsar topic."""
    def __init__(self):
        if not client:
            raise ConnectionError("Pulsar client is not available.")
        self._consumer: pulsar.Consumer = client.subscribe(
            OUTPUT_TOPIC,
            subscription_name="voice-agent-subscription"
        )

    async def stream_responses(self):
        """An async generator that yields messages as they arrive."""
        while True:
            try:
                msg: pulsar.Message = await self._consumer.receive()
                try:
                    # Yield the message data and then acknowledge it
                    yield msg.data().decode('utf-8')
                    await self._consumer.acknowledge(msg)
                except Exception:
                    # If processing fails, negatively acknowledge to allow redelivery
                    await self._consumer.negative_acknowledge(msg)
            except asyncio.CancelledError:
                print("Consumer task cancelled.")
                break
            except Exception as e:
                print(f"Error receiving from Pulsar: {e}")
                await asyncio.sleep(1)

    def close(self):
        """Closes the consumer and the client."""
        if self._consumer:
            self._consumer.close()
        if client:
            client.close()
