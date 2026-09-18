import { assertEquals } from "jsr:@std/assert@1.0.19";
import { createSpeechAnalyzeHandler, type SpeechAnalyzeDeps } from "./handler.ts";

const ORIGIN = "http://localhost:3000";

function setup(overrides: Partial<SpeechAnalyzeDeps> = {}) {
  const calls: Array<{ bytes: Uint8Array; mimeType: string }> = [];
  const deps: SpeechAnalyzeDeps = {
    allowedOrigins: [ORIGIN],
    getUserId: (token) => Promise.resolve(token === "valid-jwt" ? "u1" : null),
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
    evaluate: () =>
      Promise.resolve({
        summary: "Explica una decisión y su resultado.",
        structure: "Idea clara; falta un cierre.",
        vocabulary: "Vocabulario concreto pero poco variado.",
        strength: "Conecta la acción con su beneficio.",
        retryCue: "Cierra con una frase que resuma el aprendizaje.",
      }),
    ...overrides,
  };
  return { handler: createSpeechAnalyzeHandler(deps), calls };
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
  const { handler, calls } = setup();
  const response = await handler(post(validBody(), ""));
  assertEquals(response.status, 401);
  assertEquals(calls.length, 0);
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
