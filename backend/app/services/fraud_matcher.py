"""欺诈匹配引擎 —— 双路 embedding 融合比对"""
from __future__ import annotations

import logging
import time
from typing import Optional

import numpy as np

from app.core.config import settings
from app.models.schemas import EmbeddingDetail, RiskLevel, Action
from app.services.asr_service import transcribe
from app.services.text_embedding import embed_text
from app.services.audio_embedding import embed_audio
from app.services.cache_service import FraudCache

logger = logging.getLogger(__name__)

fraud_cache: Optional[FraudCache] = None


async def get_cache() -> FraudCache:
    global fraud_cache
    if fraud_cache is None:
        fraud_cache = FraudCache()
        fraud_cache.load()
    return fraud_cache


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b))


def _build_detail(vec: np.ndarray, cache: FraudCache, path_name: str) -> EmbeddingDetail:
    top_k = cache.search(vec, k=5)
    best = top_k[0] if top_k else {"similarity": 0.0, "label": None, "id": None}
    return EmbeddingDetail(similarity=best["similarity"], matched_label=best.get("label"), top_k=[{"id": r["id"], "label": r["label"], "similarity": round(r["similarity"], 4)} for r in top_k])


def _fusion_similarity(text_sim: float, audio_sim: float) -> float:
    return settings.fusion_alpha * audio_sim + (1 - settings.fusion_alpha) * text_sim


def _decide(fused_sim: float) -> tuple[RiskLevel, Action]:
    if fused_sim >= settings.high_risk_threshold:
        return RiskLevel.high, Action.hangup
    elif fused_sim >= settings.medium_risk_threshold:
        return RiskLevel.medium, Action.warn
    else:
        return RiskLevel.low, Action.allow


async def analyze_call(audio_base64: str, request_id: str, caller_number: Optional[str] = None) -> dict:
    t0 = time.perf_counter()
    cache = await get_cache()

    try:
        asr_result = transcribe(audio_base64)
        transcript = asr_result["text"]
        text_vec = embed_text(transcript) if transcript else np.zeros(cache.dim_text or 384, dtype=np.float32)
        text_detail = _build_detail(text_vec, cache, "text")
    except Exception as exc:
        logger.warning("ASR/Text embedding failed: %s", exc)
        transcript = ""
        text_vec = np.zeros(cache.dim_text or 384, dtype=np.float32)
        text_detail = EmbeddingDetail(similarity=0.0, matched_label=None, top_k=[])

    try:
        audio_vec = embed_audio(audio_base64)
        audio_detail = _build_detail(audio_vec, cache, "audio")
    except Exception as exc:
        logger.warning("Audio embedding failed: %s", exc)
        audio_vec = np.zeros(cache.dim_audio or 768, dtype=np.float32)
        audio_detail = EmbeddingDetail(similarity=0.0, matched_label=None, top_k=[])

    fused_sim = _fusion_similarity(text_detail.similarity, audio_detail.similarity)
    risk_level, action = _decide(fused_sim)
    elapsed_ms = (time.perf_counter() - t0) * 1000

    return {
        "request_id": request_id, "risk_level": risk_level, "risk_score": round(fused_sim, 4),
        "recommended_action": action, "text_embedding": text_detail, "audio_embedding": audio_detail,
        "fused_similarity": round(fused_sim, 4), "processing_time_ms": round(elapsed_ms, 1),
        "transcript_preview": transcript[:100] if transcript else None,
    }
