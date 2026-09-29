import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1.0.19";
import { cancelMembership, CancelMembershipError } from "./whop_membership.ts";

const MEMBERSHIP_ID = "mem_abc123";
const SECRET_API_KEY = "sk_super_secret_test_key_do_not_leak";
const BASE_URL = "https://sandbox-api.whop.com/api/v1";

function client(fetchImpl: typeof fetch) {
  return { fetch: fetchImpl, baseUrl: BASE_URL, apiKey: SECRET_API_KEY };
}

function membershipResponse(
  body: { status: string; cancel_at_period_end: boolean },
  status = 200,
) {
  return Promise.resolve(Response.json(body, { status }));
}

Deno.test("cancelMembership rejects a malformed membershipId before any network call", async () => {
  let called = false;
  const fetchImpl = () => {
    called = true;
    return membershipResponse({ status: "canceled", cancel_at_period_end: true });
  };
  for (
    const bad of [
      "",
      "abc123",
      "mem_",
      "membership_abc123",
      undefined as unknown as string,
      123 as unknown as string,
    ]
  ) {
    const error = await assertRejects(
      () => cancelMembership(client(fetchImpl), bad),
      CancelMembershipError,
    );
    assertEquals(error.reason, "invalid_membership_id");
    assertEquals(error.status, undefined);
  }
  assertEquals(called, false);
});

Deno.test("cancelMembership sends POST .../memberships/{id}/cancel with auth, idempotency and body", async () => {
  let captured: Request | undefined;
  const fetchImpl = (input: Request | URL | string, init?: RequestInit) => {
    captured = new Request(input, init);
    return membershipResponse({ status: "active", cancel_at_period_end: true });
  };

  const result = await cancelMembership(client(fetchImpl), MEMBERSHIP_ID);

  assertEquals(result, { outcome: "canceled", status: "active", cancelAtPeriodEnd: true });
  assertEquals(captured?.method, "POST");
  assertEquals(
    captured?.url,
    "https://sandbox-api.whop.com/api/v1/memberships/mem_abc123/cancel",
  );
  assertEquals(captured?.headers.get("Authorization"), `Bearer ${SECRET_API_KEY}`);
  assertEquals(captured?.headers.get("Content-Type"), "application/json");
  assertEquals(captured?.headers.get("Idempotency-Key"), "flui-account-delete-mem_abc123");
  assertEquals(await captured?.json(), { cancel_at_period_end: true });
});

Deno.test("cancelMembership URL-encodes the membership id in the path", async () => {
  let captured: Request | undefined;
  const fetchImpl = (input: Request | URL | string, init?: RequestInit) => {
    captured = new Request(input, init);
    return membershipResponse({ status: "canceled", cancel_at_period_end: true });
  };

  await cancelMembership(client(fetchImpl), "mem_weird id/slash");

  assertEquals(
    captured?.url,
    "https://sandbox-api.whop.com/api/v1/memberships/mem_weird%20id%2Fslash/cancel",
  );
});

Deno.test("cancelMembership forwards an explicit reason in the body", async () => {
  let captured: Request | undefined;
  const fetchImpl = (input: Request | URL | string, init?: RequestInit) => {
    captured = new Request(input, init);
    return membershipResponse({ status: "canceled", cancel_at_period_end: true });
  };

  await cancelMembership(client(fetchImpl), MEMBERSHIP_ID, { reason: "account deletion" });

  assertEquals(await captured?.json(), {
    cancel_at_period_end: true,
    reason: "account deletion",
  });
});

Deno.test("cancelMembership uses a caller-supplied Idempotency-Key, truncated to 255 chars", async () => {
  let captured: Request | undefined;
  const fetchImpl = (input: Request | URL | string, init?: RequestInit) => {
    captured = new Request(input, init);
    return membershipResponse({ status: "canceled", cancel_at_period_end: true });
  };
  const longKey = "x".repeat(300);

  await cancelMembership(client(fetchImpl), MEMBERSHIP_ID, { idempotencyKey: longKey });

  const sentKey = captured?.headers.get("Idempotency-Key");
  assertEquals(sentKey?.length, 255);
  assertEquals(sentKey, "x".repeat(255));
});

Deno.test("cancelMembership resolves canceled when cancel_at_period_end is true regardless of status", async () => {
  const fetchImpl = () => membershipResponse({ status: "active", cancel_at_period_end: true });
  const result = await cancelMembership(client(fetchImpl), MEMBERSHIP_ID);
  assertEquals(result, { outcome: "canceled", status: "active", cancelAtPeriodEnd: true });
});

Deno.test("cancelMembership resolves canceled when status is terminal even if cancel_at_period_end is false", async () => {
  for (const status of ["canceled", "expired", "completed"] as const) {
    const fetchImpl = () => membershipResponse({ status, cancel_at_period_end: false });
    const result = await cancelMembership(client(fetchImpl), MEMBERSHIP_ID);
    assertEquals(result, { outcome: "canceled", status, cancelAtPeriodEnd: false });
  }
});

Deno.test("cancelMembership rejects a 200 response that is neither cancel_at_period_end nor terminal", async () => {
  for (const status of ["trialing", "active", "past_due", "unresolved"]) {
    const fetchImpl = () => membershipResponse({ status, cancel_at_period_end: false });
    const error = await assertRejects(
      () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
      CancelMembershipError,
    );
    assertEquals(error.reason, "unexpected_response");
    assertEquals(error.status, 200);
    assertEquals(error.message.includes(SECRET_API_KEY), false);
  }
});

Deno.test("cancelMembership rejects a 200 response with a malformed membership payload", async () => {
  const fetchImpl = () => Promise.resolve(Response.json({ id: "mem_abc123" }, { status: 200 }));
  const error = await assertRejects(
    () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
    CancelMembershipError,
  );
  assertEquals(error.reason, "unexpected_response");
  assertEquals(error.status, 200);
});

Deno.test("cancelMembership resolves alreadyGone on 404, never guessing success", async () => {
  const fetchImpl = () => Promise.resolve(Response.json({ error: "not_found" }, { status: 404 }));
  const result = await cancelMembership(client(fetchImpl), MEMBERSHIP_ID);
  assertEquals(result, { outcome: "alreadyGone" });
});

Deno.test("cancelMembership on 409 follows up with GET and resolves alreadyCanceled when already terminal", async () => {
  const calls: Array<{ method: string | undefined; url: string }> = [];
  const fetchImpl = (input: Request | URL | string, init?: RequestInit) => {
    const request = new Request(input, init);
    calls.push({ method: request.method, url: request.url });
    if (calls.length === 1) {
      return Promise.resolve(Response.json({ error: "conflict" }, { status: 409 }));
    }
    return membershipResponse({ status: "canceled", cancel_at_period_end: true });
  };

  const result = await cancelMembership(client(fetchImpl), MEMBERSHIP_ID);

  assertEquals(result, { outcome: "alreadyCanceled", status: "canceled", cancelAtPeriodEnd: true });
  assertEquals(calls[0].method, "POST");
  assertEquals(calls[1].method, "GET");
  assertEquals(calls[1].url, "https://sandbox-api.whop.com/api/v1/memberships/mem_abc123");
});

Deno.test("cancelMembership on 409 resolves alreadyCanceled when the GET shows cancel_at_period_end true", async () => {
  let call = 0;
  const fetchImpl = () => {
    call += 1;
    if (call === 1) return Promise.resolve(Response.json({ error: "conflict" }, { status: 409 }));
    return membershipResponse({ status: "active", cancel_at_period_end: true });
  };
  const result = await cancelMembership(client(fetchImpl), MEMBERSHIP_ID);
  assertEquals(result, {
    outcome: "alreadyCanceled",
    status: "active",
    cancelAtPeriodEnd: true,
  });
});

Deno.test("cancelMembership on 409 rejects when the follow-up GET shows the membership is still active", async () => {
  let call = 0;
  const fetchImpl = () => {
    call += 1;
    if (call === 1) return Promise.resolve(Response.json({ error: "conflict" }, { status: 409 }));
    return membershipResponse({ status: "active", cancel_at_period_end: false });
  };
  const error = await assertRejects(
    () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
    CancelMembershipError,
  );
  assertEquals(error.reason, "unresolved_conflict");
});

Deno.test("cancelMembership on 409 rejects when the follow-up GET itself fails", async () => {
  let call = 0;
  const fetchImpl = () => {
    call += 1;
    if (call === 1) return Promise.resolve(Response.json({ error: "conflict" }, { status: 409 }));
    return Promise.resolve(Response.json({ error: "server_error" }, { status: 500 }));
  };
  const error = await assertRejects(
    () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
    CancelMembershipError,
  );
  assertEquals(error.reason, "unresolved_conflict");
  assertEquals(error.status, 500);
});

Deno.test("cancelMembership on 409 rejects when the follow-up GET payload is malformed", async () => {
  let call = 0;
  const fetchImpl = () => {
    call += 1;
    if (call === 1) return Promise.resolve(Response.json({ error: "conflict" }, { status: 409 }));
    return Promise.resolve(Response.json({}, { status: 200 }));
  };
  const error = await assertRejects(
    () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
    CancelMembershipError,
  );
  assertEquals(error.reason, "unresolved_conflict");
});

Deno.test("cancelMembership rejects 401/403 with a typed error carrying the status, no key leak", async () => {
  for (const status of [401, 403]) {
    const fetchImpl = () =>
      Promise.resolve(Response.json({ error: `denied ${SECRET_API_KEY}` }, { status }));
    const error = await assertRejects(
      () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
      CancelMembershipError,
    );
    assertEquals(error.reason, "http_error");
    assertEquals(error.status, status);
    assertEquals(error.message.includes(SECRET_API_KEY), false);
  }
});

Deno.test("cancelMembership rejects any other non-2xx with a typed error carrying the status", async () => {
  const fetchImpl = () => Promise.resolve(Response.json({ error: "boom" }, { status: 500 }));
  const error = await assertRejects(
    () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
    CancelMembershipError,
  );
  assertEquals(error.reason, "http_error");
  assertEquals(error.status, 500);
});

Deno.test("cancelMembership rejects a network failure without leaking the API key", async () => {
  const fetchImpl = () => Promise.reject(new TypeError("network down"));
  const error = await assertRejects(
    () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
    CancelMembershipError,
  );
  assertEquals(error.reason, "network_error");
  assertEquals(error.status, undefined);
  assertEquals(error.message.includes(SECRET_API_KEY), false);
});

Deno.test("cancelMembership rejects a timeout distinctly from a plain network error", async () => {
  const fetchImpl = () => Promise.reject(new DOMException("The signal timed out", "TimeoutError"));
  const error = await assertRejects(
    () => cancelMembership(client(fetchImpl), MEMBERSHIP_ID),
    CancelMembershipError,
  );
  assertEquals(error.reason, "timeout");
  assertEquals(error.status, undefined);
});

Deno.test("CancelMembershipError carries reason, status and message as a real Error", () => {
  const error = new CancelMembershipError("http_error", 403, "denied");
  assertEquals(error instanceof Error, true);
  assertEquals(error.name, "CancelMembershipError");
  assertEquals(error.reason, "http_error");
  assertEquals(error.status, 403);
  assertEquals(error.message, "denied");
});

Deno.test("CancelMembershipError is a distinct constructible type", () => {
  assertThrows(
    () => {
      throw new CancelMembershipError("network_error", undefined, "unreachable");
    },
    CancelMembershipError,
  );
});
