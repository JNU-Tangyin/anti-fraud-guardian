"""Pydantic 请求/响应模型"""
from __future__ import annotations

from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class RiskLevel(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class Action(str, Enum):
    allow = "allow"
    warn = "warn"
    hangup = "hangup"


class AnalyzeRequest(BaseModel):
    audio_base64: str = Field(..., description="通话前1分钟录音，base64 编码的 WAV/PCM")
    audio_format: str = Field(default="wav")
    caller_number: Optional[str] = Field(default=None)
    device_id: str = Field(...)


class FeedbackRequest(BaseModel):
    request_id: str = Field(...)
    user_label: str = Field(..., description="fraud / normal / spam")
    notes: Optional[str] = Field(default=None)


class EmbeddingDetail(BaseModel):
    similarity: float
    matched_label: Optional[str] = None
    top_k: list[dict] = Field(default_factory=list)


class AnalyzeResponse(BaseModel):
    request_id: str
    risk_level: RiskLevel
    risk_score: float
    recommended_action: Action
    text_embedding: Optional[EmbeddingDetail] = None
    audio_embedding: Optional[EmbeddingDetail] = None
    fused_similarity: float = 0.0
    processing_time_ms: float = 0.0
    transcript_preview: Optional[str] = None


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str
    models_loaded: dict


class EmbeddingUploadRequest(BaseModel):
    embedding: list[float]
    embedding_type: str = Field(default="text")
    label: Optional[str] = None
    source_text: Optional[str] = None
    device_id: Optional[str] = None


class CentroidInfo(BaseModel):
    cluster_id: int
    centroid: list[float]
    radius: float
    size: int
    purity: float
    version: int


class CentroidsResponse(BaseModel):
    version: int
    generated_at: str
    model: str
    model_fingerprint: str = ""
    dim: int
    n_centroids: int
    threshold_high: float
    threshold_medium: float
    centroids: list[CentroidInfo]


class ClusterRunResponse(BaseModel):
    n_samples: int
    n_clusters: int
    n_noise: int
    n_fraud_clusters: int
    fraud_clusters: list[dict]
    run_at: str


class ClusterStats(BaseModel):
    total_samples: int
    last_cluster_run: Optional[str] = None
    n_fraud_centroids: int = 0
    centroids_version: int = 0
