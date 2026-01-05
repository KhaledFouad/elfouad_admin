#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="<PROJECT_ID>"
REGION="<REGION>"
SCHEDULER_REGION="<REGION>"
JOB_NAME="firestore-daily-backup"

SCHEDULER_SA="firestore-backup-scheduler@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "${SCHEDULER_SA}" \
  --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam service-accounts create firestore-backup-scheduler \
    --project "${PROJECT_ID}" \
    --display-name "Firestore backup scheduler"
fi

gcloud run services add-iam-policy-binding firestoreDailyBackup \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --member "serviceAccount:${SCHEDULER_SA}" \
  --role "roles/run.invoker"

FUNCTION_URL="$(gcloud functions describe firestoreDailyBackup \
  --gen2 \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --format='value(serviceConfig.uri)')"

gcloud scheduler jobs create http "${JOB_NAME}" \
  --project "${PROJECT_ID}" \
  --location "${SCHEDULER_REGION}" \
  --schedule "0 3 * * *" \
  --time-zone "Africa/Cairo" \
  --uri "${FUNCTION_URL}" \
  --http-method POST \
  --oidc-service-account-email "${SCHEDULER_SA}" \
  --oidc-token-audience "${FUNCTION_URL}"
