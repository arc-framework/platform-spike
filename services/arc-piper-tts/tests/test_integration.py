"""
Integration test for arc-piper-tts service.

Tests the /tts and /health endpoints.
"""

import httpx
import pytest


@pytest.fixture
def client():
    """Test client pointing to local service"""
    return httpx.AsyncClient(base_url="http://localhost:8000", timeout=30.0)


@pytest.mark.asyncio
async def test_health_check(client):
    """Test /health endpoint returns 200 and correct schema"""
    response = await client.get("/health")
    assert response.status_code == 200
    
    data = response.json()
    assert data["service"] == "arc-piper-tts"
    assert data["status"] in ["healthy", "degraded"]
    assert "model_loaded" in data
    assert "model_name" in data


@pytest.mark.asyncio
async def test_root_endpoint(client):
    """Test / endpoint returns service info"""
    response = await client.get("/")
    assert response.status_code == 200
    
    data = response.json()
    assert data["service"] == "arc-piper-tts"
    assert data["version"] == "0.1.0"


@pytest.mark.asyncio
async def test_tts_synthesis(client):
    """Test POST /tts endpoint returns WAV audio"""
    payload = {"text": "Hello, this is a test."}
    response = await client.post("/tts", json=payload)
    
    # Should return 200 if model loaded, 503 if not
    assert response.status_code in [200, 503]
    
    if response.status_code == 200:
        # Check content type
        assert response.headers["content-type"] == "audio/wav"
        
        # Check WAV header is present
        content = response.content
        assert content[:4] == b"RIFF"  # WAV file signature
        assert len(content) > 1000  # Should have audio data


@pytest.mark.asyncio
async def test_tts_empty_text(client):
    """Test POST /tts with empty text returns validation error"""
    payload = {"text": ""}
    response = await client.post("/tts", json=payload)
    
    # Should fail validation (422) or be unavailable (503)
    assert response.status_code in [422, 503]


@pytest.mark.asyncio
async def test_tts_long_text(client):
    """Test POST /tts with longer text"""
    payload = {"text": "This is a longer test sentence. " * 10}
    response = await client.post("/tts", json=payload)
    
    # Should return 200 if model loaded, 503 if not
    assert response.status_code in [200, 503]
    
    if response.status_code == 200:
        assert response.headers["content-type"] == "audio/wav"
        assert len(response.content) > 5000  # Longer audio
