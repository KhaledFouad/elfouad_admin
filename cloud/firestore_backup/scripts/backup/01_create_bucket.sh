#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="<PROJECT_ID>"
BUCKET_NAME="<BUCKET_NAME>"
LOCATION="<REGION>"

gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${LOCATION}" \
  --uniform-bucket-level-access \
  --public-access-prevention=enforced
