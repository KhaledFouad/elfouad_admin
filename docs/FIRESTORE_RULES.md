# Firestore Rules: Protect Archive Bin

Goal: allow archive-then-delete in the app while preventing clients from
deleting `archive_bin`.

## Rules Snippet

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /archive_bin/{docId} {
      allow delete: if false;
      // Keep your existing auth conditions for read/write.
      allow read, write: if true;
    }

    match /{document=**} {
      // Allow deletes everywhere except archive_bin.
      allow delete: if !resource.name.matches(
        'projects/.*/databases/.*/documents/archive_bin/.*'
      );
      // Keep your existing auth conditions for read/write.
      allow read, write: if true;
    }
  }
}
```

## Deploy Steps

1) Save the snippet into your `firestore.rules` file (or merge it into your
   existing rules).
2) Deploy:
   - Firebase CLI:
     - `firebase deploy --only firestore:rules`
   - Or gcloud (if you manage rules there):
     - `gcloud firestore rules update firestore.rules --project <PROJECT_ID>`

## Notes

- The app deletes originals after writing to `archive_bin`, so deletes must be
  allowed on primary collections.
- If you block deletes on `archive_bin`, client restore will not remove archive
  entries. Either allow delete for admins or move restore to backend tooling.
