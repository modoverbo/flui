> **Research report** · Date: 2026-09-13 · Scope: Flutter web on Vercel, Flutter 3.47 ecosystem, logo icon options.
>
> **Partially superseded** by [`mvp-frontend-only.md`](mvp-frontend-only.md): the Neon + Better Auth + Hono API on Vercel Functions plan was replaced by Supabase (Auth, Postgres with RLS) plus Supabase Edge Functions for Whop only. The Flutter ecosystem, Vercel prebuilt-deploy and logo sections remain valid. See [`docs/adr/`](../adr/) for the final decisions.
>
> Preserved verbatim as produced by the research phase.

# flui: stack check (as of 2026-09-13)

I checked versions against the npm and pub.dev registries and your local `flutter create --help` / `flutter build web --help` (3.47.4). I checked everything else against official docs. Anything I couldn't confirm is marked **[unverified]**.

---

## 1. How the Flutter app should reach Neon

### a. Neon Managed Better Auth + Neon Data API
- **What Neon Auth is now:** it runs on **Better Auth**, pinned to 1.4.18. The older Stack Auth version no longer takes new users. ([overview](https://neon.com/docs/auth/overview), [migration guide](https://neon.com/docs/auth/migrate/from-legacy-auth))
- **Status:** **Beta**, "targeting GA this quarter". AWS regions only. ([roadmap](https://neon.com/docs/auth/roadmap))
- **Supported features:** email/password, email OTP, magic link, phone, JWT, admin, and social login with Google, GitHub and Vercel.
  - **Apple is not listed.**
  - The Bearer plugin is not listed either.
  - Setups where the frontend and backend are separate deployments are "not yet supported" because they rely on cookies.
  - Framework guides exist only for Next.js and React.
- **Price:** free up to 60k MAU on the Free plan, up to 1M MAU on Launch/Scale. ([pricing](https://neon.com/pricing))
- **Data API:** **Beta**, "fully compatible with PostgREST".
  - It validates JWTs against any provider's JWKS URL (Firebase, Clerk, Auth0 and others) and reads the user's id from the `sub` claim via `auth.user_id()`.
  - Row Level Security is effectively mandatory.
  - It's included on all plans. ([overview](https://neon.com/docs/data-api/overview), [providers](https://neon.com/docs/data-api/custom-authentication-providers))
- **Dart support:** there's no SDK. Neon says "Native Swift, Kotlin, and Dart apps use the HTTP endpoints directly." ([FAQ](https://neon.com/faqs/best-backend-mobile-app-ios-android))
  - The Supabase-maintained `postgrest` Dart package (2.9.1) is a generic PostgREST client. Whether it works with Neon's Data API is **[unverified]**.
- **Tradeoffs:**
  - You'd depend on two Beta products.
  - There's no documented Flutter or native flow, and no Apple sign-in.
  - Business logic (spaced repetition, streaks, grading) ends up in RLS rules and SQL functions, which are harder to unit-test.
  - The AI conversation feature needs a server anyway.

### b. Your own API on Vercel Functions (TypeScript)
- **Framework:** Hono (4.13.7) deploys on Vercel with no config and runs on Fluid compute. ([changelog](https://vercel.com/changelog/deploy-hono-backends-with-zero-configuration))
  - Node 24 is supported on Vercel. ([Node runtime](https://vercel.com/docs/functions/runtimes/node-js))
- **Auth: Better Auth 1.7.4**, self-hosted, with users stored in your own Neon database.
  - Mobile sign-in is verified: `signIn.social({provider, idToken})` works for Google and Apple.
  - The Google `clientId` can be an array (web, iOS and Android client IDs).
  - Native iOS Apple tokens need `appBundleIdentifier`. ([Better Auth docs v1.6.23 via Context7](https://github.com/better-auth/better-auth/blob/v1.6.23/docs/content/docs/authentication/apple.mdx))
  - Mobile clients send `Authorization: Bearer` tokens through the [bearer plugin](https://www.better-auth.com/docs/plugins/bearer).
  - The JWT plugin can later issue tokens for the Neon Data API if you want it.
  - Community Dart clients exist (`flutter_better_auth` 0.6.5, `better_auth_flutter` 0.1.2). Treat them as optional; a thin client you write yourself is safer.
- **ORM: Drizzle 0.45.2** is the stable release; 1.0 is still on the `rc` tag.
  - Prisma's stable client is 7.10.0. Oddly, the npm `latest` tag for `prisma` points to `8.0.0-rc.14`, so pin versions explicitly.
- **Driver:** `@neondatabase/serverless` 1.1.0.
  - Its HTTP mode suits one-shot queries; WebSocket mode is needed for interactive transactions. ([Neon](https://neon.com/docs/serverless/serverless-driver), [Drizzle](https://orm.drizzle.team/docs/connect-neon))
  - The alternative is `pg` plus `attachDatabasePool` from `@vercel/functions`, which Fluid compute is designed for. ([Vercel KB](https://vercel.com/kb/guide/connection-pooling-with-functions))
- **Other auth libraries:**
  - Auth.js has been in maintenance mode under the Better Auth team since September 2025. ([blog](https://better-auth.com/blog/authjs-joins-better-auth))
  - Clerk's Flutter SDK is still `0.0.18-beta`.
- **Vercel cost:**
  - Hobby is free but "non-commercial, personal use only". It includes 4 active CPU-hours and 1M function invocations.
  - Pro costs $20 per seat per month. ([Hobby](https://vercel.com/docs/plans/hobby))

### c. Firebase Auth + your Vercel API + Neon
- `firebase_auth` 6.6.1 is the official FlutterFire plugin and covers all platforms. Email and social logins are free up to 50k MAU. ([pricing](https://firebase.google.com/pricing))
- The API verifies Firebase ID tokens with `jose` against Google's JWKS, or with `firebase-admin` 14.4.0. The Neon Data API also accepts Firebase tokens directly.
- **Tradeoffs:**
  - The mobile SDKs are the most polished of any option.
  - Users live outside Postgres, so you need a mirror `users` table.
  - You add a second vendor.

**Recommendation: option b** (Hono + Better Auth + Drizzle on Vercel, with Flutter calling a REST API defined by an OpenAPI contract).
- Every piece is stable, and Google and Apple native sign-in both work.
- Domain logic lives in testable TypeScript and Dart instead of RLS rules.
- The AI feature can reuse the same API.
- It costs about $0 until launch (Neon Free plus Vercel Hobby, then Pro).
- The price is that you own the auth setup and maintenance.
- Fallback if you'd rather not own auth: option c.

---

## 2. Deploying Flutter Web to Vercel

- **No native support:** Vercel's framework list has no Flutter preset. ([frameworks](https://vercel.com/docs/frameworks))
  - Community guides use the "Other" preset and `git clone` Flutter in `installCommand`. Those clones aren't pinned, and the SDK downloads on every build (Hobby builders have 2 vCPU / 8 GB).
  - The build image is Amazon Linux 2023. ([build image](https://vercel.com/docs/builds/build-image))
- **Better option: build in GitHub Actions.**
  - Install Flutter with `subosito/flutter-action` pinned to 3.47.4, then run `flutter build web --release --dart-define-from-file=config/prod.json`.
  - Then run `vercel pull`, `vercel build --prod` and `vercel deploy --prebuilt --prod`.
  - Add `"git": {"deploymentEnabled": false}` so Vercel doesn't also deploy from Git. ([KB](https://vercel.com/kb/guide/how-can-i-use-github-actions-with-vercel), [CLI](https://vercel.com/docs/cli/deploy))
  - Prebuilt deploys lose Vercel's system environment variables at build time. That doesn't matter for Flutter.
- **SPA fallback:** `"rewrites":[{"source":"/(.*)","destination":"/index.html"}]`. Vercel checks for a real file before applying rewrites. ([vercel.json](https://vercel.com/docs/project-configuration/vercel-json))
- **Caching:**
  - Flutter's output filenames aren't content-hashed (`main.dart.js`, `flutter_bootstrap.js`), so don't mark them `immutable`.
  - Vercel's default `public, max-age=0, must-revalidate` is the right setting: the CDN still caches at the edge and browsers revalidate. ([cache headers](https://vercel.com/docs/caching/cache-control-headers))
  - Flutter removed its default service worker ([flutter#156910](https://github.com/flutter/flutter/issues/156910)). There's no `--pwa-strategy` flag in 3.47.4.
- **WASM:**
  - `--wasm` builds both WASM and a JS fallback.
  - The COOP `same-origin` and COEP `credentialless` headers are only needed for multi-threading.
  - iOS browsers can't run WasmGC. Firefox and Safari are currently blocked by bugs and fall back to JS. ([Flutter wasm docs](https://docs.flutter.dev/platform-integration/web/wasm))
  - **Watch out:** COOP `same-origin` breaks Google sign-in popups ([GIS setup](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid), [drift web docs](https://drift.simonbinder.eu/web/)). Don't send COOP/COEP at first.
- **Monorepo:** use two Vercel projects in one repo.
  - `apps/api`: Git-integrated, with Root Directory set to `apps/api`.
  - `apps/app`: deployed from GitHub Actions.
  - Vercel's automatic "skip unaffected projects" only understands JS workspaces, so use GitHub Actions path filters or `ignoreCommand`. ([monorepos](https://vercel.com/docs/monorepos))
  - Optional: add an external rewrite on the web project, `/api/:path*` → `https://api.<domain>/:path*`. Web then gets same-origin httpOnly cookies while mobile keeps using Bearer tokens.
  - Vercel Services (one project, many apps, launched 2026-06-30) is **Beta**, and would need Flutter inside Vercel's build. ([services](https://vercel.com/docs/services), [KB](https://vercel.com/kb/guide/vercel-services))

**Recommendation:** build in GitHub Actions and deploy prebuilt, with a separate API project. Start with a JS-only build (or `--wasm` without COOP/COEP headers). That gives reproducible, pinned builds and fast deploys, at the cost of maintaining one CI workflow.

---

## 3. Flutter 3.47 / Dart 3.13 ecosystem

**Big change for a new project:** Flutter 3.47 publishes Material and Cupertino as standalone packages, `material_ui` 1.2.0 and `cupertino_ui` 1.0.2. The in-framework libraries were frozen in 3.44, but formal deprecation hasn't happened yet. Migrate with `dart fix --apply --code=migrate_design_widgets`. ([breaking change](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui)) go_router 18 already depends on these packages. **Start the app on `material_ui`.**

- **State management**
  - **Riverpod** (`flutter_riverpod` 3.4.3, `riverpod_generator` 4.0.9, `riverpod_lint` 3.1.9):
    - Riverpod's docs say to use code generation "only if you already use code-generation for other things", because Dart macros were cancelled (Jan 2025). ([Riverpod](https://riverpod.dev/docs/concepts/about_code_generation), [Dart blog](https://dart.dev/blog/an-update-on-dart-macros-data-serialization))
    - Mutations and offline persistence are still experimental.
    - `ProviderContainer.test` and overrides make testing easy.
  - **Bloc**: `flutter_bloc` 9.1.1 hasn't been released since May 2025; `bloc` 9.2.1 is more recent.
  - The Flutter team's own guide recommends MVVM, abstract repositories, fakes over mocks, and go_router. ([recommendations](https://docs.flutter.dev/app-architecture/recommendations))
  - **→ Riverpod 3 with code generation**, since freezed already needs `build_runner`. Notifiers act as ViewModels; the domain layer stays pure Dart.
- **Routing:** `go_router` 18.0.1 (needs Flutter ≥3.44) and `go_router_builder` 4.5.0 for typed routes.
  - For auth guards, use `redirect` with `refreshListenable`; `onEnter` exists since 16.3.
  - URLs have been case-sensitive since v15. ([changelog](https://pub.dev/packages/go_router/changelog))
- **Models:**
  - `freezed` 4.0.1 (2026-08-29) supports Dart 3.13 primary constructors and needs SDK ≥3.13. Breaking change: no `final` inside constructor parameters. ([changelog](https://pub.dev/packages/freezed/changelog))
  - Pair it with `freezed_annotation` 3.1.0, `json_serializable` 6.14.1 and `build_runner` 2.16.1.
  - Primary constructors ([Dart 3.13](https://dart.dev/resources/language/evolution)) cut boilerplate but don't give you equality or copyWith, so code generation is still needed.
  - Alternative: `dart_mappable` 4.10.0.
- **HTTP and errors:**
  - **`dio` 5.11.1** has interceptors for token refresh and retry; `http` is at 1.6.0.
  - Use your own `sealed class Result<T>`, as the Flutter architecture guide does.
  - `fpdart` 1.2.0 hasn't shipped since Oct 2025, and its 2.0 dev releases stopped in 2024. `result_dart` 2.2.0 is an alternative.
- **Local storage:**
  - `shared_preferences` 2.5.5 for small settings.
  - **`drift` 2.35.0 + `drift_flutter` 0.3.1** for an offline catalog cache and a queue of attempts.
    - `sqlite3` 3.x makes `sqlite3_flutter_libs` unnecessary; that package is now `0.6.0+eol`.
    - On web, drift needs `sqlite3.wasm` and the worker file. Its fastest storage mode needs COOP/COEP; otherwise it falls back to IndexedDB. ([drift web](https://drift.simonbinder.eu/web/))
  - `hive_ce` 2.20.0 is actively maintained. The original `isar` was last released in 2023; `isar_community` 3.3.2 is the fork.
- **Secure token storage:** `flutter_secure_storage` 11.1.1.
  - On web it uses experimental WebCrypto over localStorage, which is not truly secure and needs HSTS.
  - Android now requires API 23 or higher. ([pub](https://pub.dev/packages/flutter_secure_storage))
  - This is why cookies on web plus Bearer tokens on mobile is the better split.
- **Google and Apple sign-in:**
  - `google_sign_in` 7.2.0: `GoogleSignIn.instance` is a singleton, `initialize()` must be awaited exactly once, and `authenticate()` only works where `supportsAuthenticate()` is true. **On web you must use the SDK-rendered button (`renderButton`).** ([pub](https://pub.dev/packages/google_sign_in))
  - `sign_in_with_apple` 8.2.0: native on iOS and macOS. Android and web need an Apple Services ID and a redirect endpoint on your server.
  - App Store rule 4.8: if you offer Google login, you must also offer an equivalent privacy-focused login such as Sign in with Apple. ([guidelines](https://developer.apple.com/app-store/review/guidelines/))
- **Fonts:** bundle Plus Jakarta Sans and Inter 4.1 as assets. Both are OFL-1.1 ([PJS](https://github.com/tokotype/PlusJakartaSans), [Inter](https://github.com/rsms/inter)).
  - Register the licenses with `LicenseRegistry`.
  - `google_fonts` 8.2.1 prefers bundled asset files and lets you turn off runtime fetching. Bundling gives offline use and no third-party requests.
- **SVG:** `flutter_svg` 2.3.0.
- **Lints:** **`very_good_analysis` 11.0.0** (2026-09-03, Dart 3.13, adds rules for primary constructors) over `flutter_lints` 6.0.0.
- **Testing:**
  - `mocktail` 1.0.5, but prefer fakes.
  - `integration_test` from the SDK.
  - `patrol` 4.9.0 supports web since 4.0 and handles native UI.
  - `alchemist` 0.14.0 (VGV + Betterment) for golden tests that are stable on CI. `golden_toolkit` is dead (last release 2023).
- **Config and flavors:**
  - `--dart-define-from-file=config/<env>.json` (accepts `.json` or `.env`).
  - New `--web-define` fills template variables in `index.html` (both flags checked locally).
  - Use Android/iOS flavors for separate bundle IDs.
- **i18n:**
  - `flutter gen-l10n` writes generated files into your source tree now; the old synthetic `flutter_gen` package is gone and `generate: true` is required. ([breaking change](https://docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source))
  - `slang` 4.19.2 is type-safe and needs no build_runner.
  - UI strings only (catalog content comes from the database) → **gen-l10n**, with Spanish ARB as the template.
- **Project template:**
  - Suggested command: `flutter create --empty --org <reverse.domain> --platforms android,ios,web --project-name flui` (flags checked locally; the `skeleton` template is retired).
  - `very_good_cli` 1.5.0 is active, but its `flutter_app` template is Bloc-based **[from memory, not re-verified]**. With Riverpod, start empty and copy its CI and coverage conventions.

**Recommendation:** Riverpod 3 + go_router 18 + freezed 4 + dio + drift + very_good_analysis, starting on `material_ui`. Everything is current and fits Clean Architecture and TDD. The main cost is heavier `build_runner` use.

---

## 4. Logo icon (three stacked wavy lines)

| Library | Icon | License | Shape | Raw SVG |
|---|---|---|---|---|
| Tabler | `ripple` | MIT | 3 strokes, one soft wave each, 24px, 2px stroke, round caps | https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/outline/ripple.svg |
| Lucide | `waves` | ISC | 3 strokes, tighter repeating waves, 24px, 2px stroke, round caps | https://cdn.jsdelivr.net/npm/lucide-static@1.45.0/icons/waves.svg (the GitHub raw path returns 404) |
| Phosphor | `waves` | MIT | 3 organic curves; thin to bold, fill and duotone weights | https://raw.githubusercontent.com/phosphor-icons/core/main/raw/regular/waves.svg |
| Material Symbols | `water` (3 waves) / `waves` (4 waves) | Apache-2.0 | Filled shapes, not strokes | https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/water/materialsymbolsrounded/water_24px.svg |
| Iconoir | `sea-waves` | MIT | Only 2 waves (poor fit) | https://raw.githubusercontent.com/iconoir-icons/iconoir/main/icons/regular/sea-waves.svg |

**Tabler `ripple`** (source as fetched):
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M3 7c3 -2 6 -2 9 0s6 2 9 0" />
  <path d="M3 17c3 -2 6 -2 9 0s6 2 9 0" />
  <path d="M3 12c3 -2 6 -2 9 0s6 2 9 0" />
</svg>
```
**Lucide `waves`** (lucide-static 1.45.0):
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M2 12q2.5 2 5 0t5 0 5 0 5 0" />
  <path d="M2 19q2.5 2 5 0t5 0 5 0 5 0" />
  <path d="M2 5q2.5 2 5 0t5 0 5 0 5 0" />
</svg>
```
An MIT or ISC icon isn't exclusive to you, so anyone can use the same shape. Tweak the wave height, phase or stroke width before registering it as a brand mark.

**UI icon set: Lucide** (ISC, 24px grid, 2px stroke, round caps).
- Package: `lucide_icons_flutter` 3.1.19, with six stroke weights (`w100`–`w600`).
- Alternative: `flutter_lucide` 1.45.0, which tracks the upstream Lucide release number.
- If you pick the Tabler logo, use `tabler_icons_next` 3.46.0 instead (SVG widgets, adjustable `strokeWidth`).
- `phosphor_flutter` 2.1.0 hasn't been released since May 2024.

---

## Proposed stack

| Layer | Choice | Version | Why |
|---|---|---|---|
| Database | Neon Postgres (Vercel Marketplace integration, preview branches) | Free, then Launch (no minimum since Dec 2025) | Required by founder; a branch per preview deploy ([Neon–Vercel](https://neon.com/docs/guides/vercel-overview)) |
| API | Hono on Vercel Functions (Node 24, Fluid) | hono 4.13.7 | No config, standard web APIs, easy to test |
| ORM / driver | Drizzle + `@neondatabase/serverless` (or `pg` + `attachDatabasePool`) | 0.45.2 / 1.1.0 | Stable, type-safe SQL |
| Auth | Better Auth, self-hosted (bearer + idToken Google/Apple) | 1.7.4 | Users stored in Neon; native mobile sign-in |
| Web hosting | Vercel static, built in GitHub Actions, prebuilt deploy | vercel CLI 59.16.0 | Reproducible Flutter builds |
| UI kit | material_ui | 1.2.0 | New standalone Material package |
| State / DI | Riverpod + generator + lint | 3.4.3 / 4.0.9 / 3.1.9 | DI and state in one, easy test overrides |
| Routing | go_router (+ builder) | 18.0.1 / 4.5.0 | Official recommendation, redirect-based auth guards |
| Models | freezed + json_serializable | 4.0.1 / 6.14.1 | Supports Dart 3.13 |
| HTTP | dio + own sealed `Result` | 5.11.1 | Interceptors for auth refresh |
| Local data | drift + drift_flutter; shared_preferences | 2.35.0 / 0.3.1; 2.5.5 | Offline catalog and progress queue |
| Secrets | flutter_secure_storage (mobile only) | 11.1.1 | Keychain / Keystore |
| Sign-in | google_sign_in; sign_in_with_apple | 7.2.0; 8.2.0 | App Store rule 4.8 |
| i18n | gen-l10n (ARB, es template) | SDK | Official, ICU plurals |
| Lints | very_good_analysis | 11.0.0 | Strict rules, Dart 3.13 |
| Tests | mocktail, integration_test, patrol, alchemist | 1.0.5 / SDK / 4.9.0 / 0.14.0 | Unit through end-to-end plus goldens |
| Icons / fonts | lucide_icons_flutter; bundled PJS + Inter (OFL) | 3.1.19 | Consistent look, works offline |

## Open decisions for the founder
1. **Who owns auth:** self-hosted Better Auth (all data in Postgres, you maintain it) vs Firebase Auth (best Flutter SDKs, second vendor, users stored outside the database). Neon Managed Better Auth isn't ready for this app: it's Beta, has no Apple sign-in and doesn't support separate frontend/backend.
2. **How the web app sends credentials:** same-origin `/api` rewrite with httpOnly cookies (safer) vs Bearer tokens everywhere (one code path, weaker storage on web).
3. **Offline scope for v1:** drift-backed offline sessions now (more web setup, sync logic) vs online-only first with a thin cache.

**Could not verify:** whether Neon's Data API works with the Dart `postgrest` package; what very_good_cli's template contains; how `flutter_lucide` renders icons; why npm's `prisma` `latest` tag points to an RC.
