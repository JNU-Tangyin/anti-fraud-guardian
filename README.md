# 反诈通话卫士 (Anti-Fraud Call Guardian)

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20HarmonyOS-blue)]()
[![Backend](https://img.shields.io/badge/backend-FastAPI-green)]()
[![Frontend](https://img.shields.io/badge/frontend-Flutter-blue)]()

基于通话内容 Embedding 比对的智能反欺诈检测引擎。

## 核心思路

不依赖来电标签，而是对通话内容做 embedding：
- 云端 DBSCAN 聚类 → 提取欺诈质心
- 端侧 ONNX 本地 embedding → 与质心余弦匹配判定

## 项目结构

```
├── backend/          # Python FastAPI (15 files)
├── frontend/         # Flutter 跨平台 (12 Dart files)
├── .github/          # CI/CD 三平台自动构建
├── docs/             # 架构文档
├── scripts/          # 构建 & 部署脚本
└── docker-compose.yml
```

## 快速启动

```bash
# 后端
cd backend && pip install -r requirements.txt && python -m app.main

# 前端
cd frontend && flutter pub get && flutter run

# Docker
docker-compose up -d
```

## 核心 API

| 端点 | 说明 |
|------|------|
| `POST /api/v1/analyze` | 分析通话录音 (云端双路) |
| `POST /api/v1/embedding/upload` | 匿名上传 embedding |
| `GET /api/v1/centroids` | 下载欺诈质心 |
| `POST /api/v1/cluster/run` | 触发 DBSCAN 聚类 |

## 平台

| 平台 | 状态 |
|------|------|
| Android | ✅ APK + AAB |
| iOS | ✅ IPA (Fastlane) |
| 鸿蒙 | ⚠️ ArkUI 适配中 |
