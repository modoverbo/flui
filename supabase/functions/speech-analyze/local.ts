import { parseAllowedOrigins } from "../_shared/cors.ts";
import {
  createSpeechAnalyzeHandler,
  type ProviderTranscript,
  type SpeechCoaching,
} from "./handler.ts";

const groqApiKey = Deno.env.get("GROQ_API_KEY")?.trim();
if (!groqApiKey) throw new Error("Missing GROQ_API_KEY in .env.local");

async function transcribe(bytes: Uint8Array, mimeType: string): Promise<ProviderTranscript> {
  const form = new FormData();
  const owned = Uint8Array.from(bytes);
  form.append("file", new Blob([owned.buffer], { type: mimeType }), "speech.wav");
  form.append("model", "whisper-large-v3-turbo");
  form.append("language", "es");
  form.append("response_format", "verbose_json");
  form.append("timestamp_granularities[]", "word");
  const response = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${groqApiKey}` },
    body: form,
  });
  if (!response.ok) throw response;
  const json = await response.json() as {
    text?: string;
    duration?: number;
    words?: Array<{ word?: string; start?: number; end?: number }>;
  };
  if (typeof json.text !== "string" || !Array.isArray(json.words)) {
    throw new Error("Invalid transcript");
  }
  return {
    text: json.text,
    durationSeconds: json.duration ?? 0,
    words: json.words.flatMap((word) =>
      typeof word.word === "string" && typeof word.start === "number" &&
        typeof word.end === "number"
        ? [{ text: word.word.trim(), start: word.start, end: word.end }]
        : []
    ),
  };
}

async function evaluate(text: string): Promise<SpeechCoaching> {
  const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${groqApiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile",
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            "Eres entrenador de comunicación oral en español. Basándote solo en el texto, devuelve JSON con summary, structure, vocabulary, strength y retryCue. Frases breves y concretas. vocabulary cita evidencia léxica; retryCue pide una acción medible. No inventes tono ni pronunciación.",
        },
        {
          role: "user",
          content:
            `Consigna: Cuéntame una decisión pequeña que mejoró tu día.\nTranscripción:\n${text}`,
        },
      ],
    }),
  });
  if (!response.ok) throw response;
  const payload = await response.json() as { choices?: Array<{ message?: { content?: string } }> };
  const content = payload.choices?.[0]?.message?.content;
  if (!content) throw new Error("Invalid coaching");
  return JSON.parse(content) as SpeechCoaching;
}

const handler = createSpeechAnalyzeHandler({
  allowedOrigins: parseAllowedOrigins("http://127.0.0.1:3000,http://localhost:3000"),
  getUserId: (token) => Promise.resolve(token === "local-dev" ? "local-developer" : null),
  transcribe,
  evaluate,
});

Deno.serve({ hostname: "127.0.0.1", port: 8787 }, handler);
