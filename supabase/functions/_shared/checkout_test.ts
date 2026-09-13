import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1.0.19";
import {
  buildCheckoutConfigurationRequest,
  createWhopCheckoutConfiguration,
  normalizePurchaseUrl,
  parseCheckoutRequest,
} from "./checkout.ts";
import { HttpError } from "./http.ts";

const USER_ID = "5b7f6a3e-2d1c-4b9a-8f0e-1a2b3c4d5e6f";

Deno.test("parseCheckoutRequest accepts a plan id", () => {
  assertEquals(parseCheckoutRequest({ planId: "monthly" }), { planId: "monthly" });
  assertEquals(parseCheckoutRequest({ planId: "quarterly" }), { planId: "quarterly" });
});

Deno.test("parseCheckoutRequest rejects malformed bodies with invalid_body", () => {
  for (
    const body of [null, [], "monthly", {}, { planId: 3 }, { planId: "" }, { planId: "Monthly!" }, {
      planId: "x".repeat(65),
    }]
  ) {
    const error = assertThrows(() => parseCheckoutRequest(body), HttpError);
    assertEquals(error.status, 400);
    assertEquals(error.code, "invalid_body");
  }
});

Deno.test("buildCheckoutConfigurationRequest links the checkout to the app user and return URL", () => {
  assertEquals(
    buildCheckoutConfigurationRequest({
      whopPlanId: "plan_abc",
      userId: USER_ID,
      appUrl: "https://app.flui.example/",
    }),
    {
      plan_id: "plan_abc",
      metadata: { app_user_id: USER_ID },
      redirect_url: "https://app.flui.example/checkout/return",
    },
  );
});

Deno.test("normalizePurchaseUrl keeps absolute URLs and resolves relative Whop paths", () => {
  assertEquals(
    normalizePurchaseUrl("https://whop.com/checkout/ch_1/"),
    "https://whop.com/checkout/ch_1/",
  );
  assertEquals(normalizePurchaseUrl("/checkout/ch_1/"), "https://whop.com/checkout/ch_1/");
});

Deno.test("normalizePurchaseUrl rejects non-https URLs", () => {
  assertThrows(() => normalizePurchaseUrl("javascript:alert(1)"), HttpError);
  assertThrows(() => normalizePurchaseUrl("http://whop.com/checkout/ch_1"), HttpError);
});

Deno.test("createWhopCheckoutConfiguration posts to /checkout_configurations with the API key", async () => {
  let captured: Request | undefined;
  const fakeFetch = (input: Request | URL | string, init?: RequestInit) => {
    captured = new Request(input, init);
    return Promise.resolve(
      Response.json({ id: "ch_123", purchase_url: "https://whop.com/checkout/ch_123/" }, {
        status: 201,
      }),
    );
  };
  const body = buildCheckoutConfigurationRequest({
    whopPlanId: "plan_abc",
    userId: USER_ID,
    appUrl: "http://localhost:3000",
  });

  const result = await createWhopCheckoutConfiguration(
    { fetch: fakeFetch, baseUrl: "https://sandbox-api.whop.com/api/v1/", apiKey: "test_key" },
    body,
  );

  assertEquals(result, { id: "ch_123", purchaseUrl: "https://whop.com/checkout/ch_123/" });
  assertEquals(captured?.method, "POST");
  assertEquals(captured?.url, "https://sandbox-api.whop.com/api/v1/checkout_configurations");
  assertEquals(captured?.headers.get("Authorization"), "Bearer test_key");
  assertEquals(captured?.headers.get("Content-Type"), "application/json");
  assertEquals(await captured?.json(), body);
});

Deno.test("createWhopCheckoutConfiguration maps Whop errors to upstream_error without leaking details", async () => {
  const fakeFetch = () =>
    Promise.resolve(Response.json({ error: { message: "bad key sk_live" } }, { status: 401 }));
  const error = await assertRejects(
    () =>
      createWhopCheckoutConfiguration(
        { fetch: fakeFetch, baseUrl: "https://api.whop.com/api/v1", apiKey: "k" },
        buildCheckoutConfigurationRequest({
          whopPlanId: "plan_abc",
          userId: USER_ID,
          appUrl: "http://localhost:3000",
        }),
      ),
    HttpError,
  );
  assertEquals(error.status, 502);
  assertEquals(error.code, "upstream_error");
  assertEquals(error.message.includes("sk_live"), false);
});

Deno.test("createWhopCheckoutConfiguration fails when Whop returns no purchase_url", async () => {
  const fakeFetch = () => Promise.resolve(Response.json({ id: "ch_1" }, { status: 200 }));
  const error = await assertRejects(
    () =>
      createWhopCheckoutConfiguration(
        { fetch: fakeFetch, baseUrl: "https://api.whop.com/api/v1", apiKey: "k" },
        buildCheckoutConfigurationRequest({
          whopPlanId: "plan_abc",
          userId: USER_ID,
          appUrl: "http://localhost:3000",
        }),
      ),
    HttpError,
  );
  assertEquals(error.code, "upstream_error");
});

Deno.test("createWhopCheckoutConfiguration maps network failures to upstream_error", async () => {
  const fakeFetch = () => Promise.reject(new TypeError("network down"));
  const error = await assertRejects(
    () =>
      createWhopCheckoutConfiguration(
        { fetch: fakeFetch, baseUrl: "https://api.whop.com/api/v1", apiKey: "k" },
        buildCheckoutConfigurationRequest({
          whopPlanId: "plan_abc",
          userId: USER_ID,
          appUrl: "http://localhost:3000",
        }),
      ),
    HttpError,
  );
  assertEquals(error.code, "upstream_error");
});
