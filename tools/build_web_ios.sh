#!/usr/bin/env bash
set -euo pipefail

flutter clean
flutter pub get
flutter build web --release --web-renderer html --pwa-strategy=none --base-href "/"
