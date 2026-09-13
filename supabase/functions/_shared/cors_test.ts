import { assertEquals } from "jsr:@std/assert@1.0.19";
import { corsHeaders, isOriginAllowed, parseAllowedOrigins, preflightResponse } from "./cors.ts";

const ALLOWED = ["https://app.flui.example", "http://localhost:3000"];

Deno.test("parseAllowedOrigins splits, trims and drops empty entries and trailing slashes", () => {
  assertEquals(
    parseAllowedOrigins(" https://app.flui.example/ , http://localhost:3000,, "),
    ALLOWED,
  );
});

Deno.test("parseAllowedOrigins returns an empty list when the variable is missing", () => {
  assertEquals(parseAllowedOrigins(undefined), []);
});

Deno.test("isOriginAllowed only accepts exact matches from the list", () => {
  assertEquals(isOriginAllowed("http://localhost:3000", ALLOWED), true);
  assertEquals(isOriginAllowed("http://localhost:3001", ALLOWED), false);
  assertEquals(isOriginAllowed("https://app.flui.example.evil.com", ALLOWED), false);
  assertEquals(isOriginAllowed(null, ALLOWED), false);
});

Deno.test("isOriginAllowed never treats * as a wildcard", () => {
  assertEquals(isOriginAllowed("https://anyone.example", ["*"]), false);
});

Deno.test("corsHeaders echoes an allowed origin with the headers supabase-js sends", () => {
  const headers = corsHeaders("http://localhost:3000", ALLOWED);
  assertEquals(headers["Access-Control-Allow-Origin"], "http://localhost:3000");
  assertEquals(headers["Access-Control-Allow-Methods"], "POST, OPTIONS");
  assertEquals(
    headers["Access-Control-Allow-Headers"],
    "authorization, x-client-info, apikey, content-type",
  );
  assertEquals(headers["Vary"], "Origin");
});

Deno.test("corsHeaders omits Access-Control-Allow-Origin for other origins", () => {
  const headers = corsHeaders("https://evil.example", ALLOWED);
  assertEquals(headers["Access-Control-Allow-Origin"], undefined);
  assertEquals(headers["Vary"], "Origin");
});

Deno.test("preflightResponse answers 204 for an allowed origin", async () => {
  const response = preflightResponse(
    new Request("https://fn.example", {
      method: "OPTIONS",
      headers: { Origin: "https://app.flui.example" },
    }),
    ALLOWED,
  );
  assertEquals(response.status, 204);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "https://app.flui.example");
  assertEquals(await response.text(), "");
});

Deno.test("preflightResponse answers 403 for a foreign origin", async () => {
  const response = preflightResponse(
    new Request("https://fn.example", {
      method: "OPTIONS",
      headers: { Origin: "https://evil.example" },
    }),
    ALLOWED,
  );
  assertEquals(response.status, 403);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), null);
  await response.body?.cancel();
});
