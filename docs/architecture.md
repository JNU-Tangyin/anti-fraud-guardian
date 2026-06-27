# 反诈通话卫士 — 架构设计

## 核心方案：云端聚类 → 端侧质心匹配

诈骗/推销电话话术高度重复 → embedding 空间中形成紧密簇。
正常通话内容各异 → 散落在低密度区域。

```
云端: 匿名 embedding 上传 → DBSCAN 聚类 → 提取欺诈质心
端侧: 下载质心 → 本地 ONNX embedding → 余弦匹配 → 判定
```

## 双路 Embedding

| 路径 | 模型 | 维度 |
|------|------|------|
| 文本 | Whisper → sentence-transformers MiniLM-L12 | 384d |
| 音频 | Wav2Vec2 | 768d |

融合: score = α × audio_sim + (1-α) × text_sim

## API

| 端点 | 说明 |
|------|------|
| POST /api/v1/analyze | 云端完整分析 |
| POST /api/v1/embeddings/upload | 匿名上传 |
| GET /api/v1/centroids | 下载质心 |
| POST /api/v1/cluster/run | 触发聚类 |
