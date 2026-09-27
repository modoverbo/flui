import { assertEquals } from "jsr:@std/assert@1.0.19";
import { createSpeechAnalyzeHandler, type SpeechAnalyzeDeps } from "./handler.ts";

const ORIGIN = "http://localhost:3000";

function setup(overrides: Partial<SpeechAnalyzeDeps> = {}) {
  const calls: Array<{ bytes: Uint8Array; mimeType: string }> = [];
  const hasAccessCalls: string[] = [];
  const evaluateCalls: string[] = [];
  const deps: SpeechAnalyzeDeps = {
    allowedOrigins: [ORIGIN],
    getUserId: (token) => Promise.resolve(token === "valid-jwt" ? "u1" : null),
    hasAccess: (userId) => {
      hasAccessCalls.push(userId);
      return Promise.resolve(true);
    },
    claimDailyAnalysis: () => Promise.resolve(true),
    transcribe: (bytes, mimeType) => {
      calls.push({ bytes, mimeType });
      return Promise.resolve({
        text: "Una idea clara",
        durationSeconds: 1.2,
        words: [
          { text: "Una", start: 0, end: 0.2 },
          { text: "idea", start: 0.3, end: 0.6 },
          { text: "clara", start: 0.7, end: 1 },
        ],
      });
    },
    evaluate: (text) => {
      evaluateCalls.push(text);
      return Promise.resolve({
        summary: "Explica una decisión y su resultado.",
        structure: "Idea clara; falta un cierre.",
        vocabulary: "Vocabulario concreto pero poco variado.",
        strength: "Conecta la acción con su beneficio.",
        retryCue: "Cierra con una frase que resuma el aprendizaje.",
      });
    },
    ...overrides,
  };
  return { handler: createSpeechAnalyzeHandler(deps), calls, hasAccessCalls, evaluateCalls };
}

function post(body: unknown, authorization = "Bearer valid-jwt") {
  return new Request("http://localhost/functions/v1/speech-analyze", {
    method: "POST",
    headers: {
      Origin: ORIGIN,
      Authorization: authorization,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function validBody() {
  return {
    audioBase64: btoa(String.fromCharCode(1, 2, 3)),
    mimeType: "audio/wav",
    durationMs: 1200,
  };
}

Deno.test("rejects unauthenticated speech requests", async () => {
  const { handler, calls, hasAccessCalls } = setup();
  const response = await handler(post(validBody(), ""));
  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
  assertEquals(hasAccessCalls.length, 0);
});

Deno.test("denies analysis for an authenticated user without access", async () => {
  const { handler, calls, evaluateCalls } = setup({
    hasAccess: () => Promise.resolve(false),
  });
  const response = await handler(post(validBody()));
  assertEquals(response.status, 403);
  assertEquals((await response.json()).error.code, "access_required");
  assertEquals(calls.length, 0);
  assertEquals(evaluateCalls.length, 0);
});

Deno.test("fails closed with 503 when the access check is unavailable", async () => {
  const { handler, calls, evaluateCalls } = setup({
    hasAccess: () => Promise.reject(new Error("db unreachable")),
  });
  const response = await handler(post(validBody()));
  assertEquals(response.status, 503);
  assertEquals((await response.json()).error.code, "access_unavailable");
  assertEquals(calls.length, 0);
  assertEquals(evaluateCalls.length, 0);
});

Deno.test("rejects unsupported audio and invalid duration", async () => {
  const { handler, calls } = setup();
  const badType = await handler(post({ ...validBody(), mimeType: "text/plain" }));
  const tooLong = await handler(post({ ...validBody(), durationMs: 61000 }));
  assertEquals(badType.status, 400);
  assertEquals(tooLong.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test("returns transcript and semantic coaching grounded in it", async () => {
  const { handler, calls } = setup();
  const response = await handler(post(validBody()));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    text: "Una idea clara",
    durationMs: 1200,
    words: [
      { text: "Una", start: 0, end: 0.2 },
      { text: "idea", start: 0.3, end: 0.6 },
      { text: "clara", start: 0.7, end: 1 },
    ],
    analysis: {
      summary: "Explica una decisión y su resultado.",
      structure: "Idea clara; falta un cierre.",
      vocabulary: "Vocabulario concreto pero poco variado.",
      strength: "Conecta la acción con su beneficio.",
      retryCue: "Cierra con una frase que resuma el aprendizaje.",
    },
  });
  assertEquals([...calls[0].bytes], [1, 2, 3]);
  assertEquals(calls[0].mimeType, "audio/wav");
});

Deno.test("maps provider rate limits and failures without leaking details", async () => {
  const rateLimited = setup({
    transcribe: () => Promise.reject(new Response(null, { status: 429 })),
  });
  const failed = setup({
    transcribe: () => Promise.reject(new Error("secret provider detail")),
  });
  assertEquals((await rateLimited.handler(post(validBody()))).status, 429);
  const response = await failed.handler(post(validBody()));
  assertEquals(response.status, 502);
  assertEquals(JSON.stringify(await response.json()).includes("secret"), false);
});

Deno.test("rejects payloads larger than five megabytes", async () => {
  const { handler, calls } = setup();
  const response = await handler(post({
    ...validBody(),
    audioBase64: "A".repeat(7_000_000),
  }));
  assertEquals(response.status, 413);
  assertEquals(calls.length, 0);
});

Deno.test("claims a daily quota unit before calling the provider", async () => {
  const quotaCalls: string[] = [];
  const { handler, calls } = setup({
    claimDailyAnalysis: (userId) => {
      quotaCalls.push(userId);
      return Promise.resolve(true);
    },
  });
  const response = await handler(post(validBody()));
  assertEquals(response.status, 200);
  assertEquals(quotaCalls, ["u1"]);
  assertEquals(calls.length, 1);
});

Deno.test("denies analysis with 429 daily_limit_reached once the quota is exhausted, no provider call", async () => {
  const { handler, calls, evaluateCalls } = setup({
    claimDailyAnalysis: () => Promise.resolve(false),
  });
  const response = await handler(post(validBody()));
  assertEquals(response.status, 429);
  assertEquals((await response.json()).error.code, "daily_limit_reached");
  assertEquals(calls.length, 0);
  assertEquals(evaluateCalls.length, 0);
});

Deno.test("fails closed with 503 when the quota check is unavailable, no provider call", async () => {
  const { handler, calls, evaluateCalls } = setup({
    claimDailyAnalysis: () => Promise.reject(new Error("db unreachable")),
  });
  const response = await handler(post(validBody()));
  assertEquals(response.status, 503);
  assertEquals((await response.json()).error.code, "access_unavailable");
  assertEquals(calls.length, 0);
  assertEquals(evaluateCalls.length, 0);
});

Deno.test("never claims quota for an unauthenticated or access-denied request", async () => {
  const noAuthQuota: string[] = [];
  const noAuth = setup({
    claimDailyAnalysis: (userId) => {
      noAuthQuota.push(userId);
      return Promise.resolve(true);
    },
  });
  await noAuth.handler(post(validBody(), ""));
  assertEquals(noAuthQuota.length, 0);

  const noAccessQuota: string[] = [];
  const noAccess = setup({
    hasAccess: () => Promise.resolve(false),
    claimDailyAnalysis: (userId) => {
      noAccessQuota.push(userId);
      return Promise.resolve(true);
    },
  });
  await noAccess.handler(post(validBody()));
  assertEquals(noAccessQuota.length, 0);
});

Deno.test("never claims quota for a malformed body (invalid audio)", async () => {
  const quotaCalls: string[] = [];
  const { handler } = setup({
    claimDailyAnalysis: (userId) => {
      quotaCalls.push(userId);
      return Promise.resolve(true);
    },
  });
  const response = await handler(post({ ...validBody(), mimeType: "text/plain" }));
  assertEquals(response.status, 400);
  assertEquals(quotaCalls.length, 0);
});
