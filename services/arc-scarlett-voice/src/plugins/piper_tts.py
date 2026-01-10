"""
Piper TTS Plugin for LiveKit Agents SDK
Embedded ONNX-based text-to-speech synthesis
"""

import os
import io
import wave
from typing import Optional, AsyncIterator

from livekit.agents import tts
from piper import PiperVoice
import structlog

logger = structlog.get_logger()

# ==============================================================================
# Piper TTS Plugin
# ==============================================================================

class PiperTTS(tts.TTS):
    """
    Custom TTS plugin using Piper ONNX for local text-to-speech synthesis.

    Piper provides high-quality voices with low latency and no cloud dependencies.
    """

    def __init__(
        self,
        model_path: Optional[str] = None,
        sample_rate: int = 22050
    ):
        """
        Initialize Piper TTS plugin.

        Args:
            model_path: Path to Piper ONNX model file (defaults to PIPER_MODEL_PATH env var)
            sample_rate: Audio sample rate (default: 22050 Hz for en_US-lessac-medium)
        """
        super().__init__()
        self.model_path = model_path or os.getenv(
            "PIPER_MODEL_PATH",
            "/app/models/en_US-lessac-medium.onnx"
        )
        self.sample_rate = sample_rate
        self.voice: Optional[PiperVoice] = None

        # Load model at initialization
        self._load_model()

    def _load_model(self):
        """Load Piper voice model from ONNX file."""
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"Piper model not found: {self.model_path}")

        logger.info("piper_tts.loading_model", path=self.model_path)

        try:
            self.voice = PiperVoice.load(self.model_path)
            logger.info(
                "piper_tts.model_loaded",
                path=self.model_path,
                sample_rate=self.sample_rate
            )
        except Exception as e:
            logger.error("piper_tts.load_error", error=str(e), path=self.model_path)
            raise

    async def synthesize(
        self,
        text: str,
        conn_options: Optional[tts.SynthesizeConnectionOptions] = None
    ) -> "tts.ChunkedStream":
        """
        Synthesize text to speech (non-streaming).

        Args:
            text: Text to synthesize
            conn_options: Connection options (not used)

        Returns:
            ChunkedStream with audio data
        """
        logger.info("piper_tts.synthesize_start", text_length=len(text))

        # Generate audio using Piper
        audio_bytes = self._synthesize_audio(text)

        # Create chunked stream
        return PiperChunkedStream(audio_bytes, self.sample_rate, text)

    async def astream_synthesize(
        self,
        text: str,
        conn_options: Optional[tts.SynthesizeConnectionOptions] = None
    ) -> AsyncIterator["tts.ChunkedStream"]:
        """
        Streaming synthesis (delegates to non-streaming for now).

        Args:
            text: Text to synthesize
            conn_options: Connection options

        Yields:
            ChunkedStream with audio
        """
        # Piper doesn't natively support streaming, so we yield entire audio as single chunk
        stream = await self.synthesize(text, conn_options)
        yield stream

    def _synthesize_audio(self, text: str) -> bytes:
        """
        Internal method to synthesize audio using Piper.

        Args:
            text: Text to synthesize

        Returns:
            Raw audio bytes (PCM 16-bit)
        """
        if not self.voice:
            raise RuntimeError("Piper voice not loaded. Call _load_model() first.")

        # Synthesize with Piper (returns generator of audio chunks)
        audio_chunks = []
        for audio_chunk in self.voice.synthesize(text):
            audio_chunks.append(audio_chunk)

        # Concatenate all chunks
        audio_bytes = b"".join(audio_chunks)

        logger.info(
            "piper_tts.synthesize_complete",
            text_length=len(text),
            audio_size=len(audio_bytes)
        )

        return audio_bytes


# ==============================================================================
# Chunked Stream Implementation
# ==============================================================================

class PiperChunkedStream(tts.ChunkedStream):
    """
    Chunked stream for Piper TTS audio output.

    Wraps raw PCM audio in LiveKit's ChunkedStream format.
    """

    def __init__(self, audio_bytes: bytes, sample_rate: int, text: str):
        """
        Initialize chunked stream.

        Args:
            audio_bytes: Raw PCM audio data
            sample_rate: Audio sample rate (Hz)
            text: Original text that was synthesized
        """
        super().__init__(tts=None, input_text=text)
        self.audio_bytes = audio_bytes
        self.sample_rate = sample_rate
        self.text = text
        self._index = 0
        self._chunk_size = sample_rate * 2  # ~1 second chunks (16-bit PCM)

    async def __anext__(self) -> tts.SynthesizedAudio:
        """
        Return next chunk of audio.

        Returns:
            SynthesizedAudio chunk

        Raises:
            StopAsyncIteration: When all chunks have been yielded
        """
        if self._index >= len(self.audio_bytes):
            raise StopAsyncIteration

        # Get next chunk
        start = self._index
        end = min(start + self._chunk_size, len(self.audio_bytes))
        chunk = self.audio_bytes[start:end]
        self._index = end

        # Create WAV-formatted audio for LiveKit
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, "wb") as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(self.sample_rate)
            wav_file.writeframes(chunk)

        wav_bytes = wav_buffer.getvalue()

        # Return SynthesizedAudio chunk
        return tts.SynthesizedAudio(
            frame=tts.AudioFrame(
                data=wav_bytes,
                sample_rate=self.sample_rate,
                num_channels=1,
                samples_per_channel=len(chunk) // 2  # 16-bit = 2 bytes per sample
            )
        )

    def __aiter__(self):
        """Return async iterator."""
        return self


# ==============================================================================
# Testing / Development
# ==============================================================================

if __name__ == "__main__":
    import asyncio

    async def test_piper_tts():
        """Quick test of Piper TTS plugin."""
        tts_plugin = PiperTTS()

        # Test synthesis
        text = "Hello! This is a test of the Piper text-to-speech system."
        stream = await tts_plugin.synthesize(text)

        audio_chunks = []
        async for audio in stream:
            audio_chunks.append(audio.frame.data)
            print(f"✓ Generated audio chunk: {len(audio.frame.data)} bytes")

        total_size = sum(len(chunk) for chunk in audio_chunks)
        print(f"✓ Total audio size: {total_size} bytes")
        print("✓ Piper TTS test complete")

    asyncio.run(test_piper_tts())
