import asyncio
from fastapi import APIRouter, WebSocket, status, Depends
from pipecat.frames.frames import TextFrame
# This is the correct import path and the correct, case-sensitive class name.
from pipecat.transports.websocket.fastapi import FastAPIWebsocketTransport

from ...models.schemas import TextInputSchema, VoiceInputSchema
from ...core.messaging import PulsarProducer, PulsarConsumer

router = APIRouter(prefix="/api/v1")

# Dependency injection for Pulsar producer
def get_producer() -> PulsarProducer:
    return PulsarProducer()

@router.post("/text", status_code=status.HTTP_202_ACCEPTED)
async def text_only_input(
    input_data: TextInputSchema,
    producer: PulsarProducer = Depends(get_producer)
):
    message = VoiceInputSchema(
        session_id=input_data.session_id,
        text=input_data.text,
        client_type="rest"
    )
    await producer.send_message(message)
    return {"session_id": input_data.session_id}


@router.websocket("/ws/voice")
async def websocket_voice_stream(
    websocket: WebSocket,
    producer: PulsarProducer = Depends(get_producer)
):
    await websocket.accept()
    consumer = PulsarConsumer()

    async def handle_pipecat_frames(frame):
        if isinstance(frame, TextFrame):
            message = VoiceInputSchema(
                session_id=str(websocket.client),
                text=frame.text,
                client_type="websocket"
            )
            await producer.send_message(message)

    # Use the correct, case-sensitive class name here.
    transport = FastAPIWebsocketTransport(websocket)

    async def stream_from_pulsar_to_client():
        try:
            async for message_text in consumer.stream_responses():
                await websocket.send_text(message_text)
        except asyncio.CancelledError:
            pass
        finally:
            consumer.close()

    streaming_task = asyncio.create_task(stream_from_pulsar_to_client())
    try:
        await transport.run()
    finally:
        streaming_task.cancel()
        await streaming_task
