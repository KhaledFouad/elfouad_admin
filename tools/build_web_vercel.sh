#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.38.9}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_SDK_DIR="${HOME}/.cache/flutter-sdk-${FLUTTER_VERSION}"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    return 0
  fi

  if [ ! -x "${FLUTTER_SDK_DIR}/bin/flutter" ]; then
    echo "Flutter SDK not found. Installing version: ${FLUTTER_VERSION}"
    rm -rf "${FLUTTER_SDK_DIR}"
    if ! git clone \
      --depth 1 \
      --branch "${FLUTTER_VERSION}" \
      https://github.com/flutter/flutter.git \
      "${FLUTTER_SDK_DIR}"; then
      echo "Version ${FLUTTER_VERSION} not found. Falling back to channel: ${FLUTTER_CHANNEL}"
      rm -rf "${FLUTTER_SDK_DIR}"
      git clone \
        --depth 1 \
        --branch "${FLUTTER_CHANNEL}" \
        https://github.com/flutter/flutter.git \
        "${FLUTTER_SDK_DIR}"
    fi
  fi

  export PATH="${FLUTTER_SDK_DIR}/bin:${PATH}"
}

ensure_flutter

echo "Using Flutter: $(command -v flutter)"
flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true
flutter precache --web
flutter pub get
flutter build web --release --pwa-strategy=none --base-href "/" --no-web-resources-cdn --no-wasm-dry-run
