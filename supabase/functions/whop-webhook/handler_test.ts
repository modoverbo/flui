import { assertEquals } from "jsr:@std/assert@1.0.19";
import { signWebhook } from "../_shared/standard_webhooks.ts";
import type { EntitlementRow, StoredEntitlement } from "../_shared/whop_events.ts";
import { createWebhookHandler, type WebhookRepository } from "./handler.ts";

const SECRET = "ws_test_secret_value";
const USER_ID = "5b7f6a3e-2d1c-4b9a-8f0e-1a2b3c4d5e6f";
const NOW = new Date("2026-09-13T12:00:00Z");

class FakeRepository implements WebhookRepository {
  events = new Map<string, { eventType: string; processed: boolean }>();
  entitlements = new Map<string, StoredEntitlement>();
  saveResult: "saved" | "unknown_user" | "membership_conflict" = "saved";
  failOnSave = false;

  recordEvent(event: { webhookId: string; eventType: string; payload: unknown }) {
    const existing = this.events.get(event.webhookId);
    if (existing) {
      return Promise.resolve(existing.processed ? "processed" as const : "pending" as const);
    }
    this.events.set(event.webhookId, { eventType: event.eventType, processed: false });
    return Promise.resolve("new" as const);
  }
  markProcessed(webhookId: string) {
    const event = this.events.get(webhookId);
    if (event) event.processed = true;
    return Promise.resolve();
  }
  getEntitlement(userId: string) {
    return Promise.resolve(this.entitlements.get(userId) ?? null);
  }
  saveEntitlement(row: EntitlementRow) {
    if (this.failOnSave) return Promise.reject(new Error("db down"));
    if (this.saveResult === "saved") this.entitlements.set(row.user_id, row);
    return Promise.resolve(this.saveResult);
  }
}

function membershipEvent(
  type: string,
  data: Record<string, unknown> = {},
  extra: Record<string, unknown> = {},
) {
  return {
    id: "msg_1",
    type,
    api_version: "v1",
    timestamp: "2026-09-13T11:59:00Z",
    data: {
      id: "mem_1",
      status: "trialing",
      plan: { id: "plan_monthly" },
      metadata: { app_user_id: USER_ID },
      renewal_period_end: "2026-09-20T11:59:00Z",
      cancel_at_period_end: false,
      ...data,
    },
    ...extra,
  };
}

async function signedRequest(
  payload: unknown,
  webhookId = "msg_1",
  secret = SECRET,
): Promise<Request> {
  const body = typeof payload === "string" ? payload : JSON.stringify(payload);
  const timestamp = Math.floor(NOW.getTime() / 1000);
  return new Request("http://localhost/functions/v1/whop-webhook", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "webhook-id": webhookId,
      "webhook-timestamp": String(timestamp),
      "webhook-signature": await signWebhook(secret, webhookId, timestamp, body),
    },
    body,
  });
}

function handlerWith(repository: FakeRepository, companyId?: string) {
  return createWebhookHandler({
    secret: SECRET,
    companyId,
    repository,
    now: () => NOW,
    log: () => {},
  });
}

Deno.test("non-POST requests return 405", async () => {
  const response = await handlerWith(new FakeRepository())(
    new Request("http://localhost", { method: "GET" }),
  );
  assertEquals(response.status, 405);
  await response.body?.cancel();
});

Deno.test("an invalid signature returns 401 and records nothing", async () => {
  const repository = new FakeRepository();
  const response = await handlerWith(repository)(
    await signedRequest(membershipEvent("membership.activated"), "msg_1", "ws_wrong"),
  );
  assertEquals(response.status, 401);
  assertEquals((await response.json()).error.code, "invalid_signature");
  assertEquals(repository.events.size, 0);
});

Deno.test("a signed but malformed payload returns 400", async () => {
  const repository = new FakeRepository();
  const response = await handlerWith(repository)(await signedRequest("{nope"));
  assertEquals(response.status, 400);
  assertEquals((await response.json()).error.code, "invalid_payload");
});

Deno.test("membership.activated for a trial creates a trialing entitlement and marks the event processed", async () => {
  const repository = new FakeRepository();
  const response = await handlerWith(repository)(
    await signedRequest(membershipEvent("membership.activated")),
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { status: "applied" });
  assertEquals(repository.entitlements.get(USER_ID)?.status, "trialing");
  assertEquals(repository.entitlements.get(USER_ID)?.trial_ends_at, "2026-09-20T11:59:00.000Z");
  assertEquals(repository.events.get("msg_1"), {
    eventType: "membership.activated",
    processed: true,
  });
});

Deno.test("membership.deactivated revokes access", async () => {
  const repository = new FakeRepository();
  const handler = handlerWith(repository);
  await (await handler(await signedRequest(membershipEvent("membership.activated"), "msg_1"))).body
    ?.cancel();
  const response = await handler(
    await signedRequest(
      membershipEvent("membership.deactivated", { status: "canceled" }, {
        timestamp: "2026-09-13T11:59:30Z",
      }),
      "msg_2",
    ),
  );
  assertEquals(await response.json(), { status: "applied" });
  assertEquals(repository.entitlements.get(USER_ID)?.status, "canceled");
});

Deno.test("a webhook that was already processed is acknowledged without side effects", async () => {
  const repository = new FakeRepository();
  repository.events.set("msg_1", { eventType: "membership.activated", processed: true });
  const response = await handlerWith(repository)(
    await signedRequest(membershipEvent("membership.activated")),
  );
  assertEquals(await response.json(), { status: "duplicate" });
  assertEquals(repository.entitlements.size, 0);
});

Deno.test("a webhook recorded but not processed (earlier failure) is processed on retry", async () => {
  const repository = new FakeRepository();
  repository.events.set("msg_1", { eventType: "membership.activated", processed: false });
  const response = await handlerWith(repository)(
    await signedRequest(membershipEvent("membership.activated")),
  );
  assertEquals(await response.json(), { status: "applied" });
  assertEquals(repository.entitlements.size, 1);
});

Deno.test("unknown and payment events are stored, acknowledged and ignored", async () => {
  const repository = new FakeRepository();
  const response = await handlerWith(repository)(
    await signedRequest({ id: "msg_1", type: "payment.succeeded", data: { id: "pay_1" } }),
  );
  assertEquals(await response.json(), { status: "ignored", reason: "not_a_membership_event" });
  assertEquals(repository.events.get("msg_1")?.processed, true);
});

Deno.test("stale events are acknowledged and skipped", async () => {
  const repository = new FakeRepository();
  repository.entitlements.set(USER_ID, {
    user_id: USER_ID,
    whop_membership_id: "mem_1",
    whop_plan_id: "plan_monthly",
    status: "active",
    current_period_end: "2026-10-20T00:00:00.000Z",
    trial_ends_at: null,
    cancel_at_period_end: false,
    last_event_at: "2026-09-14T00:00:00.000Z",
  });
  const response = await handlerWith(repository)(
    await signedRequest(membershipEvent("membership.deactivated")),
  );
  assertEquals(await response.json(), { status: "skipped", reason: "stale_event" });
  assertEquals(repository.entitlements.get(USER_ID)?.status, "active");
});

Deno.test("events from another Whop company are ignored", async () => {
  const repository = new FakeRepository();
  const response = await handlerWith(repository, "biz_flui")(
    await signedRequest(membershipEvent("membership.activated", {}, { account_id: "biz_other" })),
  );
  assertEquals(await response.json(), { status: "ignored", reason: "foreign_account" });
  assertEquals(repository.entitlements.size, 0);
});

Deno.test("entitlements for unknown users are acknowledged and ignored", async () => {
  const repository = new FakeRepository();
  repository.saveResult = "unknown_user";
  const response = await handlerWith(repository)(
    await signedRequest(membershipEvent("membership.activated")),
  );
  assertEquals(await response.json(), { status: "ignored", reason: "unknown_user" });
  assertEquals(repository.events.get("msg_1")?.processed, true);
});

Deno.test("database failures return 500 so Whop retries, and the event stays pending", async () => {
  const repository = new FakeRepository();
  repository.failOnSave = true;
  const response = await handlerWith(repository)(
    await signedRequest(membershipEvent("membership.activated")),
  );
  assertEquals(response.status, 500);
  assertEquals((await response.json()).error.code, "internal_error");
  assertEquals(repository.events.get("msg_1")?.processed, false);
});
