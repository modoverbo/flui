import { assertEquals } from "jsr:@std/assert@1.0.19";
import { bearerToken, errorResponse, HttpError, jsonResponse } from "./http.ts";

Deno.test("jsonResponse serializes the body with a JSON content type and extra headers", async () => {
  const response = jsonResponse(201, { ok: true }, { "X-Test": "1" });
  assertEquals(response.status, 201);
  assertEquals(response.headers.get("Content-Type"), "application/json; charset=utf-8");
  assertEquals(response.headers.get("X-Test"), "1");
  assertEquals(await response.json(), { ok: true });
});

Deno.test("errorResponse uses the typed error envelope", async () => {
  const response = errorResponse(new HttpError(404, "unknown_plan", "Plan not found."));
  assertEquals(response.status, 404);
  assertEquals(await response.json(), {
    error: { code: "unknown_plan", message: "Plan not found." },
  });
});

Deno.test("bearerToken extracts the token from an Authorization header", () => {
  assertEquals(bearerToken("Bearer abc.def.ghi"), "abc.def.ghi");
  assertEquals(bearerToken("bearer   abc"), "abc");
});

Deno.test("bearerToken rejects missing or malformed headers", () => {
  assertEquals(bearerToken(null), null);
  assertEquals(bearerToken(""), null);
  assertEquals(bearerToken("Basic abc"), null);
  assertEquals(bearerToken("Bearer "), null);
});
