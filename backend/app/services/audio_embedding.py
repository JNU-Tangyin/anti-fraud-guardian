"""音频直接 Embedding 服务 — Wav2Vec2"""
from __future__ import annotations

import logging

import numpy as np
import torch

from app.core.config import settings
from app.services.asr_service import decode_base64_audio

logger = logging.getLogger(__name__)

_audio_model = None
_processor = None


def _get_models():
    global _audio_model, _processor
    if _audio_model is None:
        from transformers import Wav2Vec2Model, Wav2Vec2Processor
        logger.info("Loading audio embedding model: %s on %s", settings.audio_embedding_model, settings.device)
        _processor = Wav2Vec2Processor.from_pretrained(settings.audio_embedding_model)
        _audio_model = Wav2Vec2Model.from_pretrained(settings.audio_embedding_model)
        _audio_model = _audio_model.to(settings.device)
        _audio_model.eval()
    return _audio_model, _processor


def _mean_pool(embeddings: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
    mask = attention_mask.unsqueeze(-1).float()
    return (embeddings * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1e-9)


def embed_audio(audio_base64: str) -> np.ndarray:
    model, processor = _get_models()
    samples, sr = decode_base64_audio(audio_base64)
    max_len = settings.max_audio_seconds * 16000
    if len(samples) > max_len:
        samples = samples[:max_len]
    inputs = processor(samples, sampling_rate=16000, return_tensors="pt", padding=True)
    inputs = {k: v.to(settings.device) for k, v in inputs.items()}
    with torch.no_grad():
        outputs = model(**inputs)
        pooled = _mean_pool(outputs.last_hidden_state, inputs["attention_mask"])
    vec = pooled.squeeze(0).cpu().numpy().astype(np.float32)
    norm = np.linalg.norm(vec)
    if norm > 1e-9:
        vec = vec / norm
    return vec


def get_audio_embedding_dim() -> int:
    model, _ = _get_models()
    return model.config.hidden_size
