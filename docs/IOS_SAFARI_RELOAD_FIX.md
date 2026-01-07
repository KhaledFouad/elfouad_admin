# iOS Safari Reload Loop Fix

## Why the loop happens
iPhone Safari is aggressive about memory and reloads large web apps more often.
If a service worker or cached `index.html`/bootstrap files are stale, Safari can
keep reloading and re-registering old assets in a loop after a new deploy.

This project disables PWA support (`--pwa-strategy=none`) and uses the HTML
renderer to reduce memory pressure and avoid service-worker cache conflicts.
Vercel headers force fresh HTML/JS while allowing long-lived caching for assets.

## Verify the fix
1) Open the site in Safari Private mode.
2) If it works in Private mode, clear old site data:
   Settings > Safari > Advanced > Website Data > remove the site.

Note: disabling PWA means no offline support, but it prevents the reload loop
caused by old service workers.
