"""文本 Embedding 服务 — sentence-transformers"""
from __future__ import annotations

import logging

import numpy as np

from app.core.config import settings

logger = logging.getLogger(__name__)

_text_model = None


def _get_model():
    global _text_model
    if _text_model is None:
        from sentence_transformers import SentenceTransformer
        logger.info("Loading text embedding model: %s on %s", settings.text_embedding_model, settings.device)
        _text_model = SentenceTransformer(settings.text_embedding_model, device=settings.device)
    return _text_model


def embed_text(text: str) -> np.ndarray:
    if not text or not text.strip():
        dim = _get_model().get_sentence_embedding_dimension()
        return np.zeros(dim, dtype=np.float32)
    model = _get_model()
    vec = model.encode(text.strip(), normalize_embeddings=True, show_progress_bar=False)
    return vec.astype(np.float32)


def embed_batch(texts: list[str]) -> np.ndarray:
    model = _get_model()
    vecs = model.encode([t.strip() for t in texts], normalize_embeddings=True, show_progress_bar=False)
    return vecs.astype(np.float32)


def get_embedding_dim() -> int:
    return _get_model().get_sentence_embedding_dimension()
