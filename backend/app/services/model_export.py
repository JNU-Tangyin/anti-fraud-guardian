"""模型导出工具 — sentence-transformers → ONNX"""
from __future__ import annotations

import hashlib
import json
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


def export_to_onnx(model_name: str = "paraphrase-multilingual-MiniLM-L12-v2", output_dir: str | None = None, opset_version: int = 14) -> dict:
    import torch
    from sentence_transformers import SentenceTransformer
    output_dir = Path(output_dir or str(PROJECT_ROOT / "data" / "models"))
    output_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Loading model: %s", model_name)
    model = SentenceTransformer(model_name)
    dim = model.get_sentence_embedding_dimension()
    onnx_path = output_dir / "minilm-l12-v2.onnx"
    transformer = model._first_module()
    tokenizer = transformer.tokenizer
    dummy_input = tokenizer("这是一个测试句子", return_tensors="pt", padding="max_length", max_length=128, truncation=True)
    try:
        from optimum.onnxruntime import ORTModelForFeatureExtraction
        ORTModelForFeatureExtraction.from_pretrained(model_name, export=True).save_pretrained(str(output_dir))
    except ImportError:
        auto_model = transformer.auto_model
        auto_model.eval()
        torch.onnx.export(auto_model, (dummy_input["input_ids"], dummy_input["attention_mask"]), str(onnx_path), input_names=["input_ids", "attention_mask"], output_names=["last_hidden_state"], dynamic_axes={"input_ids": {0: "batch", 1: "sequence"}, "attention_mask": {0: "batch", 1: "sequence"}, "last_hidden_state": {0: "batch", 1: "sequence"}}, opset_version=opset_version, do_constant_folding=True)
    tokenizer.save_pretrained(str(output_dir))
    sha = hashlib.sha256()
    with open(str(onnx_path), "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha.update(chunk)
    fingerprint = sha.hexdigest()
    fp_path = output_dir / "model_fingerprint.json"
    with open(fp_path, "w", encoding="utf-8") as f:
        json.dump({"model_name": model_name, "dim": dim, "sha256": fingerprint}, f, ensure_ascii=False, indent=2)
    logger.info("Model fingerprint: %s", fingerprint[:16])
    return {"onnx_path": str(onnx_path), "dim": dim, "fingerprint": fingerprint}


def get_model_fingerprint() -> str | None:
    fp_path = PROJECT_ROOT / "data" / "models" / "model_fingerprint.json"
    if not fp_path.exists():
        return None
    with open(fp_path, "r", encoding="utf-8") as f:
        return json.load(f).get("sha256")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    result = export_to_onnx()
    print(f"ONNX model exported: {result['onnx_path']}")
    print(f"Fingerprint: {result['fingerprint'][:32]}...")
