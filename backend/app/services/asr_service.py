"""ASR 语音识别服务 — Whisper"""
from __future__ import annotations

import io
import wave
import base64
import logging

import numpy as np

from app.core.config import settings

logger = logging.getLogger(__name__)

_whisper_model = None


def _get_model():
    global _whisper_model
    if _whisper_model is None:
        import whisper
        logger.info("Loading Whisper model: %s on %s", settings.asr_model, settings.device)
        _whisper_model = whisper.load_model(settings.asr_model, device=settings.device)
    return _whisper_model


def decode_base64_audio(audio_base64: str) -> tuple[np.ndarray, int]:
    raw = base64.b64decode(audio_base64)
    try:
        with wave.open(io.BytesIO(raw), "rb") as wf:
            sr = wf.getframerate()
            n_frames = wf.getnframes()
            audio_data = wf.readframes(n_frames)
            samples = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32) / 32768.0
            return samples, sr
    except Exception:
        samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
        return samples, settings.sample_rate


def transcribe(audio_base64: str, language: str | None = None) -> dict:
    model = _get_model()
    samples, sr = decode_base64_audio(audio_base64)
    samples = samples.astype(np.float32)
    transcribe_opts = {"fp16": False}
    if language:
        transcribe_opts["language"] = language
    result = model.transcribe(samples, **transcribe_opts)
    return {
        "text": result["text"].strip(),
        "segments": [{"start": s["start"], "end": s["end"], "text": s["text"].strip()} for s in result.get("segments", [])],
        "language": result.get("language", "unknown"),
        "duration_s": len(samples) / sr,
    }
