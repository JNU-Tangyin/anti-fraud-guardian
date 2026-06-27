"""应用配置中心"""
from __future__ import annotations

import os
from pathlib import Path
from dataclasses import dataclass

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


@dataclass
class Settings:
    host: str = os.getenv("HOST", "0.0.0.0")
    port: int = int(os.getenv("PORT", "8000"))
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"

    asr_model: str = os.getenv("ASR_MODEL", "base")
    text_embedding_model: str = os.getenv("TEXT_EMBED_MODEL", "paraphrase-multilingual-MiniLM-L12-v2")
    audio_embedding_model: str = os.getenv("AUDIO_EMBED_MODEL", "facebook/wav2vec2-base")
    fusion_alpha: float = float(os.getenv("FUSION_ALPHA", "0.5"))

    faiss_index_path: str = os.getenv("FAISS_INDEX_PATH", str(PROJECT_ROOT / "data" / "fraud_index.faiss"))
    metadata_path: str = os.getenv("METADATA_PATH", str(PROJECT_ROOT / "data" / "fraud_metadata.json"))

    high_risk_threshold: float = float(os.getenv("HIGH_RISK_THRESHOLD", "0.75"))
    medium_risk_threshold: float = float(os.getenv("MEDIUM_RISK_THRESHOLD", "0.55"))

    max_audio_seconds: int = int(os.getenv("MAX_AUDIO_SECONDS", "60"))
    sample_rate: int = int(os.getenv("SAMPLE_RATE", "16000"))

    device: str = os.getenv("DEVICE", "cpu")

    cluster_data_dir: str = os.getenv("CLUSTER_DATA_DIR", str(PROJECT_ROOT / "data" / "cluster"))
    cluster_eps: float = float(os.getenv("CLUSTER_EPS", "0.15"))
    cluster_min_samples: int = int(os.getenv("CLUSTER_MIN_SAMPLES", "5"))
    cluster_auto_trigger: int = int(os.getenv("CLUSTER_AUTO_TRIGGER", "100"))
    centroids_path: str = os.getenv("CENTROIDS_PATH", str(PROJECT_ROOT / "data" / "cluster" / "centroids.json"))
    onnx_export_dir: str = os.getenv("ONNX_EXPORT_DIR", str(PROJECT_ROOT / "data" / "models"))


settings = Settings()
