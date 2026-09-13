import { assertEquals } from "jsr:@std/assert@1.0.19";
import type { WhopCheckoutConfigurationRequest } from "../_shared/checkout.ts";
import { type CheckoutDeps, createCheckoutHandler } from "./handler.ts";

const USER_ID = "5b7f6a3e-2d1c-4b9a-8f0e-1a2b3c4d5e6f";
const ORIGIN = "http://localhost:3000";

function setup(overrides: Partial<CheckoutDeps> = {}) {
  const calls: WhopCheckoutConfigurationRequest[] = [];
  const deps: CheckoutDeps = {
    allowedOrigins: [ORIGIN],
    appUrl: "http://localhost:3000",
    getUserId: (token) => Promise.resolve(token === "valid-jwt" ? USER_ID : null),
    hasAccess: () => Promise.resolve(false),
    findActivePlan: (planId) =>
      Promise.resolve(planId === "monthly" ? { id: "monthly", whopPlanId: "plan_monthly" } : null),
    createCheckoutConfiguration: (body) => {
      calls.push(body);
      return Promise.resolve({ id: "ch_1", purchaseUrl: "https://whop.com/checkout/ch_1/" });
    },
    ...overrides,
  };
  return { handler: createCheckoutHandler(deps), calls };
}

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request("http://localhost/functions/v1/whop-checkout", {
    method: "POST",
    headers: {
      Origin: ORIGIN,
      Authorization: "Bearer valid-jwt",
      "Content-Type": "application/json",
      ...headers,
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error.code;
}

Deno.test("OPTIONS preflight from an allowed origin returns 204 with CORS headers", async () => {
  const { handler } = setup();
  const response = await handler(
    new Request("http://localhost", { method: "OPTIONS", headers: { Origin: ORIGIN } }),
  );
  assertEquals(response.status, 204);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), ORIGIN);
});

Deno.test("OPTIONS preflight from a foreign origin returns 403", async () => {
  const { handler } = setup();
  const response = await handler(
    new Request("http://localhost", {
      method: "OPTIONS",
      headers: { Origin: "https://evil.example" },
    }),
  );
  assertEquals(response.status, 403);
  await response.body?.cancel();
});

Deno.test("methods other than POST return 405", async () => {
  const { handler } = setup();
  const response = await handler(
    new Request("http://localhost", { method: "GET", headers: { Origin: ORIGIN } }),
  );
  assertEquals(response.status, 405);
  assertEquals(await errorCode(response), "method_not_allowed");
});

Deno.test("requests from a foreign origin return 403 origin_not_allowed", async () => {
  const { handler, calls } = setup();
  const response = await handler(post({ planId: "monthly" }, { Origin: "https://evil.example" }));
  assertEquals(response.status, 403);
  assertEquals(await errorCode(response), "origin_not_allowed");
  assertEquals(calls.length, 0);
});

Deno.test("missing or invalid tokens return 401 unauthorized", async () => {
  const { handler } = setup();
  const missing = await handler(post({ planId: "monthly" }, { Authorization: "" }));
  const invalid = await handler(post({ planId: "monthly" }, { Authorization: "Bearer forged" }));
  assertEquals([missing.status, await errorCode(missing)], [401, "unauthorized"]);
  assertEquals([invalid.status, await errorCode(invalid)], [401, "unauthorized"]);
});

Deno.test("malformed JSON or plan ids return 400 invalid_body", async () => {
  const { handler } = setup();
  for (const body of ["{not json", { plan: "monthly" }]) {
    const response = await handler(post(body));
    assertEquals([response.status, await errorCode(response)], [400, "invalid_body"]);
  }
});

Deno.test("unknown or inactive plans return 404 unknown_plan", async () => {
  const { handler } = setup();
  const response = await handler(post({ planId: "lifetime" }));
  assertEquals([response.status, await errorCode(response)], [404, "unknown_plan"]);
});

Deno.test("users who already have access get 409 already_subscribed", async () => {
  const { handler, calls } = setup({ hasAccess: () => Promise.resolve(true) });
  const response = await handler(post({ planId: "monthly" }));
  assertEquals([response.status, await errorCode(response)], [409, "already_subscribed"]);
  assertEquals(calls.length, 0);
});

Deno.test("a valid request creates a Whop checkout linked to the user and returns purchaseUrl", async () => {
  const { handler, calls } = setup();
  const response = await handler(post({ planId: "monthly" }));
  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), ORIGIN);
  assertEquals(await response.json(), { purchaseUrl: "https://whop.com/checkout/ch_1/" });
  assertEquals(calls, [{
    plan_id: "plan_monthly",
    metadata: { app_user_id: USER_ID },
    redirect_url: "http://localhost:3000/checkout/return",
  }]);
});

Deno.test("requests without an Origin header (non-browser clients) are allowed", async () => {
  const { handler } = setup();
  const request = post({ planId: "monthly" });
  request.headers.delete("Origin");
  const response = await handler(request);
  assertEquals(response.status, 200);
  await response.body?.cancel();
});

Deno.test("Whop failures return 502 upstream_error", async () => {
  const { handler } = setup({
    createCheckoutConfiguration: () => Promise.reject(new Error("boom")),
  });
  const response = await handler(post({ planId: "monthly" }));
  assertEquals([response.status, await errorCode(response)], [502, "upstream_error"]);
});

Deno.test("unexpected dependency failures return 500 internal_error", async () => {
  const { handler } = setup({ findActivePlan: () => Promise.reject(new Error("db down")) });
  const response = await handler(post({ planId: "monthly" }));
  assertEquals([response.status, await errorCode(response)], [500, "internal_error"]);
});
