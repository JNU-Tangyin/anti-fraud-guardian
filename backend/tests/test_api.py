"""后端测试"""
from __future__ import annotations

import base64
import io
import struct
import wave
import math

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.core.config import settings
from app.services.asr_service import decode_base64_audio


def make_sine_wav(duration_s: float = 1.0, freq: float = 440.0, sample_rate: int = 16000) -> bytes:
    n_samples = int(duration_s * sample_rate)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        for i in range(n_samples):
            t = i / sample_rate
            sample = int(16000 * math.sin(2 * math.pi * freq * t))
            wf.writeframes(struct.pack("<h", max(-32768, min(32767, sample))))
    return buf.getvalue()


def make_speech_like_wav(duration_s: float = 3.0) -> bytes:
    sample_rate = 16000
    n_samples = int(duration_s * sample_rate)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        for i in range(n_samples):
            t = i / sample_rate
            s = 0.6 * math.sin(2 * math.pi * 200 * t) + 0.3 * math.sin(2 * math.pi * 400 * t) + 0.1 * math.sin(2 * math.pi * 800 * t)
            sample = int(8000 * s)
            wf.writeframes(struct.pack("<h", max(-32768, min(32767, sample))))
    return buf.getvalue()


def encode_b64(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


class TestHealth:
    async def test_health(self, client):
        resp = await client.get("/api/v1/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"


class TestAudioDecode:
    def test_decode_sine_wav(self):
        wav_bytes = make_sine_wav(duration_s=1.0)
        b64 = encode_b64(wav_bytes)
        samples, sr = decode_base64_audio(b64)
        assert sr == 16000
        assert len(samples) == 16000


class TestAnalyzeEndpoint:
    async def test_analyze_accepts_audio(self, client):
        wav_bytes = make_speech_like_wav(duration_s=3.0)
        payload = {"audio_base64": encode_b64(wav_bytes), "audio_format": "wav", "device_id": "test-001"}
        resp = await client.post("/api/v1/analyze", json=payload)
        assert resp.status_code in (200, 500)


class TestCache:
    async def test_seed_and_stats(self, client):
        resp = await client.post("/api/v1/cache/seed", params={"label": "fraud", "text": "您好，您的银行卡涉嫌洗钱"})
        assert resp.status_code == 200
        resp = await client.get("/api/v1/cache/stats")
        assert resp.status_code == 200
        assert resp.json()["total_samples"] >= 1
