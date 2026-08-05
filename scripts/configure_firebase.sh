#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# CROSSMATE_SHARED_RULES_GUARD:START
RULES_FILE="$ROOT/firebase/database.rules.json"
if ! grep -Fq '"crossmateRooms"' "$RULES_FILE" || ! grep -Fq '"crossmateNativeRooms"' "$RULES_FILE"; then
  echo "[crossmate] Refusing to deploy an incomplete shared Realtime Database ruleset." >&2
  echo "[crossmate] firebase/database.rules.json must preserve crossmateRooms and crossmateNativeRooms." >&2
  exit 1
fi
if grep -Fq '"shapeSiegeRooms"' "$RULES_FILE"; then
  echo "[crossmate] Refusing to deploy rules containing the retired legacy room path." >&2
  exit 1
fi
# CROSSMATE_SHARED_RULES_GUARD:END

PROJECT_ID="${1:-}"
if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 YOUR_FIREBASE_PROJECT_ID" >&2
  exit 1
fi

PLATFORMS=()
ARGS=()
if [[ -d android ]]; then
  PLATFORMS+=(android)
  ARGS+=(--android-package-name com.gidigames.crossmate)
fi
if [[ -d ios ]]; then
  PLATFORMS+=(ios)
  ARGS+=(--ios-bundle-id com.gidigames.crossmate)
fi
if [[ ${#PLATFORMS[@]} -eq 0 ]]; then
  echo "[crossmate] Run ./scripts/bootstrap.sh first." >&2
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "[crossmate] Node.js/npm is required for Firebase CLI." >&2
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  npm install -g firebase-tools
fi
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"

PLATFORM_CSV="$(IFS=,; echo "${PLATFORMS[*]}")"
firebase login
flutterfire configure \
  --project "$PROJECT_ID" \
  --platforms "$PLATFORM_CSV" \
  "${ARGS[@]}" \
  --yes

firebase use "$PROJECT_ID"
firebase deploy --only database

echo "[crossmate] Configured Firebase for: $PLATFORM_CSV"
echo "[crossmate] Enable Anonymous sign-in in Firebase Console > Authentication > Sign-in method."
echo "[crossmate] Native online rooms use the crossmateNativeRooms database node."
echo "[crossmate] The deployed shared rules also preserve browser rooms under crossmateRooms."
echo "[crossmate] Firebase mobile config files are intentionally ignored by Git."
echo "[crossmate] Run this script again on macOS after the iOS host is generated."
