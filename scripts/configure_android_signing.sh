#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d android ]]; then
  echo "[crossmate] Run ./scripts/bootstrap.sh first." >&2
  exit 1
fi
if ! command -v keytool >/dev/null 2>&1; then
  echo "[crossmate] keytool was not found. Install OpenJDK 17." >&2
  exit 1
fi

KEY_DIR="${CROSSMATE_KEY_DIR:-$HOME/.crossmate-keys}"
KEYSTORE="$KEY_DIR/crossmate-upload-keystore.jks"
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

if [[ ! -f "$KEYSTORE" ]]; then
  echo "[crossmate] Creating the Google Play upload key at $KEYSTORE"
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias upload \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000
else
  echo "[crossmate] Reusing $KEYSTORE"
fi

read -r -s -p "Keystore password: " STORE_PASSWORD
echo
read -r -s -p "Key password (usually the same): " KEY_PASSWORD
echo

cat > android/key.properties <<KEYEOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=upload
storeFile=$KEYSTORE
KEYEOF
chmod 600 android/key.properties

echo "[crossmate] Signing configuration written to android/key.properties"
echo "[crossmate] Back up $KEYSTORE and its passwords somewhere secure."
