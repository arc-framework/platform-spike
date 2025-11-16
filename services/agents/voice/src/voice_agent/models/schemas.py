from typing import Optional
from pydantic import BaseModel

class VoiceInputSchema(BaseModel):
    """
    The canonical message format sent to the Pulsar input topic.
    """
    session_id: str
    text: str
    audio_data: Optional[bytes] = None
    client_type: str


class TextInputSchema(BaseModel):
    """
    The schema for the synchronous, text-only REST API endpoint.
    """
    session_id: str
    text: str
