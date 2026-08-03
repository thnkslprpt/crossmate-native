#!/usr/bin/env bash
set -euo pipefail

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/development/flutter}"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.8}"

echo "[crossmate] Installing Ubuntu prerequisites"
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk

if [[ ! -d "$FLUTTER_HOME/.git" ]]; then
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  git clone https://github.com/flutter/flutter.git \
    --branch "$FLUTTER_VERSION" \
    --depth 1 \
    "$FLUTTER_HOME"
else
  echo "[crossmate] Flutter already exists at $FLUTTER_HOME"
  git -C "$FLUTTER_HOME" fetch --tags --force
  git -C "$FLUTTER_HOME" checkout "$FLUTTER_VERSION"
fi

SHELL_RC="$HOME/.bashrc"
if [[ "${SHELL##*/}" == "zsh" ]]; then
  SHELL_RC="$HOME/.zshrc"
fi
PATH_LINE="export PATH=\"$FLUTTER_HOME/bin:\$PATH\""
if ! grep -Fq "$FLUTTER_HOME/bin" "$SHELL_RC" 2>/dev/null; then
  printf '\n# Flutter SDK\n%s\n' "$PATH_LINE" >> "$SHELL_RC"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter config --no-analytics
flutter doctor

cat <<'MSG'

Flutter is installed. Open a new terminal, then install the Android SDK.
The simplest Ubuntu route is:

  sudo snap install android-studio --classic
  android-studio

Use Android Studio's SDK Manager to install the latest Android SDK,
Android SDK Command-line Tools, Platform Tools, and one emulator image.
Then run:

  flutter doctor --android-licenses
  flutter doctor
MSG
