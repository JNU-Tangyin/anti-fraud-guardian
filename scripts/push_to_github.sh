#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_USER="JNU-Tangyin"
REPO_NAME="anti-fraud-guardian"
cd "$PROJECT_DIR"
echo "Pushing to $GITHUB_USER/$REPO_NAME..."
if [ ! -d ".git" ]; then git init && git checkout -b main; fi
git add .
git commit -m "Update: anti-fraud-guardian" || echo "(nothing to commit)"
if git remote | grep -q origin; then git remote set-url origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"; else git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"; fi
git push -u origin main
echo "Done: https://github.com/$GITHUB_USER/$REPO_NAME"
