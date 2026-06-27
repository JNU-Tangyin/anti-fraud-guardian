"""欺诈 Embedding 缓存服务 — FAISS + JSON 元数据"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Optional

import numpy as np

from app.core.config import settings

logger = logging.getLogger(__name__)


class FraudCache:
    def __init__(self):
        self._index = None
        self._vectors: list[np.ndarray] = []
        self._metadata: list[dict] = []
        self._use_faiss = False
        self.dim_text: Optional[int] = None
        self.dim_audio: Optional[int] = None

    def load(self) -> None:
        try:
            import faiss
            index_path = settings.faiss_index_path
            if os.path.exists(index_path):
                self._index = faiss.read_index(index_path)
                self._use_faiss = True
                logger.info("FAISS index loaded: %d vectors", self._index.ntotal)
            else:
                logger.info("No FAISS index found, starting empty")
        except ImportError:
            logger.info("FAISS not installed, using brute-force NumPy")

        meta_path = settings.metadata_path
        if os.path.exists(meta_path):
            with open(meta_path, "r", encoding="utf-8") as f:
                self._metadata = json.load(f)
            logger.info("Metadata loaded: %d entries", len(self._metadata))
        else:
            logger.info("No metadata file, starting empty")

        if not self._use_faiss:
            self._rebuild_fallback()

    def _rebuild_fallback(self) -> None:
        self._vectors = []
        for meta in self._metadata:
            vec_data = meta.get("vector")
            if vec_data:
                self._vectors.append(np.array(vec_data, dtype=np.float32))

    def search(self, query_vec: np.ndarray, k: int = 5) -> list[dict]:
        query = query_vec.astype(np.float32).reshape(1, -1)
        if self._use_faiss and self._index is not None and self._index.ntotal > 0:
            import faiss
            similarities, indices = self._index.search(query, min(k, self._index.ntotal))
            return self._format_results(similarities[0], indices[0])
        elif self._vectors:
            vecs = np.stack(self._vectors, axis=0)
            sims = np.dot(vecs, query.T).flatten()
            top_idx = np.argsort(sims)[::-1][:k]
            return self._format_results(sims[top_idx], top_idx)
        else:
            return []

    def _format_results(self, similarities: np.ndarray, indices: np.ndarray) -> list[dict]:
        results = []
        for sim, idx in zip(similarities, indices):
            idx = int(idx)
            if idx < 0 or idx >= len(self._metadata):
                continue
            meta = self._metadata[idx]
            results.append({"id": meta.get("id", str(idx)), "label": meta.get("label", "unknown"), "similarity": round(float(sim), 4), "source_text": meta.get("source_text", "")})
        return results

    def add(self, vector: np.ndarray, label: str, source_text: str = "", sample_id: Optional[str] = None) -> str:
        import uuid
        sample_id = sample_id or str(uuid.uuid4())[:8]
        vec = vector.astype(np.float32)
        meta = {"id": sample_id, "label": label, "source_text": source_text, "vector": vec.tolist()}
        self._metadata.append(meta)
        if self._use_faiss:
            import faiss
            if self._index is None:
                self._index = faiss.IndexFlatIP(len(vec))
            self._index.add(vec.reshape(1, -1))
        else:
            self._vectors.append(vec)
        return sample_id

    def save(self) -> None:
        if self._use_faiss and self._index is not None:
            os.makedirs(os.path.dirname(settings.faiss_index_path), exist_ok=True)
            import faiss
            faiss.write_index(self._index, settings.faiss_index_path)
        os.makedirs(os.path.dirname(settings.metadata_path), exist_ok=True)
        light_meta = [{k: v for k, v in m.items() if k != "vector"} for m in self._metadata]
        for m in light_meta:
            m["vector_dim"] = len(m.get("vector", []))
        with open(settings.metadata_path, "w", encoding="utf-8") as f:
            json.dump(light_meta, f, ensure_ascii=False, indent=2)

    def stats(self) -> dict:
        dist = {}
        for m in self._metadata:
            lbl = m.get("label", "unknown")
            dist[lbl] = dist.get(lbl, 0) + 1
        return {"total_samples": len(self._metadata), "use_faiss": self._use_faiss, "labels": dist}
