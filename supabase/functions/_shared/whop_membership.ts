/**
 * Whop membership cancellation — a fail-closed primitive consumed by account
 * deletion (U22b). Never guesses at billing state: any ambiguous or
 * unexpected response rejects rather than assuming the membership was
 * canceled.
 *
 * Contract verified against Whop's live OpenAPI spec (memory obs #892,
 * fetched 2026-09-29, spec version 1.0.0):
 * - `POST {baseUrl}/memberships/{id}/cancel`, Bearer auth with scope
 *   `membership:cancel` or `member:manage`.
 * - Body `{ cancel_at_period_end, reason? }`. Per decision #434/#894, this
 *   helper always sends `cancel_at_period_end: true` — renewal stops, the
 *   membership stays active until the paid period ends, no refund.
 * - Optional `Idempotency-Key` header (<= 255 chars; a replay within 24h
 *   returns the stored response).
 * - 200 returns the Membership (`status` + `cancel_at_period_end`). 404
 *   means the membership is unknown. 409 is Conflict with no documented
 *   meaning, so this helper re-reads the membership via `GET
 *   {baseUrl}/memberships/{id}` before deciding.
 */
import type { WhopClientOptions } from "./checkout.ts";

const MEMBERSHIP_ID_PATTERN = /^mem_.+$/;
const DEFAULT_TIMEOUT_MS = 10_000;
const MAX_IDEMPOTENCY_KEY_LENGTH = 255;

/** Whop's `Membership.status` enum, per the verified OpenAPI spec. */
export type WhopMembershipStatus =
  | "trialing"
  | "active"
  | "past_due"
  | "completed"
  | "canceled"
  | "expired"
  | "unresolved";

/** Statuses that mean the membership will never renew again. */
const NON_RENEWING_STATUSES: ReadonlySet<WhopMembershipStatus> = new Set([
  "canceled",
  "expired",
  "completed",
]);

export interface CancelMembershipOptions {
  /** Forwarded to Whop as the cancellation reason. */
  reason?: string;
  /**
   * Overrides the derived `Idempotency-Key`. Truncated to 255 chars; must
   * never contain secrets — this is sent to Whop as a plain header.
   */
  idempotencyKey?: string;
  /** Aborts the Whop call after this many milliseconds. Defaults to 10s. */
  timeoutMs?: number;
}

export type CancelMembershipResult =
  | { outcome: "canceled"; status: WhopMembershipStatus; cancelAtPeriodEnd: boolean }
  | { outcome: "alreadyGone" }
  | { outcome: "alreadyCanceled"; status: WhopMembershipStatus; cancelAtPeriodEnd: boolean };

export type CancelMembershipErrorReason =
  | "invalid_membership_id"
  | "network_error"
  | "timeout"
  | "http_error"
  | "unexpected_response"
  | "unresolved_conflict";

/**
 * A typed, fail-closed error. `status` is Whop's HTTP status when one
 * exists (e.g. 401/403/500/409-then-failed-GET), `undefined` for a network
 * failure or timeout. Never carries the API key.
 */
export class CancelMembershipError extends Error {
  constructor(
    readonly reason: CancelMembershipErrorReason,
    readonly status: number | undefined,
    message: string,
  ) {
    super(message);
    this.name = "CancelMembershipError";
  }
}

interface ParsedMembership {
  status: WhopMembershipStatus;
  cancelAtPeriodEnd: boolean;
}

function parseMembership(payload: unknown): ParsedMembership | null {
  const body = payload as { status?: unknown; cancel_at_period_end?: unknown } | null;
  const status = body?.status;
  const cancelAtPeriodEnd = body?.cancel_at_period_end;
  if (typeof status !== "string" || typeof cancelAtPeriodEnd !== "boolean") return null;
  return { status: status as WhopMembershipStatus, cancelAtPeriodEnd };
}

function isRenewalStopped(membership: ParsedMembership): boolean {
  return membership.cancelAtPeriodEnd || NON_RENEWING_STATUSES.has(membership.status);
}

function membershipUrl(baseUrl: string, membershipId: string): string {
  return `${baseUrl.replace(/\/+$/, "")}/memberships/${encodeURIComponent(membershipId)}`;
}

function deriveIdempotencyKey(membershipId: string, options: CancelMembershipOptions): string {
  const key = options.idempotencyKey ?? `flui-account-delete-${membershipId}`;
  return key.slice(0, MAX_IDEMPOTENCY_KEY_LENGTH);
}

function classifyFetchFailure(cause: unknown): CancelMembershipError {
  const isTimeout = cause instanceof DOMException && cause.name === "TimeoutError";
  return new CancelMembershipError(
    isTimeout ? "timeout" : "network_error",
    undefined,
    isTimeout ? "Timed out reaching Whop." : "Could not reach Whop.",
  );
}

async function getMembership(
  client: WhopClientOptions,
  membershipId: string,
  timeoutMs: number,
): Promise<ParsedMembership | null> {
  let response: Response;
  try {
    response = await client.fetch(membershipUrl(client.baseUrl, membershipId), {
      method: "GET",
      headers: { Authorization: `Bearer ${client.apiKey}` },
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (cause) {
    throw classifyFetchFailure(cause);
  }
  if (!response.ok) {
    throw new CancelMembershipError(
      "unresolved_conflict",
      response.status,
      `Whop returned 409 for the cancellation and the follow-up GET also failed (${response.status}).`,
    );
  }
  const payload = await response.json().catch(() => null);
  return parseMembership(payload);
}

async function resolveConflict(
  client: WhopClientOptions,
  membershipId: string,
  timeoutMs: number,
): Promise<CancelMembershipResult> {
  const membership = await getMembership(client, membershipId, timeoutMs);
  if (membership !== null && isRenewalStopped(membership)) {
    return {
      outcome: "alreadyCanceled",
      status: membership.status,
      cancelAtPeriodEnd: membership.cancelAtPeriodEnd,
    };
  }
  throw new CancelMembershipError(
    "unresolved_conflict",
    409,
    "Whop returned 409 for the cancellation and the membership is not canceled.",
  );
}

/**
 * Cancels a Whop membership at the end of its current billing period
 * (decision #434/#894: `cancel_at_period_end: true`, never immediate).
 * Fails closed on any ambiguous or unexpected response — the caller (U22b)
 * must abort account deletion on any rejection.
 */
export async function cancelMembership(
  client: WhopClientOptions,
  membershipId: string,
  options: CancelMembershipOptions = {},
): Promise<CancelMembershipResult> {
  if (typeof membershipId !== "string" || !MEMBERSHIP_ID_PATTERN.test(membershipId)) {
    throw new CancelMembershipError(
      "invalid_membership_id",
      undefined,
      'membershipId must be a non-empty string starting with "mem_".',
    );
  }

  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const body: Record<string, unknown> = { cancel_at_period_end: true };
  if (options.reason !== undefined) body.reason = options.reason;

  let response: Response;
  try {
    response = await client.fetch(`${membershipUrl(client.baseUrl, membershipId)}/cancel`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${client.apiKey}`,
        "Content-Type": "application/json",
        "Idempotency-Key": deriveIdempotencyKey(membershipId, options),
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (cause) {
    throw classifyFetchFailure(cause);
  }

  if (response.status === 404) {
    return { outcome: "alreadyGone" };
  }

  if (response.status === 409) {
    return await resolveConflict(client, membershipId, timeoutMs);
  }

  if (!response.ok) {
    throw new CancelMembershipError(
      "http_error",
      response.status,
      `Whop rejected the membership cancellation (${response.status}).`,
    );
  }

  const payload = await response.json().catch(() => null);
  const membership = parseMembership(payload);
  if (membership === null) {
    throw new CancelMembershipError(
      "unexpected_response",
      response.status,
      "Whop returned an unrecognized membership shape after cancellation.",
    );
  }
  if (isRenewalStopped(membership)) {
    return {
      outcome: "canceled",
      status: membership.status,
      cancelAtPeriodEnd: membership.cancelAtPeriodEnd,
    };
  }
  throw new CancelMembershipError(
    "unexpected_response",
    response.status,
    `Whop's membership is still renewing after a 200 cancellation response (status=${membership.status}).`,
  );
}
