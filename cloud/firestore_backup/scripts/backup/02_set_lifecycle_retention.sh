#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="<PROJECT_ID>"
BUCKET_NAME="<BUCKET_NAME>"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/02_set_lifecycle_retention.json"

gcloud storage buckets update "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --lifecycle-file="${CONFIG_FILE}"
