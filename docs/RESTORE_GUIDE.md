# Firestore Restore Guide (Safe)

Restores should be treated as a last resort. Prefer restoring into a separate
project first to validate the data and avoid overwriting production.

## 1) List Available Backups

```bash
gcloud storage ls "gs://<BUCKET_NAME>/firestore-backups/"
gcloud storage ls "gs://<BUCKET_NAME>/firestore-backups/YYYY-MM-DD/"
```

Pick the most recent timestamp folder:

```
gs://<BUCKET_NAME>/firestore-backups/YYYY-MM-DD/HHmmss/
```

## 2) Restore to a Test Project (Recommended)

```bash
gcloud firestore import \
  "gs://<BUCKET_NAME>/firestore-backups/YYYY-MM-DD/HHmmss/" \
  --project <PROJECT_ID> \
  --database "(default)"
```

## 3) Production Restore (If Approved)

1) Stop all writes (disable app or restrict access).
2) Run the import command above for production.
3) Verify core collections (`sales`, `expenses`, `products`, `drinks`, `extras`).

## Warnings

- Import overwrites documents with matching IDs.
- Import does **not** delete documents that are missing from the backup.
- You may need cleanup after restore if newer docs should be removed.

## Suggested Safety Steps

- Restore into a separate project first.
- Validate key screens and metrics.
- Re-point the app only after verification.
