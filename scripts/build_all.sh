#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$PROJECT_DIR/frontend"
BUILD_DIR="$PROJECT_DIR/build"
VERSION=$(grep '^version:' "$FRONTEND_DIR/pubspec.yaml" | head -1 | awk '{print $2}' | sed 's/+.*//')
BUILD_NUMBER=$(date +%Y%m%d%H%M)
GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'
log()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
mkdir -p "$BUILD_DIR"
if ! command -v flutter &>/dev/null; then err "Flutter SDK not found"; fi
cd "$FRONTEND_DIR"
flutter pub get
TARGET="${1:-all}"
case "$TARGET" in
  all|android)
    log "Building Android APK..."
    flutter build apk --release --build-number="$BUILD_NUMBER"
    flutter build appbundle --release --build-number="$BUILD_NUMBER"
    cp build/app/outputs/flutter-apk/app-release.apk "$BUILD_DIR/anti-fraud-v${VERSION}-android.apk"
    log "Android: $BUILD_DIR/anti-fraud-v${VERSION}-android.apk"
    ;;&n  all|ios)
    if [[ "$(uname)" == "Darwin" ]]; then
      log "Building iOS..."
      cd ios && pod install --repo-update 2>/dev/null || true; cd ..
      flutter build ios --release --no-codesign --build-number="$BUILD_NUMBER"
      log "iOS build done (needs Xcode for IPA)"
    else
      warn "iOS build requires macOS"
    fi
    ;;
esac
echo ""
log "Build complete. Artifacts in: $BUILD_DIR"
ls -lh "$BUILD_DIR/" 2>/dev/null || warn "No artifacts found"
