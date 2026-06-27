"""云端聚类引擎 — DBSCAN 聚类 + 质心提取 + 对比学习"""
from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional

import numpy as np

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass
class ClusterInfo:
    cluster_id: int
    size: int
    centroid: list[float]
    radius: float
    label_distribution: dict[str, int]
    dominant_label: str
    purity: float
    is_fraud_cluster: bool
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    version: int = 1


@dataclass
class ClusteringResult:
    n_samples: int
    n_clusters: int
    n_noise: int
    fraud_clusters: list[ClusterInfo]
    all_centroids: list[list[float]]
    method: str = "dbscan"
    params: dict = field(default_factory=dict)
    run_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class ClusterEngine:
    def __init__(self):
        self._vectors: list[np.ndarray] = []
        self._metadata: list[dict] = []
        self._last_result: Optional[ClusteringResult] = None

    def ingest(self, vector: np.ndarray, label: Optional[str] = None, source_text: str = "", sample_id: Optional[str] = None) -> str:
        import uuid
        sid = sample_id or str(uuid.uuid4())[:8]
        vec = vector.astype(np.float32)
        norm = np.linalg.norm(vec)
        if norm > 1e-9:
            vec = vec / norm
        self._vectors.append(vec)
        self._metadata.append({"id": sid, "label": label or "unknown", "source_text": source_text, "ingested_at": datetime.now(timezone.utc).isoformat()})
        return sid

    @property
    def n_samples(self) -> int:
        return len(self._vectors)

    def run_dbscan(self, eps: float = 0.15, min_samples: int = 5, fraud_labels: tuple = ("fraud", "spam", "scam")) -> ClusteringResult:
        from sklearn.cluster import DBSCAN
        if len(self._vectors) < min_samples:
            return ClusteringResult(n_samples=len(self._vectors), n_clusters=0, n_noise=len(self._vectors), fraud_clusters=[], all_centroids=[], params={"eps": eps, "min_samples": min_samples})
        X = np.stack(self._vectors, axis=0)
        clusterer = DBSCAN(eps=eps, min_samples=min_samples, metric="cosine")
        labels = clusterer.fit_predict(X)
        unique_labels = set(labels)
        n_clusters = len(unique_labels - {-1})
        n_noise = int(np.sum(labels == -1))
        logger.info("DBSCAN: %d samples -> %d clusters, %d noise", len(self._vectors), n_clusters, n_noise)
        all_clusters: list[ClusterInfo] = []
        for label_id in sorted(unique_labels):
            if label_id == -1:
                continue
            mask = labels == label_id
            cluster_vectors = X[mask]
            cluster_meta = [self._metadata[i] for i in range(len(self._metadata)) if mask[i]]
            centroid_raw = cluster_vectors.mean(axis=0)
            centroid_norm = np.linalg.norm(centroid_raw)
            if centroid_norm > 1e-9:
                centroid_raw /= centroid_norm
            sims = np.dot(cluster_vectors, centroid_raw)
            radius = float(1.0 - sims.mean())
            label_dist: dict[str, int] = {}
            for m in cluster_meta:
                lbl = m.get("label", "unknown")
                label_dist[lbl] = label_dist.get(lbl, 0) + 1
            dominant = max(label_dist, key=label_dist.get) if label_dist else "unknown"
            purity = label_dist[dominant] / len(cluster_meta) if cluster_meta else 0
            is_fraud = dominant in fraud_labels
            all_clusters.append(ClusterInfo(cluster_id=label_id, size=len(cluster_meta), centroid=centroid_raw.tolist(), radius=radius, label_distribution=label_dist, dominant_label=dominant, purity=purity, is_fraud_cluster=is_fraud))
        all_clusters.sort(key=lambda c: c.size, reverse=True)
        fraud_clusters = [c for c in all_clusters if c.is_fraud_cluster]
        all_centroids = [c.centroid for c in all_clusters]
        result = ClusteringResult(n_samples=len(self._vectors), n_clusters=n_clusters, n_noise=n_noise, fraud_clusters=fraud_clusters, all_centroids=all_centroids, params={"eps": eps, "min_samples": min_samples})
        self._last_result = result
        return result

    def get_fraud_centroids(self) -> list[dict]:
        if self._last_result is None:
            return []
        return [{"cluster_id": c.cluster_id, "centroid": c.centroid, "radius": c.radius, "size": c.size, "purity": c.purity, "version": c.version} for c in self._last_result.fraud_clusters]

    def get_last_result(self) -> Optional[ClusteringResult]:
        return self._last_result

    def save_vectors(self, path: Optional[str] = None):
        p = path or os.path.join(settings.cluster_data_dir, "vectors.npz")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        X = np.stack(self._vectors, axis=0) if self._vectors else np.empty((0, 0))
        np.savez_compressed(p, vectors=X)
        meta_path = p.replace(".npz", "_meta.json")
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(self._metadata, f, ensure_ascii=False, indent=2)

    def load_vectors(self, path: Optional[str] = None):
        p = path or os.path.join(settings.cluster_data_dir, "vectors.npz")
        if not os.path.exists(p):
            return
        data = np.load(p)
        self._vectors = [data["vectors"][i].astype(np.float32) for i in range(len(data["vectors"]))]
        meta_path = p.replace(".npz", "_meta.json")
        if os.path.exists(meta_path):
            with open(meta_path, "r", encoding="utf-8") as f:
                self._metadata = json.load(f)

    def save_centroids(self, path: Optional[str] = None):
        p = path or settings.centroids_path
        os.makedirs(os.path.dirname(p), exist_ok=True)
        centroids = self.get_fraud_centroids()
        payload = {"version": 1, "generated_at": datetime.now(timezone.utc).isoformat(), "model": settings.text_embedding_model, "dim": len(centroids[0]["centroid"]) if centroids else 0, "n_centroids": len(centroids), "threshold_high": settings.high_risk_threshold, "threshold_medium": settings.medium_risk_threshold, "centroids": centroids}
        with open(p, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)


class ContrastiveTrainer:
    @staticmethod
    def info_nce_loss(embeddings: np.ndarray, labels: np.ndarray, temperature: float = 0.07) -> float:
        valid = labels >= 0
        emb = embeddings[valid]
        lbl = labels[valid]
        n = len(emb)
        if n < 2:
            return 0.0
        sim = np.dot(emb, emb.T) / temperature
        pos_mask = np.equal(lbl[:, None], lbl[None, :]) & ~np.eye(n, dtype=bool)
        total_loss = 0.0
        count = 0
        for i in range(n):
            pos_idx = np.where(pos_mask[i])[0]
            if len(pos_idx) == 0:
                continue
            exp_sim = np.exp(sim[i] - sim[i].max())
            numerator = exp_sim[pos_idx].sum()
            denominator = exp_sim.sum() - np.exp(sim[i, i] - sim[i].max())
            if denominator < 1e-9:
                continue
            total_loss += -np.log(numerator / denominator)
            count += 1
        return float(total_loss / max(count, 1))

    @staticmethod
    def supcon_loss_quick(embeddings: np.ndarray, labels: np.ndarray, temperature: float = 0.1) -> float:
        valid = labels >= 0
        emb = embeddings[valid]
        lbl = labels[valid]
        n = len(emb)
        if n < 2:
            return 0.0
        sim = np.dot(emb, emb.T) / temperature
        same_label = np.equal(lbl[:, None], lbl[None, :])
        np.fill_diagonal(same_label, False)
        total = 0.0
        cnt = 0
        for i in range(n):
            pos = same_label[i]
            if pos.sum() == 0:
                continue
            max_sim = sim[i].max()
            exp_sim = np.exp(sim[i] - max_sim)
            num = exp_sim[pos].sum()
            denom = exp_sim.sum() - np.exp(sim[i, i] - max_sim)
            if denom < 1e-9:
                continue
            total += -np.log(num / denom)
            cnt += 1
        return float(total / max(cnt, 1))
