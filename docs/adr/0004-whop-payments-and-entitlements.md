# ADR 0004: Whop payments, card-upfront trial and entitlements

- **Status:** Accepted (revised 2026-09-13: the in-app no-card trial was replaced by a Whop trial)
- **Date:** 2026-09-13
- **Evidence:** [research/mvp-frontend-only.md](../research/mvp-frontend-only.md), Whop docs
  (checkout configurations, memberships, webhooks), verified 2026-09-13

## Context

flui sells a subscription on the web. Requirements:

- One product with two recurring plans: **monthly** (`billing_period` 30) and **quarterly**
  (`billing_period` 90, discounted).
- A **7-day free trial**.
- The Whop API key and webhook secret must never reach the client.
- Access must be enforceable by the database (RLS), not only by the UI.
- No custom backend beyond one Supabase Edge Functions area.

Whop facts that shape the design:

- A checkout configuration created with the API key carries `metadata`, and memberships created
  from it inherit that metadata. This is the only reliable way to link a Whop membership to a
  Supabase user.
- Whop trials require a payment method ("When you start a free trial, you must provide a valid
  payment method"). `trial_period_days` is set on the plan; Whop blocks repeated trials.
- Webhooks follow Standard Webhooks (HMAC-SHA256, 5-minute tolerance) and are delivered at least
  once; Whop cannot deliver to `localhost`.

## Decision

1. **Trial model: Whop trial with the card collected at signup.** Both plans have
   `trial_period_days = 7` and `initial_price = 0` (for renewal plans `initial_price` is an extra
   one-time fee). The first charge happens on day 8. A signup alone grants nothing.
2. **App flow:** Register → Paywall ("7 días gratis. Hoy no te cobramos nada.") → `whop-checkout`
   → Whop hosted checkout → `APP_URL/checkout/return` → poll `my_access()` → Time budget → Hoy.
3. **`whop-checkout`** verifies the Supabase JWT, checks the plan in `subscription_plans`, refuses
   users who already have access (409), and creates a checkout configuration with `plan_id`,
   `metadata.app_user_id` and `redirect_url`. It returns `purchaseUrl`.
4. **`whop-webhook`** verifies the signature, stores each event by `webhook-id` (idempotent), maps
   `membership.activated`, `membership.deactivated`, `membership.cancel_at_period_end_changed` and
   `membership.trial_ending_soon` to one `entitlements` row per user, ignores stale events and never
   lets an old membership's deactivation revoke a newer one. Other events are stored and answered 200.
5. **Access = entitlement only:** `has_access(uid)` is true when `status in ('trialing','active')`
   and `current_period_end` is null or in the future. `my_access()` exposes
   `{has_access, entitlement_status, current_period_end, trial_ends_at}`.
6. **All content is paid:** words, confusions, exercises, options and readings require `has_access()`
   in RLS. There are no free words. Plans stay readable by `anon` and `authenticated` so the paywall
   can show prices.
7. **Transparency before the first charge:** handle `membership.trial_ending_soon` (entitlement stays
   `trialing`) and send a reminder before day 8. The reminder email is a **TODO** (marked in
   `whop-webhook/handler.ts`); until it exists, the app shows `trial_ends_at` clearly and Whop's own
   receipts apply. Cancelling must stay one click away (Whop `manage_url`). No dark patterns.
8. **Local development:** use `supabase/snippets/grant_dev_entitlement.sql` (dev only) or a tunnel to
   `supabase functions serve` for real sandbox webhooks.

## Consequences

- Fewer signups turn into trials than with a no-card trial, but every trial is a strong purchase
  intent signal and converts automatically.
- **Risk to monitor:** card penetration and card-not-present acceptance in Latin America may reduce
  trial starts. Track paywall → checkout → trial conversion by country.
- The webhook may lag behind the redirect; the app must poll `my_access()`.
- Entitlements are written only by the service role; pgTAP tests prove clients cannot write them.
- Web-only payments avoid app-store billing rules for now (ADR 0005).

## Alternatives considered

| Option | Why not |
|--------|---------|
| In-app trial without card (`profiles.trial_ends_at`) | Rejected by the founder: weaker intent signal, manual conversion step, and Whop cannot run card-less trials anyway |
| Card requested after the first session | Rejected by the founder: extra flow complexity for an unvalidated gain |
| First words free, rest gated | Superseded: all content requires access; the paywall shows value through copy and the trial |
| Hosted plan link without checkout configuration | No reliable user mapping (only a prefilled email) |
| Whop OAuth and client-side access checks | Not enforceable by RLS; second login for users |
