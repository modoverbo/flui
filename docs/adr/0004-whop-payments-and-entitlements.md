# ADR 0004: Whop payments, card-upfront trial and entitlements

- **Status:** Accepted (revised 2026-09-13: the in-app no-card trial was replaced by a Whop trial;
  amended 2026-09-29: account deletion cancels the membership, see decision 9)
- **Date:** 2026-09-13
- **Evidence:** [research/mvp-frontend-only.md](../research/mvp-frontend-only.md), Whop docs
  (checkout configurations, memberships, webhooks), verified 2026-09-13; membership cancellation
  verified 2026-09-29 against Whop's live OpenAPI spec (`https://api.whop.com/api/v1/openapi.json`)

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
9. **Account deletion cancels the membership, fail closed.** `account-delete` deletes only the
   caller's own account and runs, in order: read the entitlement → cancel the membership → remove
   every object under `speaking-audio/<uid>/` → delete the auth user. Any failure stops the chain, so
   an account is never deleted while its membership may still renew.
   - **Cancel at period end, not immediately** (founder decision): `POST /memberships/{id}/cancel`
     with `cancel_at_period_end: true` stops renewal; access in Whop lasts until the paid period
     ends. There is no refund. The call is skipped when the entitlement is not live or is already
     `cancel_at_period_end`, and uses a deterministic `Idempotency-Key` so a retry cannot double-act.
   - **Response handling** (`_shared/whop_membership.ts`): a 200 counts only if the membership is
     `cancel_at_period_end` or already canceled, expired or completed. A 409 has no documented
     meaning, so it is resolved by `GET /memberships/{id}` and succeeds only on those same states. A
     404 fails closed as `membership_not_found`: a canceled membership still exists, so a 404 means a
     wrong environment, company or id, and deleting the account would leave a live membership
     billing. Every other failure also stops the deletion.
   - **Later webhooks:** Whop still sends `membership.cancel_at_period_end_changed` and, at period
     end, `membership.deactivated`. The `entitlements` row is gone with the user (`on delete cascade`),
     so the write hits a foreign-key violation that `whop-webhook` maps to `unknown_user` and answers
     200; Whop stops retrying and no orphan row is created.
   - The `whop_webhook_events` log is not tied to the user and survives deletion, so its payload is
     minimised: `whop-webhook` stores only `timestamp`, `membership_id`, `plan_id`, `status` and
     `app_user_id` (the webhook id and event type are their own columns) and drops the rest of the
     body, including the buyer's Whop identity. A CHECK constraint enforces that allow-list, and
     migration `20260930130000_whop_webhook_events_minimize_payload.sql` scrubbed the rows stored
     before it.

## Consequences

- Fewer signups turn into trials than with a no-card trial, but every trial is a strong purchase
  intent signal and converts automatically.
- **Risk to monitor:** card penetration and card-not-present acceptance in Latin America may reduce
  trial starts. Track paywall → checkout → trial conversion by country.
- The webhook may lag behind the redirect; the app must poll `my_access()`.
- Entitlements are written only by the service role; pgTAP tests prove clients cannot write them.
- Web-only payments avoid app-store billing rules for now (ADR 0005).
- Account deletion depends on Whop being reachable: while it is down, deletion fails with
  `billing_unavailable` and the user must retry. A `whop_membership_not_found` failure needs a human
  to check the configuration or the stored membership id.
- `WHOP_API_KEY` needs the `membership:cancel` (or `member:manage`) scope for `account-delete`.

## Alternatives considered

| Option | Why not |
|--------|---------|
| In-app trial without card (`profiles.trial_ends_at`) | Rejected by the founder: weaker intent signal, manual conversion step, and Whop cannot run card-less trials anyway |
| Card requested after the first session | Rejected by the founder: extra flow complexity for an unvalidated gain |
| First words free, rest gated | Superseded: all content requires access; the paywall shows value through copy and the trial |
| Hosted plan link without checkout configuration | No reliable user mapping (only a prefilled email) |
| Whop OAuth and client-side access checks | Not enforceable by RLS; second login for users |
