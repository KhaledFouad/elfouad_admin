# iOS Safari Web Deploy

Recommended build flags for iPhone Safari:
- `--web-renderer html`
- `--pwa-strategy=none`

If this site was previously deployed as a PWA, iPhone Safari may keep an old
service worker cached. Clear it using:
- Settings > Safari > Advanced > Website Data > remove site data
- Or open the site in Private mode to test

Build output goes to `build/web`.
