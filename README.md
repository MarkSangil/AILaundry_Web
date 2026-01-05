# ailaundry_web

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deployment to Vercel

### Quick Deploy (Recommended)

The easiest way to deploy is using the deployment script:

```bash
./deploy.sh
```

This script will:
1. Check if Vercel CLI is installed (installs if missing)
2. Build your Flutter web app
3. Deploy to Vercel production

### Manual Deploy

If you prefer to deploy manually:

1. **Install Vercel CLI** (if not already installed):
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel** (first time only):
   ```bash
   vercel login
   ```

3. **Build the Flutter app**:
   ```bash
   flutter build web --release
   ```

4. **Deploy to Vercel**:
   ```bash
   vercel --prod
   ```

### One-Liner Deploy

For the fastest deployment, use this one-liner:

```bash
flutter build web --release && vercel --prod
```

### Automatic Deployment

The project is configured for automatic deployment via GitHub:
- Pushing to the `main` branch automatically triggers a Vercel deployment
- No manual action needed for production deployments from Git

### Preview Deployments

To deploy a preview (non-production) version:

```bash
vercel
```

This creates a preview URL that you can share for testing before merging to production.
