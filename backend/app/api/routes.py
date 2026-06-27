"""API 路由"""
from __future__ import annotations

import uuid
import logging
from datetime import datetime, timezone
from typing import Optional

import numpy as np

from fastapi import APIRouter, HTTPException

from app import __version__
from app.core.config import settings
from app.models.schemas import (
    AnalyzeRequest, AnalyzeResponse, FeedbackRequest, HealthResponse,
    EmbeddingUploadRequest, CentroidsResponse, CentroidInfo,
    ClusterRunResponse, ClusterStats,
)
from app.services.fraud_matcher import analyze_call, get_cache
from app.services.cluster_service import ClusterEngine, ContrastiveTrainer

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["anti-fraud"])


@router.get("/health", response_model=HealthResponse)
async def health():
    models_loaded = {
        "asr": settings.asr_model,
        "text_embedding": settings.text_embedding_model,
        "audio_embedding": settings.audio_embedding_model,
        "device": settings.device,
    }
    return HealthResponse(version=__version__, models_loaded=models_loaded)


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze(req: AnalyzeRequest):
    request_id = str(uuid.uuid4())[:12]
    try:
        result = await analyze_call(
            audio_base64=req.audio_base64,
            request_id=request_id,
            caller_number=req.caller_number,
        )
        return AnalyzeResponse(**result)
    except Exception as exc:
        logger.exception("Analysis failed for request %s", request_id)
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/feedback")
async def feedback(req: FeedbackRequest):
    return {"status": "received", "request_id": req.request_id, "label": req.user_label}


@router.get("/cache/stats")
async def cache_stats():
    cache = await get_cache()
    return cache.stats()


@router.post("/cache/seed")
async def seed_sample(label: str, text: str):
    from app.services.text_embedding import embed_text
    cache = await get_cache()
    vec = embed_text(text)
    sample_id = cache.add(vector=vec, label=label, source_text=text)
    cache.save()
    return {"sample_id": sample_id, "label": label, "text": text}


_cluster_engine: Optional[ClusterEngine] = None


def _get_cluster_engine() -> ClusterEngine:
    global _cluster_engine
    if _cluster_engine is None:
        _cluster_engine = ClusterEngine()
        _cluster_engine.load_vectors()
    return _cluster_engine


@router.post("/embeddings/upload")
async def upload_embedding(req: EmbeddingUploadRequest):
    engine = _get_cluster_engine()
    vec = np.array(req.embedding, dtype=np.float32)
    sample_id = engine.ingest(vector=vec, label=req.label, source_text=req.source_text or "")
    auto_triggered = False
    if engine.n_samples >= settings.cluster_auto_trigger:
        try:
            engine.run_dbscan(eps=settings.cluster_eps, min_samples=settings.cluster_min_samples)
            engine.save_vectors()
            engine.save_centroids()
            auto_triggered = True
        except Exception as e:
            logger.warning("Auto-clustering failed: %s", e)
    return {"status": "ingested", "sample_id": sample_id, "total_samples": engine.n_samples, "auto_clustered": auto_triggered}


def _get_model_fingerprint() -> str:
    from app.services.model_export import get_model_fingerprint
    return get_model_fingerprint() or "not_exported"


@router.get("/centroids", response_model=CentroidsResponse)
async def get_centroids(version: int = 0):
    engine = _get_cluster_engine()
    centroids_data = engine.get_fraud_centroids()
    current_version = 1
    return CentroidsResponse(
        version=current_version,
        generated_at=datetime.now(timezone.utc).isoformat(),
        model=settings.text_embedding_model,
        model_fingerprint=_get_model_fingerprint(),
        dim=len(centroids_data[0]["centroid"]) if centroids_data else 0,
        n_centroids=len(centroids_data),
        threshold_high=settings.high_risk_threshold,
        threshold_medium=settings.medium_risk_threshold,
        centroids=[CentroidInfo(**c) for c in centroids_data],
    )


@router.post("/cluster/run", response_model=ClusterRunResponse)
async def run_clustering(eps: float = 0.15, min_samples: int = 5):
    engine = _get_cluster_engine()
    if engine.n_samples < min_samples:
        raise HTTPException(status_code=400, detail=f"Need at least {min_samples} samples")
    result = engine.run_dbscan(eps=eps, min_samples=min_samples)
    engine.save_vectors()
    engine.save_centroids()
    return ClusterRunResponse(
        n_samples=result.n_samples, n_clusters=result.n_clusters, n_noise=result.n_noise,
        n_fraud_clusters=len(result.fraud_clusters),
        fraud_clusters=[{"cluster_id": c.cluster_id, "size": c.size, "dominant_label": c.dominant_label, "purity": round(c.purity, 3), "radius": round(c.radius, 4)} for c in result.fraud_clusters],
        run_at=result.run_at,
    )


@router.get("/cluster/stats", response_model=ClusterStats)
async def cluster_stats():
    engine = _get_cluster_engine()
    last = engine.get_last_result()
    return ClusterStats(total_samples=engine.n_samples, last_cluster_run=last.run_at if last else None, n_fraud_centroids=len(last.fraud_clusters) if last else 0, centroids_version=1)


@router.post("/cluster/contrastive-loss")
async def compute_contrastive_loss(eps: float = 0.15, min_samples: int = 5):
    engine = _get_cluster_engine()
    if engine.n_samples < 10:
        raise HTTPException(status_code=400, detail="Need at least 10 samples")
    from sklearn.cluster import DBSCAN
    X = np.stack(engine._vectors, axis=0)
    labels = DBSCAN(eps=eps, min_samples=min_samples, metric="cosine").fit_predict(X)
    loss = ContrastiveTrainer.info_nce_loss(X, labels)
    supcon = ContrastiveTrainer.supcon_loss_quick(X, labels)
    return {"n_samples": len(X), "n_clusters": len(set(labels) - {-1}), "n_noise": int(np.sum(labels == -1)), "info_nce_loss": round(loss, 4), "supcon_loss": round(supcon, 4)}
