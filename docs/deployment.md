# Deployment guide

Step-by-step setup of production for the founder: Supabase, Whop, Vercel and GitHub. Local
development is covered in the [README](../README.md).

## Quick path

1. [Create the Supabase project](#1-supabase) and push migrations.
2. [Configure Whop](#2-whop): product, 2 plans with a 7-day trial, API key, webhook.
3. [Set function secrets and deploy the functions](#13-function-secrets-and-deploy).
4. [Insert production plans](#24-link-plans-to-the-database) with the production Whop plan ids.
5. [Create the Vercel project](#3-vercel-pro) and [add GitHub secrets](#4-github-secrets).
6. Push to `main` (or run **web-deploy** manually) and walk the [go-live checklist](#6-go-live-checklist).

---

## 1. Supabase

### 1.1 Create the project

1. In [supabase.com/dashboard](https://supabase.com/dashboard) create a project named `flui`.
2. **Region:** closest to most users. South America → *South America (São Paulo)*; Mexico, Central
   America and US Hispanic users → *East US (North Virginia)*. The region cannot be changed later.
3. Save the database password in a password manager.
4. **Authentication → URL configuration:** Site URL = your production domain
   (for example `https://app.flui.example`); add it to Redirect URLs.
5. **Authentication → Providers → Email:** enabled. For production, configure custom SMTP (the
   built-in sender is rate-limited) and decide whether email confirmation is required.

### 1.2 Link and push migrations

```bash
npx supabase@latest login
npx supabase@latest link --project-ref <project-ref>
npx supabase@latest db push --dry-run   # review
npx supabase@latest db push             # applies supabase/migrations only
```

> Do **not** use `--include-seed` in production: `seed.sql` contains Whop **sandbox** plan ids and
> AI-drafted starter content. Load reviewed content with a dedicated SQL script after linguistic
> review (see [learning-method.md](learning-method.md#legal-and-quality-guardrails)).

### 1.3 Function secrets and deploy

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically. Set the rest (production
values, never committed):

| Secret | Production value |
|--------|------------------|
| `WHOP_API_KEY` | Whop production API key (§2.2) |
| `WHOP_WEBHOOK_SECRET` | `ws_...` secret of the production webhook (§2.3) |
| `WHOP_COMPANY_ID` | `biz_...` of the production company |
| `WHOP_API_BASE_URL` | `https://api.whop.com/api/v1` |
| `APP_URL` | `https://app.flui.example` (no trailing slash) |
| `ALLOWED_ORIGINS` | `https://app.flui.example` (comma-separated if several) |
| `WHOP_PLAN_MONTHLY_ID`, `WHOP_PLAN_QUARTERLY_ID` | Optional, reference only |

```bash
# Option A: one by one
npx supabase@latest secrets set WHOP_API_BASE_URL=https://api.whop.com/api/v1 --project-ref <project-ref>

# Option B: from a local file that is git-ignored (e.g. supabase/functions/.env.production)
npx supabase@latest secrets set --env-file supabase/functions/.env.production --project-ref <project-ref>

# Deploy both functions (verify_jwt comes from supabase/config.toml:
# whop-checkout requires a user JWT, whop-webhook does not)
npx supabase@latest functions deploy whop-checkout whop-webhook --project-ref <project-ref>
```

Function URLs:
- `https://<project-ref>.supabase.co/functions/v1/whop-checkout`
- `https://<project-ref>.supabase.co/functions/v1/whop-webhook`

---

## 2. Whop

Use the **sandbox** (`https://sandbox-api.whop.com/api/v1`, sandbox dashboard) for local and dev,
and a separate **production** company, product, plans, API key and webhook for prod. Sandbox ids are
never valid in production.

### 2.1 Product and plans

Create one product and two plans (dashboard, or API).

| Setting | Monthly | Quarterly |
|---------|---------|-----------|
| `plan_type` | `renewal` | `renewal` |
| `billing_period` (days) | 30 | 90 |
| `renewal_price` | monthly price | discounted (below 3 × monthly) |
| `initial_price` | **0** (for renewal plans this is an extra one-time fee) | **0** |
| `trial_period_days` | **7** | **7** |
| `currency` | `usd` (or your choice) | same |
| `release_method` | `buy_now` | `buy_now` |

API reference (verified): `POST /products` needs `account_id` (`biz_...`) and `title` (permissions
`access_pass:create`, `access_pass:basic:read`); `POST /plans` needs `product_id`, `plan_type`,
`release_method`, `currency`, `billing_period`, prices, `trial_period_days` and `visibility`
(permission `plan:create`).

> **Only one trial.** The 7-day trial is the Whop trial (card collected at checkout, first charge on
> day 8). There is no in-app trial, so users never get 14 days. Whop blocks repeated trials for the
> same buyer; returning users are charged immediately.

### 2.2 API key

Create a company API key with only the permissions the functions and setup need:

| Permission | Why |
|------------|-----|
| `checkout_configuration:create` | `whop-checkout` creates checkout configurations |
| `checkout_configuration:basic:read` | Required by the checkout configuration endpoint |
| `plan:create`, `access_pass:create`, `access_pass:update` | Listed as required by the checkout configuration endpoint; also used for setup |
| `access_pass:basic:read` | Product setup through the API |
| `developer:manage_webhook` | Create the webhook through the API (optional if done in the dashboard) |
| `webhook_receive:memberships`, `webhook_receive:payments` | Receive membership and payment webhooks |
| `member:basic:read` | Optional: support tooling to read memberships |

Store the key only as the `WHOP_API_KEY` function secret.

### 2.3 Webhook

- **URL:** `https://<project-ref>.supabase.co/functions/v1/whop-webhook`
- **Events:** `membership.activated`, `membership.deactivated`,
  `membership.cancel_at_period_end_changed`, `membership.trial_ending_soon`
  (optionally `payment.succeeded`, `payment.failed` for the event log).
- **API version:** pin `api_version_date` when creating the webhook so the payload shape is stable.
  The function accepts both the legacy (`plan.id`, `renewal_period_end`) and the versioned
  (`plan_id`, `current_period_end`) membership layouts.
- API alternative: `POST /webhooks` with `{ "url", "events", "resource_id"? }` (permission
  `developer:manage_webhook`); the response includes `webhook_secret`.
- Save the `ws_...` secret as `WHOP_WEBHOOK_SECRET`, exactly as provided (do not strip the prefix or
  base64-encode it).

### 2.4 Link plans to the database

Production does not use the seed. Insert the plans with the **production** Whop plan ids and your
final prices (the seed prices are placeholders):

```sql
insert into public.subscription_plans
  (id, whop_plan_id, billing_period_days, price_cents, currency, label, savings_label, sort_order, active)
values
  ('monthly',   'plan_PRODUCTION_MONTHLY',   30,  999, 'USD', 'Mensual',    null,         1, true),
  ('quarterly', 'plan_PRODUCTION_QUARTERLY', 90, 2499, 'USD', 'Trimestral', 'Ahorra 17%', 2, true)
on conflict (id) do update
  set whop_plan_id = excluded.whop_plan_id,
      price_cents = excluded.price_cents,
      savings_label = excluded.savings_label,
      active = excluded.active;
```

Run it in the Supabase SQL editor. Keep `price_cents` and `savings_label` in sync with Whop.

### 2.5 Trial reminder (pending)

Before launch, send a reminder before the first charge when `membership.trial_ending_soon` arrives
(TODO in `supabase/functions/whop-webhook/handler.ts`). Until then, show `trial_ends_at` from
`my_access()` prominently in the app and link to Whop's manage page for cancellation.

---

## Local webhooks

Whop rejects `localhost` webhook URLs. Pick one:

**A. Tunnel to the local functions (real sandbox events)**

```bash
npx supabase@latest start
npx supabase@latest functions serve                 # uses supabase/functions/.env (sandbox values)
cloudflared tunnel --url http://127.0.0.1:54421     # or: ngrok http 54421
```

Create a **sandbox** webhook pointing to `https://<tunnel-host>/functions/v1/whop-webhook` and put
its secret in `supabase/functions/.env`. The checkout redirect goes to `APP_URL`
(`http://localhost:3000/checkout/return`).

**B. Grant a dev entitlement (no Whop involved)**

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54422/postgres" \
  -v email=you@example.com -f supabase/snippets/grant_dev_entitlement.sql
```

Dev only: it writes `entitlements` as the database owner. Clients can never do this (pgTAP-tested).

---

## 3. Vercel Pro

1. Create a project (for example `flui-web`) under the Pro team. Commercial use requires a paid plan.
2. **Settings → Build & Deployment:** Framework Preset *Other*; enable the Build Command override and
   leave it empty; Root Directory empty (it also applies to CLI deploys).
3. **Settings → Git:** do not connect the repository, or disable automatic Git deployments. Deploys
   come only from GitHub Actions.
4. **IDs:** run `npx vercel@59.16.0 link` locally once and read `orgId` and `projectId` from
   `.vercel/project.json` (git-ignored), or copy them from the team and project settings.
5. **Token:** Account Settings → Tokens → create a token scoped to the team.
6. **Domain:** add the production domain, then use it for `APP_URL`, `ALLOWED_ORIGINS` and the
   Supabase Site URL.
7. The app must contain `app/vercel.json` with the SPA rewrite
   (`{"rewrites": [{"source": "/(.*)", "destination": "/index.html"}]}`); the workflow copies it into
   `build/web`.

---

## 4. GitHub secrets

Repository → Settings → Secrets and variables → Actions (the deploy job uses the `production`
environment, which can hold them too).

| Secret | Used by | Value |
|--------|---------|-------|
| `SUPABASE_URL` | web-deploy, supabase-keepalive | `https://<project-ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | web-deploy, supabase-keepalive | publishable (anon) key; safe for clients |
| `VERCEL_TOKEN` | web-deploy | token from §3.5 |
| `VERCEL_ORG_ID` | web-deploy | `orgId` |
| `VERCEL_PROJECT_ID` | web-deploy | `projectId` |

```bash
gh secret set SUPABASE_URL --body "https://<project-ref>.supabase.co"
gh secret set SUPABASE_ANON_KEY        # paste when prompted
gh secret set VERCEL_TOKEN
gh secret set VERCEL_ORG_ID
gh secret set VERCEL_PROJECT_ID
```

Never add `WHOP_*` or the service role key to GitHub: they belong to Supabase function secrets only.

---

## 5. Keep-alive (Supabase Free plan)

Free projects pause after one week of inactivity. `.github/workflows/supabase-keepalive.yml` reads
one active plan through the REST API with the anon key on Mondays and Thursdays. Notes:

- GitHub disables scheduled workflows after 60 days without repository activity; re-enable it from
  the Actions tab if that happens.
- Remove the workflow when the project moves to a paid plan.

---

## 6. Go-live checklist

- [ ] `supabase db push` applied every migration; RLS is enabled on every table.
- [ ] Production `subscription_plans` rows use production Whop plan ids and final prices.
- [ ] Both plans have `trial_period_days = 7` and `initial_price = 0`.
- [ ] Function secrets set; both functions deployed; `whop-webhook` answers 401 to an unsigned POST.
- [ ] Production webhook created with the four membership events and a pinned API version.
- [ ] Production smoke test: sign up, start the trial with a real card, `my_access()` shows
      `trialing`, then cancel from Whop and confirm access ends when the membership deactivates.
- [ ] Content loaded after human linguistic review.
- [ ] Custom SMTP configured in Supabase Auth.
- [ ] Vercel domain, `APP_URL`, `ALLOWED_ORIGINS` and Supabase Site URL all match.
- [ ] GitHub secrets set; **web-deploy** succeeded; SPA deep links (for example `/checkout/return`) load.
- [ ] Trial reminder before the first charge is implemented or a manual process is in place.
