# Firestore Daily Backup Setup

This guide sets up a daily Firestore export to GCS using Cloud Scheduler + HTTP Cloud Function.

## Prerequisites

- `gcloud` installed and authenticated.
- Billing enabled on the project.
- Firestore in Native mode.

## 1) Configure Variables

Pick values and replace placeholders in the scripts:

- `<PROJECT_ID>`
- `<BUCKET_NAME>`
- `<REGION>` (use the same region for functions and scheduler)

Optional:
- `EXPORT_COLLECTION_IDS` (comma-separated list) in `03_deploy_function.sh`

## 2) Create the GCS Bucket

Run:

```bash
cloud/firestore_backup/scripts/backup/01_create_bucket.sh
```

## 3) Set Lifecycle Retention

Edit `cloud/firestore_backup/scripts/backup/02_set_lifecycle_retention.json`
and update the `age` field to match your retention (e.g., 30 or 60 days).

Apply:

```bash
cloud/firestore_backup/scripts/backup/02_set_lifecycle_retention.sh
```

## 4) Deploy the Cloud Function

Run:

```bash
cloud/firestore_backup/scripts/backup/03_deploy_function.sh
```

This creates a dedicated service account and grants:
- `roles/datastore.importExportAdmin`
- `roles/storage.objectAdmin`

## 5) Create the Scheduler Job

Run:

```bash
cloud/firestore_backup/scripts/backup/04_create_scheduler_job.sh
```

Schedule: `0 3 * * *` (Africa/Cairo) with OIDC.

## Verify Checklist

- Cloud Function `firestoreDailyBackup` deployed.
- Cloud Scheduler job runs daily at 03:00 Africa/Cairo.
- GCS bucket contains `firestore-backups/YYYY-MM-DD/HHmmss/`.
- Lifecycle rule deletes objects older than your retention days.

## Manual Test (Optional)

```bash
FUNCTION_URL="$(gcloud functions describe firestoreDailyBackup \
  --gen2 --project <PROJECT_ID> --region <REGION> \
  --format='value(serviceConfig.uri)')"

curl -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{}'
```
