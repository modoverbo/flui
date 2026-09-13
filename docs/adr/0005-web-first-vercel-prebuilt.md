# ADR 0005: Web first, prebuilt Flutter web deployed to Vercel Pro

- **Status:** Accepted
- **Date:** 2026-09-13
- **Evidence:** [research/stack.md](../research/stack.md) §2,
  [research/mvp-frontend-only.md](../research/mvp-frontend-only.md) §4–5

## Context

- The MVP sells subscriptions through Whop. On iOS, App Store Review Guideline **3.1.1** requires
  in-app purchase for subscriptions and digital content (link-out entitlements exist only in some
  storefronts such as the US, the EU and Brazil, with their own fees and rules). Google Play requires
  Google Play Billing for subscriptions, except through enrolled programs with fees.
- Supporting in-app purchase would mean parallel billing, receipt validation and entitlement merging:
  out of scope for validating the idea.
- Vercel has no Flutter preset. Building Flutter inside Vercel means unpinned SDK downloads on every
  build. Vercel Hobby forbids commercial use, so the paid plan (Pro) is required.

## Decision

- **Web first.** The MVP ships as Flutter web only. Mobile store builds and store payments are out
  of scope until the idea is validated.
- **Build in GitHub Actions** with `subosito/flutter-action` pinned to Flutter 3.47.4:
  `flutter build web --release --dart-define-from-file=<temp json from secrets>`.
- Copy `app/vercel.json` (SPA rewrites to `/index.html`) into `build/web`.
- **Deploy the static folder** with the Vercel CLI:
  `vercel deploy build/web --prod --yes --token $VERCEL_TOKEN`, linked through `VERCEL_ORG_ID` and
  `VERCEL_PROJECT_ID`. The Vercel project uses the "Other" preset with an empty build command and Git
  deployments disabled.

## Consequences

- Reproducible, pinned builds; Vercel only serves static files.
- Flutter's output files are not content-hashed, so keep Vercel's default revalidating cache headers.
- Do not send COOP/COEP headers initially (they break Google sign-in popups; only needed for
  multi-threaded WASM).
- A future mobile release must revisit payments: in-app purchase (or store programs) plus a way to
  merge store entitlements into `entitlements`.

## Alternatives considered

| Option | Why not |
|--------|---------|
| Build Flutter on Vercel ("Other" preset + git clone Flutter) | Unpinned, slow, fragile builds |
| `vercel build` + `deploy --prebuilt` | Requires producing `.vercel/output`; unnecessary for a plain static folder |
| Cloudflare Workers static assets | Free and allowed commercially, but the founder already pays for Vercel Pro |
| GitHub Pages / Vercel Hobby | Commercial use not allowed |
| Mobile first with Whop checkout | Conflicts with Apple 3.1.1 and Google Play billing policy outside specific programs |
