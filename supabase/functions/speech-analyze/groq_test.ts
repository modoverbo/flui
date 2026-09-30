import { assertEquals } from "jsr:@std/assert@1.0.19";
import { createGroqProvider } from "./groq.ts";

function stubFetch(body: unknown): { requests: Request[]; restore: () => void } {
  const original = globalThis.fetch;
  const requests: Request[] = [];
  globalThis.fetch = (input: RequestInfo | URL, init?: RequestInit) => {
    requests.push(new Request(input, init));
    return Promise.resolve(Response.json(body));
  };
  return { requests, restore: () => (globalThis.fetch = original) };
}

const coaching = {
  summary: "Contaste una decisión concreta.",
  structure: "Tiene inicio y cierre.",
  vocabulary: 'Usaste "enfocado".',
  strength: "El punto principal es claro.",
  retryCue: "Repite y cierra con una conclusión.",
  observations: [],
};

Deno.test("evaluate uses a model available on Groq's free and developer tiers", async () => {
  // llama-3.3-70b-versatile left the free and developer tiers; Groq answers
  // "does not exist or you do not have access to it" for non-enterprise keys.
  const { requests, restore } = stubFetch({
    choices: [{ message: { content: JSON.stringify(coaching) } }],
  });
  try {
    await createGroqProvider("test-key").evaluate("Hola, esta mañana caminé.");
  } finally {
    restore();
  }
  assertEquals(requests.length, 1);
  assertEquals(requests[0].url, "https://api.groq.com/openai/v1/chat/completions");
  const payload = await requests[0].json();
  assertEquals(payload.model, "openai/gpt-oss-120b");
  assertEquals(payload.response_format, { type: "json_object" });
});

Deno.test("transcribe keeps whisper-large-v3-turbo with word timestamps", async () => {
  const { requests, restore } = stubFetch({
    text: "Hola",
    duration: 1,
    words: [{ word: "Hola", start: 0, end: 0.5 }],
  });
  try {
    await createGroqProvider("test-key").transcribe(new Uint8Array([1, 2, 3]), "audio/wav");
  } finally {
    restore();
  }
  const form = await requests[0].formData();
  assertEquals(form.get("model"), "whisper-large-v3-turbo");
  assertEquals(form.get("response_format"), "verbose_json");
  assertEquals(form.getAll("timestamp_granularities[]"), ["word"]);
});
