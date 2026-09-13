> **Research report** · Date: 2026-09-13 · Scope: frontend-only MVP feasibility (Neon vs Supabase), Whop without exposing secrets, commercial hosting terms, app-store payment rules.
>
> Supersedes the backend plan in [`stack.md`](stack.md). Later decisions refined it: hosting is Vercel Pro (commercial use allowed on paid plans) instead of Cloudflare, and the free trial is a Whop card-upfront trial. See [`docs/adr/`](../adr/).
>
> Preserved verbatim as produced by the research phase.

# flui MVP stack check: Neon, Supabase, Whop, hosting and app stores (verified 2026-09-13)

For a Flutter app, Neon's login service (Neon Auth) does not work without a server of your own: Safari and iPhone logins break unless you add a proxy, and mobile isn't supported. By the founder's own rule, that means switching to Supabase. The main alternative is keeping Neon's database and swapping the login for Firebase Auth. Either way, Whop needs one small serverless function, and it can run for $0 on a free tier that doesn't ban commercial use. Vercel Hobby and GitHub Pages don't allow a paid app; Cloudflare does.

## 1. Neon without a backend

**How Neon Auth works over HTTP.** Neon Auth is Neon's hosted Better Auth service, currently in Beta.
- **Endpoints.** The React quickstart's Auth Base URL already ends in `/auth` (for example `https://ep-xxx.neonauth.us-east-2.aws.neon.build/neondb/auth`). Relative to it:
  - `POST /sign-up/email` and `POST /sign-in/email`
  - `GET /get-session`, which returns the JWT in a `Set-Auth-Jwt` header
  - `GET /token` for authenticated users and `GET /token/anonymous` for guests
  - Sources: [auth flow](https://neon.com/docs/auth/authentication-flow), [Data API troubleshooting](https://neon.com/docs/data-api/troubleshooting), [access control](https://neon.com/docs/data-api/access-control), [React quickstart](https://neon.com/docs/auth/quick-start/react).
- **The session is a cookie.** The session lives in `__Secure-neonauth.session_token`. The docs describe it as "an opaque session token (not a JWT)… secure (HTTPS only, HttpOnly, SameSite=None)" ([auth flow](https://neon.com/docs/auth/authentication-flow)).
- **The JWT is short-lived and has no refresh token.**
  - Tokens are signed with EdDSA and "expire in 15 minutes" ([JWT plugin](https://neon.com/docs/auth/guides/plugins/jwt)).
  - Keys are published at `<AUTH_URL>/.well-known/jwks.json`.
  - To "refresh", you call `/token` again with the cookie.
- **Cross-origin calls.** For a SPA on another origin you must set `credentials: 'include'`: "Otherwise `authClient.token()` returns `data.token` as `undefined`" ([JWT plugin](https://neon.com/docs/auth/guides/plugins/jwt)). The Better Auth client already defaults to `credentials: "include"` ([source](https://github.com/better-auth/better-auth/blob/main/packages/better-auth/src/client/config.ts)).
- **Safari blocks this.**
  - Neon's JWT page says: "Cross-domain setups have further limitations, notably Safari ITP blocking third-party cookies, with reverse-proxy or shared-parent-domain workarounds" ([JWT plugin](https://neon.com/docs/auth/guides/plugins/jwt)).
  - WebKit says: "ITP by default blocks all third-party cookies. There are no exceptions" ([WebKit](https://webkit.org/tracking-prevention/)).
  - Chrome still allows third-party cookies ([Privacy Sandbox](https://privacysandbox.google.com/blog/privacy-sandbox-next-steps)).
  - Neon documents no custom auth domain, so the only fix left is a same-origin reverse proxy. That proxy is itself a server piece.
- **Neon's official support position.**
  - "Vite + React ✅ Supported", but "Architectures where frontend and backend are separate deployments… are not yet supported… HTTP-only cookies… cannot be securely shared between frontend and backend applications on different domains" ([roadmap](https://neon.com/docs/auth/roadmap)).
  - The official browser-only example does deploy a Vite SPA that calls Neon directly ([react-neon-js](https://github.com/neondatabase/neon-js/tree/main/examples/react-neon-js)).
  - The JWT plugin page adds that it "is **not** a replacement for session management in web applications."
- **Trusted domains and CORS.**
  - Trusted domains are only a redirect allowlist for OAuth and email links. Localhost is allowed automatically and wildcards are supported ([domains](https://neon.com/docs/auth/guides/configure-domains)).
  - Data API CORS defaults to "Empty (Allows all origins)". Set your real origins for production ([manage](https://neon.com/docs/data-api/manage)).
- **Calling it from Dart.**
  - There is no Dart SDK, so you would re-implement the session and JWT caching that `neon-js` does.
  - On web, `http`'s `BrowserClient` has `withCredentials`: "Whether to send credentials such as cookies… for cross-site requests" ([pub](https://pub.dev/documentation/http/latest/browser_client/BrowserClient-class.html)).
  - The Data API is PostgREST-compatible, so Supabase's `postgrest` Dart package 2.9.1 should work against it. Its `PostgrestClient(url, accessToken: …)` takes a token callback ([pub](https://pub.dev/packages/postgrest), [source](https://github.com/supabase/supabase-flutter/blob/main/packages/postgrest/lib/src/postgrest.dart)).
- **Mobile is undocumented.**
  - Better Auth relaxes its request-origin checks when requests carry "neither Fetch Metadata headers nor an Origin/Referer header (typical of non-browser clients)" ([security](https://www.better-auth.com/docs/reference/security)). A native app could therefore copy the session cookie by hand, but that is an unofficial hack.
  - Better Auth's bearer-token plugin is not in Neon's supported plugin list ([plugins](https://neon.com/docs/auth/guides/plugins)).
  - Redirecting OAuth back to a custom app scheme is not documented.
- **Operational caveats.**
  - The default shared email sender is rate-limited, and verification *links* need your own SMTP.
  - Email verification is off by default.
  - "Anyone can sign up."
  - Sources: [checklist](https://neon.com/docs/auth/production-checklist), [auth flow](https://neon.com/docs/auth/authentication-flow).
  - Neon Auth runs in AWS regions only ([overview](https://neon.com/docs/auth/overview)).

**Free plan today** ([pricing](https://neon.com/pricing)):
- 100 projects, 10 branches each.
- 100 CU-hours per project (a CU is Neon's compute unit, about 4 GB RAM), 0.5 GB storage per project.
- Scale to zero after 5 minutes, autoscaling up to 2 CU, 5 GB egress.
- Auth up to 60k MAU.
- "All plans include… a Data API."
- "Hitting any Free monthly limit… suspends compute until the next billing month."
- The docs contain no commercial-use ban. The Free plan is aimed at "Prototypes, side projects, and small teams."
- Neon Functions also exist now, in Beta: "free to use during beta… on any plan", JS/TS only, and only in `aws-us-east-2` and `aws-eu-central-1` ([functions](https://neon.com/docs/compute/functions/overview)).

**Security model.**
- "The API does not have its own separate permission system." Only table GRANTs and row-level security (RLS) protect data. "If RLS is disabled… any authenticated user can see all rows" ([access control](https://neon.com/docs/data-api/access-control)).
- The Data API URL and the Auth URL are public.
- A subscription flag must never be writable by the `authenticated` role.

**Keeping Neon without the cookie problem.** The Data API accepts tokens from Firebase ("provide your Firebase/GCP Project ID as the JWT Audience") and from Google Identity ([custom providers](https://neon.com/docs/data-api/custom-authentication-providers)).
- `firebase_auth` 6.6.1 supports web, Android and iOS ([pub](https://pub.dev/packages/firebase_auth)).
- Firebase's free Spark plan covers up to 50K MAU ([Firebase](https://firebase.google.com/pricing)).
- Auth is token-based, so there are no third-party cookies.

**Verdict:**
- (a) Flutter web: **WORKS WITH CAVEATS.** It is not officially supported for non-JS clients and breaks on Safari and iOS unless you add a same-origin proxy.
- (b) Flutter mobile: **DOES NOT WORK (officially).**
- Neon's database and Data API themselves **WORK** on both platforms if paired with a token-based provider such as Firebase.

## 2. Supabase as the fallback

- **Free plan** ([pricing](https://supabase.com/pricing)):
  - "Limit of 2 active projects".
  - "Free projects are paused after 1 week of inactivity".
  - 50,000 MAU, 500 MB database, 5 GB egress, 1 GB storage.
  - 500,000 Edge Function invocations.
  - Pro starts at $25/month.
- **Commercial use.** There is no ban. The terms even contemplate "If Customer is using the Service for commercial purposes" ([terms](https://supabase.com/terms)).
- **Flutter support.** `supabase_flutter` 2.17.2 runs on Android, iOS and web ([pub](https://pub.dev/packages/supabase_flutter)). It covers:
  - email/password and magic links,
  - native Google/Apple sign-in and `signInWithOAuth()`,
  - deep links for mobile.
  - Auth is token-based, so there is no cross-site cookie issue (my inference; not an explicit doc statement).
- **RLS** is Postgres-native, the same model as Neon.
- **Edge Function limits** ([limits](https://supabase.com/docs/guides/functions/limits)): 256 MB memory, 150 s wall clock on Free, 2 s CPU, 100 functions. That is plenty for a webhook.

**Verdict: WORKS** for web and mobile with no backend of your own, except the one Whop function.

## 3. Whop without exposing secrets

**Plans: one product, two plans.**
- **API fields.** `plan_type: "renewal"`, `billing_period` in days ("30 for monthly"), `renewal_price`, `trial_period_days` ("Free trial duration before the first recurring charge", example 7), plus a strikethrough-price field for showing the discount ([Create Plan](https://docs.whop.com/api-reference/beta/plans/create-plan)).
- **Quarterly.** Use `billing_period: 90`. Whop's iOS SDK enum lists `quarterly // 90 days` ([iOS reference](https://docs.whop.com/developer/guides/ios/checkout-reference)).
- **Discount.** Set the quarterly `renewal_price` below three times the monthly price.
- **Dashboard.**
  - "Add another billing period" adds several prices to one product ([pricing](https://docs.whop.com/manage-your-business/payment-processing/set-up-pricing)).
  - Free trials can only be added to "Recurring" checkout links.
  - Whop "automatically catches when the same person tries to sign up for multiple free trials" ([trials](https://docs.whop.com/manage-your-business/products/free-trials)).

**Checkout.**
- **Hosted link (no server).** The plan's `purchase_url` works as is. Whop's table says "Server code required: No (Dashboard)" for links and "Yes" for embedded checkout ([accept payments](https://docs.whop.com/developer/guides/accept-payments)).
- **Embedded (plan ID only, no server).** Whop has a vanilla `loader.js` with `data-whop-checkout-plan-id` / `-session` attributes and a `locale` option ("es"). A React component also exists ([embed](https://docs.whop.com/payments/checkout-embed)). In Flutter web this needs an HTML platform view. The simplest path is redirecting to `purchase_url`.
- **Attaching our user ID.** This requires a checkout configuration ("session") created with the API key:
  - It carries `metadata`, and "Payments and memberships created from a checkout session inherit its metadata" ([object](https://docs.whop.com/api-reference/checkout-configurations/checkout-configuration)).
  - The response gives `purchase_url: https://whop.com/checkout/plan_x/?session=ch_x`.
  - The endpoint needs the permissions `checkout_configuration:create`, `plan:create`, `access_pass:create` and `access_pass:update` ([create](https://docs.whop.com/api-reference/checkout-configurations/create-checkout-configuration)).
  - Without a server, the only mapping is a prefilled email, which is weak.

**Checking access.**
- **The API key must never ship.**
  - "Never expose Account API keys or App API keys in client-side code. Browser, mobile, and iframe code should call your server" ([troubleshooting](https://docs.whop.com/developer/troubleshooting)).
  - "Keep API keys server-side. Only user tokens belong in a client" ([auth](https://docs.whop.com/developer/guides/auth-scoping)).
  - Minted user tokens without `scoped_actions` "inherit every permission the minting credential has."
  - The only client-safe key is an `iap:read` key for the iOS SDK ([iOS install](https://docs.whop.com/developer/guides/ios/installation)).
- **"Sign in with Whop" (OAuth).**
  - It uses "OAuth 2.1 and… PKCE", and the guide's browser example exchanges the code with no client secret ([OAuth](https://docs.whop.com/developer/guides/oauth)).
  - The discovery document confirms `token_endpoint_auth_methods_supported: ["none", …]`, `S256`, and a `member:basic:read` scope ([OIDC](https://api.whop.com/.well-known/openid-configuration)).
  - Access tokens last 1 hour and refresh tokens rotate.
  - `GET /memberships` lists "a user credential their own" memberships ([list](https://docs.whop.com/api-reference/memberships/list-memberships)). `GET /users/{id}/access/{resource_id}` also exists ([check access](https://docs.whop.com/api-reference/beta/users/check-user-access)).
  - Caveats: it only gates the UI and can be bypassed, RLS can't see it, users need a second login, and Whop's own credential table says OAuth tokens "Live: Your server."
- **Webhooks.**
  - They follow the Standard Webhooks spec (HMAC with a `ws_` secret, 5-minute replay window).
  - "Whop rejects localhost", and delivery is "at least one time", so handlers must be idempotent.
  - Current events: `membership.activated`, `membership.deactivated`, `membership.trial_ending_soon`, `payment.succeeded`, `payment.failed`. The older `went_valid`/`went_invalid` names are not in the v1 event list ([webhooks](https://docs.whop.com/developer/guides/webhooks)).

**Minimum server piece.** One function with two routes:
1. **`POST /checkout`:**
   - verify the user's JWT against the provider's public keys (JWKS),
   - create a checkout configuration with `plan_id` and `metadata.app_user_id`,
   - return `purchase_url`.
2. **`POST /whop-webhook`:**
   - verify the signature,
   - upsert an `entitlements` row keyed on `webhook-id`,
   - the table is SELECT-own-row only via RLS, with no write grants for users.

**Free, commercial-OK places to run it:**
- **Supabase Edge Functions.** Limits are listed above.
- **Cloudflare Workers Free.**
  - 100,000 requests/day, 10 ms CPU, 50 subrequests ([limits](https://developers.cloudflare.com/workers/platform/limits/)).
  - I found no non-commercial clause in the [terms](https://www.cloudflare.com/terms/).
  - Writing to Neon from a Worker is documented, via Hyperdrive or the serverless driver over HTTP ([Neon + Workers](https://neon.com/docs/guides/cloudflare-workers), [driver](https://neon.com/docs/serverless/serverless-driver)).
- **Neon Functions.** Beta, free during beta, 100 concurrent invocations; limited regions ([limits](https://neon.com/docs/compute/functions/reference/runtime-limits)).
- **Vercel Hobby:** not allowed, because of the commercial ban (section 4).
- **Netlify Free:** 300 credits, then sites pause (section 4).

**Verdict:** A client-only check is possible via Whop OAuth, but it is not enforceable. A reliable user mapping plus an entitlement the database can trust **requires one small function**, and that runs for $0.

## 4. Free commercial web hosting

- **Vercel Hobby.**
  - "Hobby teams are restricted to non-commercial personal use only."
  - Commercial usage includes "Any method of requesting or processing payment from visitors of the site" ([fair use](https://vercel.com/docs/limits/fair-use-guidelines)).
  - A paid SaaS frontend is commercial, so it is **not allowed**.
- **GitHub Pages.** "Not… allowed… for… providing commercial software as a service (SaaS)" ([limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)). **Not allowed.**
- **Netlify Free** ([plans](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/credit-based-pricing-plans/)):
  - 300 credits/month, with production deploys consuming credits.
  - When credits run out, "projects pause until the next billing cycle".
  - I did not read Netlify's terms directly.
- **Cloudflare.**
  - Workers static assets: "free and unlimited", up to 20,000 files and 25 MiB per file ([billing](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/)).
  - Pages Free: 500 builds/month ([Pages](https://developers.cloudflare.com/pages/platform/limits/)).

**Verdict:** Use **Cloudflare Workers static assets**. The same Worker can also host `/api/*` (and a same-origin `/auth` proxy if you stay on Neon Auth).

## 5. App stores and external payments

- **Apple (guidelines updated June 8, 2026)** ([guidelines](https://developer.apple.com/app-store/review/guidelines/)).
  - **3.1.1:** subscriptions and premium content "must use in-app purchase."
  - **3.1.1(a):** link entitlements "are not required… to include buttons, external links, or other calls to action in their United States storefront apps."
  - **3.1.3(b), multiplatform:** access to web purchases is allowed "provided those items are also available as in-app purchases within the app."
  - A vocabulary trainer is not a 3.1.3(a) "reader" app.
- **US, Epic v. Apple.**
  - The Ninth Circuit (Dec 11, 2025) upheld the contempt finding. It said Apple may charge a commission limited to costs "genuinely and reasonably necessary" to coordinate the link-out, and sent the case back to set that rate ([opinion](https://law.justia.com/cases/federal/appellate-courts/ca9/25-2935/25-2935-2025-12-11.html)).
  - Reportedly the Supreme Court denied a stay on Aug 14, 2026, and zero commission applies for now ([report](https://macdailynews.com/2026/08/14/u-s-supreme-court-clears-path-for-app-store-commission-showdown-as-apple-must-defend-its-rates-in-lower-court/)).
- **EU.** Apple uses the StoreKit External Purchase Link Entitlement (EU) with an initial acquisition fee, a store services fee and a Core Technology Commission ([Apple](https://developer.apple.com/news/?id=awedznci)).
- **Brazil** (from June 18, 2026, iOS 26.5). Apps can link out to a website, with a "15 percent" store services commission on website transactions ([Apple](https://www.apple.com/newsroom/2026/06/apple-announces-changes-to-ios-in-brazil/)). I found no other LatAm program.
- **Whop's iOS SDK** uses Whop payments in the US and "falls back to Apple's StoreKit" elsewhere ([Whop iOS](https://docs.whop.com/developer/guides/ios/overview)).
- **Google Play.**
  - Subscriptions "must use Google Play's billing system", and apps "may not lead users to a payment method other than Google Play's billing system" except through enrolled programs ([policy](https://support.google.com/googleplay/android-developer/answer/9858738)).
  - US external content links program: fees start October 1, 2026 (10% for new installs on the first $1M), with a required information screen and reporting of "$0 transactions resulting from free trial purchases" ([program](https://support.google.com/googleplay/android-developer/answer/16470497)).
  - Alternative billing covers the US, EEA and UK ([blog](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html)).

**Verdict:** Web-only Whop is unrestricted. On mobile, Whop-only checkout is viable only on the US storefronts (Apple link-out; Play US program with fees), Brazil and EU programs. Elsewhere you must offer IAP or Play Billing.

## Recommended MVP architecture ($0/month, commercial use allowed)

| Component | Service | Free-tier limit | Caveat |
|---|---|---|---|
| Web hosting | Cloudflare Workers static assets | Unlimited asset requests; 20k files, 25 MiB per file | Worker code is capped at 100k requests/day and 10 ms CPU |
| Auth (email/password + Google) | Supabase Auth via `supabase_flutter` | 50k MAU | Project pauses after 1 week of inactivity; 2 free projects |
| Per-user data (daily time choice, word progress, results, streak) | Supabase Postgres + RLS | 500 MB database, 5 GB egress | RLS on every table; `entitlements` readable by the owner only |
| Server piece (create checkout session + Whop webhook) | Supabase Edge Function | 500k invocations; 150 s wall, 2 s CPU | Whop API key (custom minimal permissions) and `ws_` secret stored as function secrets; idempotent on `webhook-id` |
| Payments | Whop: one product, monthly (`billing_period` 30) and quarterly (90) plans, `trial_period_days: 7` | Whop fees (not researched) | Open `purchase_url?session=ch_…` created by the function |
| Mobile (later) | Same stack | — | Store payment rules from section 5 |

**If you stay on Neon:** use Neon DB + Data API with Firebase Auth, and a Cloudflare Worker for the checkout and webhook routes (serverless driver). Keeping Neon Auth instead means proxying `/auth/*` through the same-origin Worker.

## Neon vs Supabase decision

The founder's rule was to switch only if Neon can't work frontend-only. For Flutter it can't:
- Neon Auth is Beta and cookie-based.
- It explicitly doesn't support split frontend/backend deployments yet.
- It has no Dart SDK and no mobile path.
- It breaks on Safari and iOS without a proxy.

Neon's 100 free projects don't matter for a single MVP. Supabase covers auth, database, RLS and the webhook function in one vendor, with an official Flutter SDK that runs on web and mobile. Its real costs are the 1-week inactivity pause (irrelevant once users are active) and the 500 MB cap.

**Pick Supabase.** The only reasonable Neon route is Neon Data API plus Firebase Auth plus a Cloudflare Worker: three vendors, and a Beta Data API.

## Unverified items

- Whether Neon Auth works behind a same-origin reverse proxy (cookie Domain attribute, origin checks).
- Whether the `set-auth-jwt` header is readable cross-origin from the browser.
- Whether manually replaying Neon's session cookie works on native mobile, and whether OAuth can redirect back to a custom app scheme.
- Which OAuth scopes a Whop user token needs to list its own memberships, and whether the Check User Access endpoint accepts user tokens.
- Whether the Whop dashboard offers a quarterly cycle (the docs list weekly, monthly and yearly; the API accepts 90 days).
- Whether a Whop OIDC `id_token` would work as a Neon Data API JWT.
- Commercial use on Neon, Cloudflare and Netlify free plans: inferred from the absence of prohibitions, not a legal confirmation. Netlify's terms were not read.
- US Supreme Court and remand status (secondary sources). Reports of an Apple EU terms change on Oct 1, 2026 could not be confirmed on Apple's site.
- Neon Functions and Neon Auth pricing after Beta, and what counts as "inactivity" for Supabase's pause.
- Flutter web build file sizes against Cloudflare's 25 MiB per-file limit (not measured).
