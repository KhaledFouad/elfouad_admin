#!/usr/bin/env bash
set -euo pipefail

flutter clean
flutter pub get
flutter build web --release --pwa-strategy=none --base-href "/" --no-web-resources-cdn --no-wasm-dry-run
