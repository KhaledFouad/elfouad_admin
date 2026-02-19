# elfouad_admin

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Web Deployment (Vercel + iPhone Safari)

### Vercel project settings
1. Framework Preset: `Other`
2. Build Command: `bash tools/build_web_vercel.sh`
3. Output Directory: `build/web`
4. Root Directory: repository root

### Firebase settings required (important)
1. Open Firebase Console -> Authentication -> Settings -> Authorized domains.
2. Add your Vercel domain(s), for example:
   - `your-project.vercel.app`
   - your custom domain (if used).

If the domain is not added, web auth (including anonymous auth) can fail after deploy.

### iPhone Safari notes
1. Open links using `https` only (Vercel does this by default).
2. If you see an old cached version, refresh once after deploy.
