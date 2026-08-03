#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[crossmate] This script must run on macOS with Xcode installed." >&2
  exit 1
fi
if [[ ! -d ios ]]; then
  ./scripts/bootstrap.sh
fi
if ! command -v pod >/dev/null 2>&1; then
  echo "[crossmate] ERROR: CocoaPods is required. Install it on the Mac, then rerun this script." >&2
  echo "[crossmate] Homebrew command: brew install cocoapods" >&2
  exit 1
fi

flutter pub get
flutter analyze
flutter test
pushd ios >/dev/null
pod install --repo-update
popd >/dev/null
flutter build ios --release --no-codesign
open ios/Runner.xcworkspace

echo "[crossmate] In Xcode: select the Runner target, choose your Team, then Product > Archive."
