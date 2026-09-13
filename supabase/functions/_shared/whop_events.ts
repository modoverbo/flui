/**
 * Pure mapping from Whop webhook events to rows of `public.entitlements`.
 *
 * Whop sends membership objects in two layouts depending on the webhook's
 * `api_version_date` pin:
 *   - legacy:    plan.id, renewal_period_end
 *   - versioned: plan_id, current_period_end
 * Both are supported. The membership inherits `metadata.app_user_id` from the
 * checkout configuration created by the whop-checkout function.
 */
import { HttpError } from "./http.ts";

export type EntitlementStatus = "trialing" | "active" | "past_due" | "canceled" | "expired";

export interface WhopEnvelope {
  id?: string;
  type: string;
  api_version?: string;
  timestamp?: string | number;
  account_id?: string;
  company_id?: string;
  data: Record<string, unknown>;
}

export const MEMBERSHIP_EVENTS = [
  "membership.activated",
  "membership.deactivated",
  "membership.cancel_at_period_end_changed",
  "membership.trial_ending_soon",
] as const;

export type MembershipEventType = (typeof MEMBERSHIP_EVENTS)[number];

/** A membership event normalized for flui. `trialEndsAt: undefined` means "unknown, keep what we have". */
export interface EntitlementUpdate {
  userId: string;
  membershipId: string;
  whopPlanId: string;
  status: EntitlementStatus;
  currentPeriodEnd: string | null;
  trialEndsAt: string | undefined;
  cancelAtPeriodEnd: boolean;
  eventAt: string;
}

export type IgnoreReason =
  | "not_a_membership_event"
  | "missing_app_user_id"
  | "invalid_membership"
  | "unmapped_status";

export type MappingResult =
  | { kind: "apply"; update: EntitlementUpdate }
  | { kind: "ignore"; reason: IgnoreReason };

/** Shape of a row in public.entitlements (snake_case, as stored). */
export interface EntitlementRow {
  user_id: string;
  whop_membership_id: string;
  whop_plan_id: string;
  status: EntitlementStatus;
  current_period_end: string | null;
  trial_ends_at: string | null;
  cancel_at_period_end: boolean;
  last_event_at: string | null;
}

export type StoredEntitlement = EntitlementRow;

export type WriteDecision =
  | { kind: "write"; row: EntitlementRow }
  | { kind: "skip"; reason: "stale_event" | "other_membership_inactive" };

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const STATUS_MAP: Record<string, EntitlementStatus> = {
  trialing: "trialing",
  active: "active",
  // Cancellation scheduled for the end of the period: access continues until then.
  canceling: "active",
  past_due: "past_due",
  unresolved: "past_due",
  completed: "expired",
  expired: "expired",
  canceled: "canceled",
};

const ACCESS_STATUSES: ReadonlySet<EntitlementStatus> = new Set(["trialing", "active"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function nonEmptyString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() !== "" ? value : undefined;
}

/** Accepts ISO strings and unix timestamps (seconds); returns an ISO string or null. */
function toIsoOrNull(value: unknown): string | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return new Date(value * 1000).toISOString();
  }
  if (typeof value === "string" && value.trim() !== "") {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }
  return null;
}

export function parseWhopEnvelope(value: unknown): WhopEnvelope {
  if (!isRecord(value) || typeof value.type !== "string" || !isRecord(value.data)) {
    throw new HttpError(
      400,
      "invalid_payload",
      "Expected a Whop webhook envelope with type and data.",
    );
  }
  return value as unknown as WhopEnvelope;
}

export function mapWhopMembershipStatus(status: unknown): EntitlementStatus | null {
  return typeof status === "string" ? STATUS_MAP[status] ?? null : null;
}

function isMembershipEvent(type: string): type is MembershipEventType {
  return (MEMBERSHIP_EVENTS as readonly string[]).includes(type);
}

export function entitlementUpdateFromEvent(
  envelope: WhopEnvelope,
  receivedAt: Date,
): MappingResult {
  if (!isMembershipEvent(envelope.type)) {
    return { kind: "ignore", reason: "not_a_membership_event" };
  }
  const membership = envelope.data;

  const userId = isRecord(membership.metadata) ? membership.metadata.app_user_id : undefined;
  if (typeof userId !== "string" || !UUID_PATTERN.test(userId)) {
    return { kind: "ignore", reason: "missing_app_user_id" };
  }

  const membershipId = nonEmptyString(membership.id);
  const whopPlanId = nonEmptyString(isRecord(membership.plan) ? membership.plan.id : undefined) ??
    nonEmptyString(membership.plan_id);
  if (!membershipId || !whopPlanId) {
    return { kind: "ignore", reason: "invalid_membership" };
  }

  let status: EntitlementStatus | null;
  if (membership.status === undefined || membership.status === null) {
    status = envelope.type === "membership.deactivated"
      ? "canceled"
      : envelope.type === "membership.activated"
      ? "active"
      : null;
  } else {
    status = mapWhopMembershipStatus(membership.status);
  }
  if (status === null) {
    return { kind: "ignore", reason: "unmapped_status" };
  }

  const currentPeriodEnd = toIsoOrNull(
    membership.renewal_period_end ?? membership.current_period_end,
  );

  return {
    kind: "apply",
    update: {
      userId: userId.toLowerCase(),
      membershipId,
      whopPlanId,
      status,
      currentPeriodEnd,
      // While trialing, the current period ends when the free trial ends (first charge).
      trialEndsAt: status === "trialing" ? currentPeriodEnd ?? undefined : undefined,
      cancelAtPeriodEnd: membership.cancel_at_period_end === true,
      eventAt: toIsoOrNull(envelope.timestamp) ?? receivedAt.toISOString(),
    },
  };
}

/** True when the event belongs to a different Whop company than the configured one. */
export function isForeignAccount(envelope: WhopEnvelope, companyId: string | undefined): boolean {
  if (!companyId) return false;
  const eventAccount = envelope.account_id ?? envelope.company_id;
  return eventAccount !== undefined && eventAccount !== companyId;
}

/** Decides whether an update may overwrite the stored entitlement (ordering and multi-membership safety). */
export function decideEntitlementWrite(
  current: StoredEntitlement | null,
  update: EntitlementUpdate,
): WriteDecision {
  const sameMembership = current?.whop_membership_id === update.membershipId;

  if (
    current && sameMembership && current.last_event_at &&
    Date.parse(update.eventAt) < Date.parse(current.last_event_at)
  ) {
    return { kind: "skip", reason: "stale_event" };
  }

  if (
    current && !sameMembership && ACCESS_STATUSES.has(current.status) &&
    !ACCESS_STATUSES.has(update.status)
  ) {
    // An old membership ending must never revoke a newer membership that still grants access.
    return { kind: "skip", reason: "other_membership_inactive" };
  }

  const previousTrialEnd = sameMembership ? current?.trial_ends_at ?? null : null;

  return {
    kind: "write",
    row: {
      user_id: update.userId,
      whop_membership_id: update.membershipId,
      whop_plan_id: update.whopPlanId,
      status: update.status,
      current_period_end: update.currentPeriodEnd,
      trial_ends_at: update.trialEndsAt ?? previousTrialEnd,
      cancel_at_period_end: update.cancelAtPeriodEnd,
      last_event_at: update.eventAt,
    },
  };
}
