# ═══════════════════════════════════════════════════════════════
# 反诈卫士 — 快速构建参考
# ═══════════════════════════════════════════════════════════════

.PHONY: help setup build-android build-ios build-all clean docker

VERSION := $(shell grep '^version:' frontend/pubspec.yaml | head -1 | awk '{print $$2}' | sed 's/+.*//')

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## 初始化开发环境
	cd frontend && flutter pub get
	cd frontend && flutter create --platforms=android,ios .
	cd backend && pip install -r requirements.txt

backend: ## 启动后端服务
	cd backend && python -m app.main

docker: ## 构建 Docker 镜像
	docker-compose build && docker-compose up -d

build-android: ## 构建 Android APK
	bash scripts/build_all.sh android

build-ios: ## 构建 iOS IPA (仅 macOS)
	bash scripts/build_all.sh ios

build-all: ## 构建所有平台
	bash scripts/build_all.sh all

model-export: ## 导出 ONNX 模型
	cd backend && python -m app.services.model_export

seed-data: ## 播种测试数据
	curl -X POST "http://localhost:8000/api/v1/cache/seed?label=fraud&text=您好您的银行卡涉嫌洗钱请配合调查"
	curl -X POST "http://localhost:8000/api/v1/cache/seed?label=fraud&text=恭喜您中奖了请先缴纳手续费"
	curl -X POST "http://localhost:8000/api/v1/cache/seed?label=normal&text=晚上一起吃饭吗"

test: ## 运行测试
	cd backend && python -m pytest tests/ -v

clean: ## 清理构建产物
	rm -rf build/
	cd frontend && flutter clean

version: ## 显示版本
	@echo "Version: $(VERSION)"
