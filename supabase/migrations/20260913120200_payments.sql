-- Payments: Whop plans, per-user entitlements and the webhook event log.
--
-- Clients can read active plans (anon included, for the pricing screen) and their
-- own entitlement. Every write goes through the Edge Functions with the service
-- role. Webhook events are never visible to clients.

-- subscription_plans ------------------------------------------------------------------------

create table if not exists public.subscription_plans (
  id text primary key check (id ~ '^[a-z][a-z0-9_]*$'),
  whop_plan_id text not null,
  billing_period_days integer not null check (billing_period_days > 0),
  price_cents integer not null check (price_cents >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  label text not null check (btrim(label) <> ''),
  savings_label text,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.subscription_plans is 'Purchasable plans. `id` is the stable app-facing key (monthly, quarterly); whop_plan_id maps to Whop.';
comment on column public.subscription_plans.label is 'User-facing plan name (Spanish).';

drop trigger if exists subscription_plans_set_updated_at on public.subscription_plans;
create trigger subscription_plans_set_updated_at
  before update on public.subscription_plans
  for each row execute function public.set_updated_at();

alter table public.subscription_plans enable row level security;

revoke all on table public.subscription_plans from anon, authenticated;
grant select on table public.subscription_plans to anon, authenticated;
grant all on table public.subscription_plans to service_role;

drop policy if exists subscription_plans_select_active on public.subscription_plans;
create policy subscription_plans_select_active on public.subscription_plans
  for select to anon, authenticated
  using (active);

-- entitlements --------------------------------------------------------------------------------

create table if not exists public.entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  whop_membership_id text not null unique,
  whop_plan_id text not null,
  status text not null check (status in ('trialing', 'active', 'past_due', 'canceled', 'expired')),
  current_period_end timestamptz,
  trial_ends_at timestamptz,
  cancel_at_period_end boolean not null default false,
  last_event_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.entitlements is 'Current Whop membership state per user. Written only by the whop-webhook Edge Function.';
comment on column public.entitlements.status is 'Whop membership status mapped to flui: trialing and active grant access.';
comment on column public.entitlements.trial_ends_at is 'End of the Whop free trial (first charge date). Set while the membership is trialing.';
comment on column public.entitlements.last_event_at is 'Timestamp of the newest webhook applied; older, out-of-order events are ignored.';

drop trigger if exists entitlements_set_updated_at on public.entitlements;
create trigger entitlements_set_updated_at
  before update on public.entitlements
  for each row execute function public.set_updated_at();

alter table public.entitlements enable row level security;

revoke all on table public.entitlements from anon, authenticated;
grant select on table public.entitlements to authenticated;
grant all on table public.entitlements to service_role;

drop policy if exists entitlements_select_own on public.entitlements;
create policy entitlements_select_own on public.entitlements
  for select to authenticated
  using (user_id = (select auth.uid()));

-- whop_webhook_events ---------------------------------------------------------------------------

create table if not exists public.whop_webhook_events (
  webhook_id text primary key,
  event_type text not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  payload jsonb not null
);

comment on table public.whop_webhook_events is 'Idempotency log of verified Whop webhooks (keyed by the webhook-id header). Service role only.';

alter table public.whop_webhook_events enable row level security;

revoke all on table public.whop_webhook_events from anon, authenticated;
grant all on table public.whop_webhook_events to service_role;
-- No policies: RLS denies every client row; the service role bypasses RLS.
