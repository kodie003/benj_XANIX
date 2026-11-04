#!/usr/bin/env bash
# Vercel has no Flutter in its build image, so fetch the SDK, then build the web app.
# The Python insight engine in api/ is deployed by Vercel automatically.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.5}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

if ! command -v unzip >/dev/null 2>&1; then
  dnf install -y unzip >/dev/null 2>&1 || yum install -y unzip >/dev/null 2>&1 || true
fi

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics --enable-web >/dev/null
flutter --version
flutter pub get
flutter build web --release
