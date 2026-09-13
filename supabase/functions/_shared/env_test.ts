import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.19";
import { DEFAULT_WHOP_API_BASE_URL, readCheckoutEnv, readWebhookEnv } from "./env.ts";

function source(values: Record<string, string>) {
  return (name: string) => values[name];
}

const BASE = {
  SUPABASE_URL: "http://127.0.0.1:54421",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-secret",
};

Deno.test("readCheckoutEnv reads required values and applies defaults", () => {
  assertEquals(
    readCheckoutEnv(
      source({ ...BASE, WHOP_API_KEY: "whop-secret", APP_URL: "http://localhost:3000" }),
    ),
    {
      supabaseUrl: "http://127.0.0.1:54421",
      serviceRoleKey: "service-role-secret",
      whopApiKey: "whop-secret",
      whopApiBaseUrl: DEFAULT_WHOP_API_BASE_URL,
      appUrl: "http://localhost:3000",
      allowedOrigins: ["http://localhost:3000"],
    },
  );
  assertEquals(DEFAULT_WHOP_API_BASE_URL, "https://api.whop.com/api/v1");
});

Deno.test("readCheckoutEnv honours WHOP_API_BASE_URL and ALLOWED_ORIGINS", () => {
  const env = readCheckoutEnv(source({
    ...BASE,
    WHOP_API_KEY: "k",
    APP_URL: "https://app.flui.example",
    WHOP_API_BASE_URL: "https://sandbox-api.whop.com/api/v1",
    ALLOWED_ORIGINS: "https://app.flui.example,http://localhost:3000",
  }));
  assertEquals(env.whopApiBaseUrl, "https://sandbox-api.whop.com/api/v1");
  assertEquals(env.allowedOrigins, ["https://app.flui.example", "http://localhost:3000"]);
});

Deno.test("readCheckoutEnv lists missing variable names without exposing values", () => {
  const error = assertThrows(() =>
    readCheckoutEnv(source({ SUPABASE_SERVICE_ROLE_KEY: "super-secret" }))
  );
  assertEquals(
    (error as Error).message,
    "Missing required environment variables: SUPABASE_URL, WHOP_API_KEY, APP_URL",
  );
});

Deno.test("readWebhookEnv reads the secret and the optional company id", () => {
  assertEquals(readWebhookEnv(source({ ...BASE, WHOP_WEBHOOK_SECRET: "ws_x" })), {
    supabaseUrl: "http://127.0.0.1:54421",
    serviceRoleKey: "service-role-secret",
    webhookSecret: "ws_x",
    whopCompanyId: undefined,
  });
  assertEquals(
    readWebhookEnv(source({ ...BASE, WHOP_WEBHOOK_SECRET: "ws_x", WHOP_COMPANY_ID: "biz_1" }))
      .whopCompanyId,
    "biz_1",
  );
});

Deno.test("readWebhookEnv requires WHOP_WEBHOOK_SECRET", () => {
  assertThrows(() => readWebhookEnv(source(BASE)), Error, "WHOP_WEBHOOK_SECRET");
});
