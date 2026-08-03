#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d android ]]; then
  ./scripts/bootstrap.sh
fi
if [[ ! -f android/key.properties ]]; then
  echo "[crossmate] ERROR: release signing is not configured." >&2
  echo "[crossmate] Run ./scripts/configure_android_signing.sh first." >&2
  exit 1
fi

flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
flutter build apk --release

echo "[crossmate] Play Store bundle: build/app/outputs/bundle/release/app-release.aab"
echo "[crossmate] Test APK: build/app/outputs/flutter-apk/app-release.apk"
