import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.19";
import { HttpError } from "./http.ts";
import {
  decideEntitlementWrite,
  type EntitlementUpdate,
  entitlementUpdateFromEvent,
  isForeignAccount,
  mapWhopMembershipStatus,
  minimizeWhopPayload,
  parseWhopEnvelope,
  type StoredEntitlement,
  type WhopEnvelope,
} from "./whop_events.ts";

const USER_ID = "5b7f6a3e-2d1c-4b9a-8f0e-1a2b3c4d5e6f";
const RECEIVED_AT = new Date("2026-09-13T12:00:00Z");

function legacyMembership(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: "mem_legacy",
    status: "trialing",
    plan: { id: "plan_monthly" },
    metadata: { app_user_id: USER_ID },
    renewal_period_end: "2026-09-20T12:00:00Z",
    cancel_at_period_end: false,
    ...overrides,
  };
}

function envelope(
  type: string,
  data: Record<string, unknown>,
  extra: Partial<WhopEnvelope> = {},
): WhopEnvelope {
  return {
    id: "msg_1",
    type,
    timestamp: "2026-09-13T11:59:00Z",
    api_version: "v1",
    data,
    ...extra,
  };
}

// parseWhopEnvelope -------------------------------------------------------------------------

Deno.test("parseWhopEnvelope accepts the v1 envelope", () => {
  const parsed = parseWhopEnvelope({
    id: "msg_1",
    type: "membership.activated",
    data: { id: "mem_1" },
  });
  assertEquals(parsed.type, "membership.activated");
  assertEquals(parsed.data, { id: "mem_1" });
});

Deno.test("parseWhopEnvelope rejects payloads without type or data object", () => {
  for (
    const value of [null, "x", {}, { type: "membership.activated" }, { type: 1, data: {} }, {
      type: "a",
      data: [],
    }]
  ) {
    const error = assertThrows(() => parseWhopEnvelope(value), HttpError);
    assertEquals(error.code, "invalid_payload");
  }
});

// mapWhopMembershipStatus ---------------------------------------------------------------------

Deno.test("mapWhopMembershipStatus maps every documented Whop status", () => {
  const cases: Array<[string, string | null]> = [
    ["trialing", "trialing"],
    ["active", "active"],
    ["canceling", "active"],
    ["past_due", "past_due"],
    ["unresolved", "past_due"],
    ["completed", "expired"],
    ["expired", "expired"],
    ["canceled", "canceled"],
    ["drafted", null],
    ["something_new", null],
  ];
  for (const [whop, flui] of cases) {
    assertEquals(mapWhopMembershipStatus(whop), flui, whop);
  }
  assertEquals(mapWhopMembershipStatus(undefined), null);
});

// entitlementUpdateFromEvent ---------------------------------------------------------------------

Deno.test("a trialing membership (legacy layout) becomes a trialing entitlement with its trial end", () => {
  const result = entitlementUpdateFromEvent(
    envelope("membership.activated", legacyMembership()),
    RECEIVED_AT,
  );
  assertEquals(result, {
    kind: "apply",
    update: {
      userId: USER_ID,
      membershipId: "mem_legacy",
      whopPlanId: "plan_monthly",
      status: "trialing",
      currentPeriodEnd: "2026-09-20T12:00:00.000Z",
      trialEndsAt: "2026-09-20T12:00:00.000Z",
      cancelAtPeriodEnd: false,
      eventAt: "2026-09-13T11:59:00.000Z",
    },
  });
});

Deno.test("the versioned membership layout (plan_id, current_period_end) is supported", () => {
  const data = {
    id: "mem_v2",
    status: "active",
    plan_id: "plan_quarterly",
    current_period_end: "2026-12-12T00:00:00Z",
    cancel_at_period_end: true,
    metadata: { app_user_id: USER_ID },
  };
  const result = entitlementUpdateFromEvent(
    envelope("membership.cancel_at_period_end_changed", data),
    RECEIVED_AT,
  );
  assertEquals(result.kind, "apply");
  if (result.kind !== "apply") return;
  assertEquals(result.update.whopPlanId, "plan_quarterly");
  assertEquals(result.update.status, "active");
  assertEquals(result.update.currentPeriodEnd, "2026-12-12T00:00:00.000Z");
  assertEquals(result.update.trialEndsAt, undefined);
  assertEquals(result.update.cancelAtPeriodEnd, true);
});

Deno.test("membership.trial_ending_soon keeps the entitlement trialing", () => {
  const result = entitlementUpdateFromEvent(
    envelope("membership.trial_ending_soon", legacyMembership()),
    RECEIVED_AT,
  );
  assertEquals(result.kind, "apply");
  if (result.kind !== "apply") return;
  assertEquals(result.update.status, "trialing");
});

Deno.test("membership.deactivated uses the payload status, or canceled when it is missing", () => {
  const withStatus = entitlementUpdateFromEvent(
    envelope("membership.deactivated", legacyMembership({ status: "expired" })),
    RECEIVED_AT,
  );
  const withoutStatus = entitlementUpdateFromEvent(
    envelope("membership.deactivated", legacyMembership({ status: undefined })),
    RECEIVED_AT,
  );
  assertEquals(withStatus.kind === "apply" && withStatus.update.status, "expired");
  assertEquals(withoutStatus.kind === "apply" && withoutStatus.update.status, "canceled");
});

Deno.test("membership.activated without a status defaults to active", () => {
  const result = entitlementUpdateFromEvent(
    envelope("membership.activated", legacyMembership({ status: undefined })),
    RECEIVED_AT,
  );
  assertEquals(result.kind === "apply" && result.update.status, "active");
});

Deno.test("numeric unix timestamps are normalized to ISO strings", () => {
  const result = entitlementUpdateFromEvent(
    envelope("membership.activated", legacyMembership({ renewal_period_end: 1790000000 }), {
      timestamp: undefined,
    }),
    RECEIVED_AT,
  );
  assertEquals(
    result.kind === "apply" && result.update.currentPeriodEnd,
    new Date(1790000000 * 1000).toISOString(),
  );
  assertEquals(result.kind === "apply" && result.update.eventAt, RECEIVED_AT.toISOString());
});

Deno.test("events that are not membership events are ignored", () => {
  assertEquals(
    entitlementUpdateFromEvent(envelope("payment.succeeded", { id: "pay_1" }), RECEIVED_AT),
    { kind: "ignore", reason: "not_a_membership_event" },
  );
  assertEquals(
    entitlementUpdateFromEvent(envelope("something.else", {}), RECEIVED_AT),
    { kind: "ignore", reason: "not_a_membership_event" },
  );
});

Deno.test("memberships without a valid metadata.app_user_id are ignored", () => {
  for (const metadata of [undefined, {}, { app_user_id: "not-a-uuid" }, { app_user_id: 42 }]) {
    assertEquals(
      entitlementUpdateFromEvent(
        envelope("membership.activated", legacyMembership({ metadata })),
        RECEIVED_AT,
      ),
      { kind: "ignore", reason: "missing_app_user_id" },
    );
  }
});

Deno.test("memberships without id or plan are ignored", () => {
  assertEquals(
    entitlementUpdateFromEvent(
      envelope("membership.activated", legacyMembership({ id: undefined })),
      RECEIVED_AT,
    ),
    { kind: "ignore", reason: "invalid_membership" },
  );
  assertEquals(
    entitlementUpdateFromEvent(
      envelope("membership.activated", legacyMembership({ plan: undefined })),
      RECEIVED_AT,
    ),
    { kind: "ignore", reason: "invalid_membership" },
  );
});

Deno.test("drafted or unknown statuses are ignored", () => {
  assertEquals(
    entitlementUpdateFromEvent(
      envelope("membership.activated", legacyMembership({ status: "drafted" })),
      RECEIVED_AT,
    ),
    { kind: "ignore", reason: "unmapped_status" },
  );
});

// isForeignAccount ---------------------------------------------------------------------------------

Deno.test("isForeignAccount compares account_id or company_id with the configured company", () => {
  assertEquals(isForeignAccount(envelope("x", {}, { account_id: "biz_other" }), "biz_flui"), true);
  assertEquals(isForeignAccount(envelope("x", {}, { company_id: "biz_flui" }), "biz_flui"), false);
  assertEquals(isForeignAccount(envelope("x", {}), "biz_flui"), false);
  assertEquals(isForeignAccount(envelope("x", {}, { account_id: "biz_other" }), undefined), false);
});

// decideEntitlementWrite -------------------------------------------------------------------------------

function update(overrides: Partial<EntitlementUpdate> = {}): EntitlementUpdate {
  return {
    userId: USER_ID,
    membershipId: "mem_1",
    whopPlanId: "plan_monthly",
    status: "active",
    currentPeriodEnd: "2026-10-20T12:00:00.000Z",
    trialEndsAt: undefined,
    cancelAtPeriodEnd: false,
    eventAt: "2026-09-21T12:00:00.000Z",
    ...overrides,
  };
}

function stored(overrides: Partial<StoredEntitlement> = {}): StoredEntitlement {
  return {
    user_id: USER_ID,
    whop_membership_id: "mem_1",
    whop_plan_id: "plan_monthly",
    status: "trialing",
    current_period_end: "2026-09-20T12:00:00.000Z",
    trial_ends_at: "2026-09-20T12:00:00.000Z",
    cancel_at_period_end: false,
    last_event_at: "2026-09-13T12:00:00.000Z",
    ...overrides,
  };
}

Deno.test("the first event for a user is written", () => {
  assertEquals(
    decideEntitlementWrite(
      null,
      update({ status: "trialing", trialEndsAt: "2026-09-20T12:00:00.000Z" }),
    ),
    {
      kind: "write",
      row: {
        user_id: USER_ID,
        whop_membership_id: "mem_1",
        whop_plan_id: "plan_monthly",
        status: "trialing",
        current_period_end: "2026-10-20T12:00:00.000Z",
        trial_ends_at: "2026-09-20T12:00:00.000Z",
        cancel_at_period_end: false,
        last_event_at: "2026-09-21T12:00:00.000Z",
      },
    },
  );
});

Deno.test("a newer event for the same membership is written and keeps the known trial end", () => {
  const decision = decideEntitlementWrite(stored(), update());
  assertEquals(decision.kind, "write");
  if (decision.kind !== "write") return;
  assertEquals(decision.row.status, "active");
  assertEquals(decision.row.trial_ends_at, "2026-09-20T12:00:00.000Z");
});

Deno.test("an older event for the same membership is skipped as stale", () => {
  assertEquals(
    decideEntitlementWrite(stored({ last_event_at: "2026-09-22T00:00:00.000Z" }), update()),
    { kind: "skip", reason: "stale_event" },
  );
});

Deno.test("an event with the same timestamp is written again (idempotent)", () => {
  assertEquals(
    decideEntitlementWrite(stored({ last_event_at: "2026-09-21T12:00:00.000Z" }), update()).kind,
    "write",
  );
});

Deno.test("deactivating an old membership never revokes a newer membership that grants access", () => {
  assertEquals(
    decideEntitlementWrite(
      stored({ whop_membership_id: "mem_new", status: "active" }),
      update({ membershipId: "mem_old", status: "canceled" }),
    ),
    { kind: "skip", reason: "other_membership_inactive" },
  );
});

Deno.test("a new membership that grants access replaces an inactive one without inheriting its trial", () => {
  const decision = decideEntitlementWrite(
    stored({ whop_membership_id: "mem_old", status: "canceled" }),
    update({ membershipId: "mem_new", status: "active" }),
  );
  assertEquals(decision.kind, "write");
  if (decision.kind !== "write") return;
  assertEquals(decision.row.whop_membership_id, "mem_new");
  assertEquals(decision.row.trial_ends_at, null);
});

// minimizeWhopPayload -----------------------------------------------------------------------

Deno.test("minimizeWhopPayload keeps only the debugging fields and drops the buyer identity", () => {
  const minimized = minimizeWhopPayload(
    envelope("membership.activated", {
      id: "mem_1",
      status: "trialing",
      plan: { id: "plan_monthly", title: "Flui mensual" },
      metadata: { app_user_id: USER_ID, note: "internal" },
      user: { id: "user_1", email: "buyer@example.com", name: "Ana Buyer", username: "ana" },
      member: { id: "mber_1", user: { email: "buyer@example.com" } },
      email: "buyer@example.com",
      renewal_period_end: "2026-09-20T12:00:00Z",
      payment_method: { card: { last4: "4242" } },
    }),
  );

  assertEquals(minimized, {
    timestamp: "2026-09-13T11:59:00Z",
    membership_id: "mem_1",
    plan_id: "plan_monthly",
    status: "trialing",
    app_user_id: USER_ID,
  });
  const serialized = JSON.stringify(minimized);
  for (const leaked of ["buyer@example.com", "Ana Buyer", "4242", "internal", "user_1"]) {
    assertEquals(serialized.includes(leaked), false, `${leaked} must not be stored`);
  }
});

Deno.test("minimizeWhopPayload reads the versioned layout (plan_id) and unix timestamps", () => {
  assertEquals(
    minimizeWhopPayload(
      envelope("membership.deactivated", {
        id: "mem_2",
        plan_id: "plan_yearly",
        metadata: { app_user_id: USER_ID.toUpperCase() },
      }, { timestamp: 1789300000 }),
    ),
    {
      timestamp: "1789300000",
      membership_id: "mem_2",
      plan_id: "plan_yearly",
      app_user_id: USER_ID,
    },
  );
});

Deno.test("minimizeWhopPayload omits absent fields and never stores a non-UUID app_user_id", () => {
  assertEquals(
    minimizeWhopPayload(
      envelope("payment.succeeded", { metadata: { app_user_id: "buyer@example.com" } }, {
        timestamp: undefined,
      }),
    ),
    {},
  );
});

Deno.test("minimizeWhopPayload caps every stored value so the row stays tiny", () => {
  const minimized = minimizeWhopPayload(
    envelope("membership.activated", { id: "m".repeat(5000), status: "s".repeat(5000) }),
  );
  assertEquals(minimized.membership_id?.length, 128);
  assertEquals(minimized.status?.length, 128);
});
