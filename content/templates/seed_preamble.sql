-- flui local/dev seed. Applied by `supabase db reset` (never pushed to production by `db push`).
--
-- Contents:
--   1. subscription_plans: the two Whop plans. PLACEHOLDER PRICES (USD cents) to be
--      confirmed by the founder. whop_plan_id values point to the Whop SANDBOX
--      product; production needs its own plans and an UPDATE of whop_plan_id
--      (see docs/deployment.md).
--   2. Eight original starter words (Spanish product content) that follow the
--      selection criteria and content guidelines in docs/learning-method.md.
--      Definitions are written in-house (no RAE text). AI-assisted drafts: they
--      require human linguistic review before production use.
--
-- Invariants covered by supabase/tests/database/060_seed_content.test.sql.
-- Each exercise and its options are inserted in ONE statement so the deferred
-- "exactly 3 options, exactly 1 correct" constraint trigger passes even in
-- autocommit mode.

-- ============================================================================
-- 1. Subscription plans (founder-confirmed prices; Whop sandbox plan ids)
-- ============================================================================

insert into public.subscription_plans
  (id, whop_plan_id, billing_period_days, price_cents, currency, label, savings_label, sort_order, active)
values
  ('monthly', 'plan_rtRdHbN0gLgBh', 30, 699, 'USD', 'Mensual', null, 1, true),     -- founder-confirmed price
  ('quarterly', 'plan_xr6Skp0dSxxcz', 90, 1615, 'USD', 'Trimestral', 'Ahorra 23%', 2, true) -- founder-confirmed price
on conflict (id) do update
  set whop_plan_id = excluded.whop_plan_id,
      billing_period_days = excluded.billing_period_days,
      price_cents = excluded.price_cents,
      currency = excluded.currency,
      label = excluded.label,
      savings_label = excluded.savings_label,
      sort_order = excluded.sort_order,
      active = excluded.active;

-- ============================================================================
-- 2. Starter words
-- ============================================================================

