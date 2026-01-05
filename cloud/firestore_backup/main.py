import datetime
import json
import logging
import os

import google.auth
from google.auth.transport.requests import Request
import requests


def _get_project_id() -> str:
    return (
        os.environ.get("GCP_PROJECT")
        or os.environ.get("GOOGLE_CLOUD_PROJECT")
        or os.environ.get("PROJECT_ID")
        or ""
    )


def _parse_collection_ids(raw: str | None) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split(",") if part.strip()]


def firestoreDailyBackup(request):
    if request.method not in ("POST", "GET"):
        return ("Method not allowed", 405)

    bucket = os.environ.get("BUCKET_NAME", "").strip()
    if not bucket:
        return ("BUCKET_NAME is required.", 500)

    project_id = _get_project_id()
    if not project_id:
        return ("Project ID not detected.", 500)

    database_id = os.environ.get("DATABASE_ID", "(default)").strip() or "(default)"
    retention_days = os.environ.get("RETENTION_DAYS", "60").strip() or "60"
    collection_ids = _parse_collection_ids(os.environ.get("EXPORT_COLLECTION_IDS"))

    now = datetime.datetime.utcnow()
    date_prefix = now.strftime("%Y-%m-%d")
    time_prefix = now.strftime("%H%M%S")
    output_uri_prefix = (
        f"gs://{bucket}/firestore-backups/{date_prefix}/{time_prefix}/"
    )

    creds, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/datastore"]
    )
    creds.refresh(Request())

    url = (
        f"https://firestore.googleapis.com/v1/projects/{project_id}"
        f"/databases/{database_id}:exportDocuments"
    )
    body: dict[str, object] = {"outputUriPrefix": output_uri_prefix}
    if collection_ids:
        body["collectionIds"] = collection_ids

    logging.info("Starting export for database_id=%s", database_id)
    logging.info("Retention days (GCS lifecycle): %s", retention_days)
    logging.info("outputUriPrefix=%s", output_uri_prefix)

    resp = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {creds.token}",
            "Content-Type": "application/json",
        },
        data=json.dumps(body),
        timeout=60,
    )

    if resp.status_code >= 400:
        logging.error("Export failed: %s %s", resp.status_code, resp.text)
        return (resp.text, resp.status_code)

    payload = resp.json()
    logging.info("Export operation: %s", payload.get("name"))

    return (
        json.dumps(
            {
                "operation": payload.get("name"),
                "outputUriPrefix": output_uri_prefix,
            }
        ),
        200,
        {"Content-Type": "application/json"},
    )
