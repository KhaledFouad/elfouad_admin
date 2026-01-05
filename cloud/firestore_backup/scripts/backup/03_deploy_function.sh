#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="<PROJECT_ID>"
REGION="<REGION>"
BUCKET_NAME="<BUCKET_NAME>"
DATABASE_ID="(default)"
RETENTION_DAYS="60"
EXPORT_COLLECTION_IDS=""

FUNCTION_SA="firestore-backup-sa@${PROJECT_ID}.iam.gserviceaccount.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

gcloud services enable \
  firestore.googleapis.com \
  storage.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  cloudscheduler.googleapis.com \
  iamcredentials.googleapis.com \
  --project "${PROJECT_ID}"

if ! gcloud iam service-accounts describe "${FUNCTION_SA}" \
  --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam service-accounts create firestore-backup-sa \
    --project "${PROJECT_ID}" \
    --display-name "Firestore backup function"
fi

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${FUNCTION_SA}" \
  --role "roles/datastore.importExportAdmin"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${FUNCTION_SA}" \
  --role "roles/storage.objectAdmin"

ENV_VARS="BUCKET_NAME=${BUCKET_NAME},DATABASE_ID=${DATABASE_ID},RETENTION_DAYS=${RETENTION_DAYS}"
if [ -n "${EXPORT_COLLECTION_IDS}" ]; then
  ENV_VARS="${ENV_VARS},EXPORT_COLLECTION_IDS=${EXPORT_COLLECTION_IDS}"
fi

gcloud functions deploy firestoreDailyBackup \
  --gen2 \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --runtime python311 \
  --source "${SOURCE_DIR}" \
  --entry-point firestoreDailyBackup \
  --trigger-http \
  --no-allow-unauthenticated \
  --service-account "${FUNCTION_SA}" \
  --set-env-vars "${ENV_VARS}"
