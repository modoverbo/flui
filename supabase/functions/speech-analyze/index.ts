import { createClient } from "npm:@supabase/supabase-js@2.116.0";
import { parseAllowedOrigins } from "../_shared/cors.ts";
import {
  createSpeechAnalyzeHandler,
  type ProviderTranscript,
  type SpeechCoaching,
} from "./handler.ts";

function required(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

const supabaseUrl = required("SUPABASE_URL");
const serviceRoleKey = required("SUPABASE_SERVICE_ROLE_KEY");
const groqApiKey = required("GROQ_API_KEY");
const origins = parseAllowedOrigins(Deno.env.get("ALLOWED_ORIGINS"));
const allowedOrigins = origins.length > 0 ? origins : ["http://localhost:3000"];
const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const handler = createSpeechAnalyzeHandler({
  allowedOrigins,
  async getUserId(token) {
    const { data, error } = await admin.auth.getUser(token);
    return error || !data.user ? null : data.user.id;
  },
  async transcribe(bytes, mimeType): Promise<ProviderTranscript> {
    const extension = mimeType.split("/").at(-1)?.replace("m4a", "m4a") ?? "wav";
    const form = new FormData();
    const ownedBytes = Uint8Array.from(bytes);
    form.append(
      "file",
      new Blob([ownedBytes.buffer], { type: mimeType }),
      `speech.${extension}`,
    );
    form.append("model", "whisper-large-v3-turbo");
    form.append("language", "es");
    form.append("response_format", "verbose_json");
    form.append("timestamp_granularities[]", "word");
    const response = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
      method: "POST",
      headers: { Authorization: `Bearer ${groqApiKey}` },
      body: form,
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) throw response;
    const json = await response.json() as {
      text?: string;
      duration?: number;
      words?: Array<{ word?: string; start?: number; end?: number }>;
    };
    if (typeof json.text !== "string" || !Array.isArray(json.words)) {
      throw new Error("Groq returned an invalid transcription response.");
    }
    return {
      text: json.text,
      durationSeconds: typeof json.duration === "number" ? json.duration : 0,
      words: json.words.flatMap((word) =>
        typeof word.word === "string" && typeof word.start === "number" &&
          typeof word.end === "number"
          ? [{ text: word.word.trim(), start: word.start, end: word.end }]
          : []
      ),
    };
  },
  async evaluate(text): Promise<SpeechCoaching> {
    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${groqApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "Eres un entrenador de comunicación oral en español. Evalúa únicamente la evidencia del texto; no inventes tono, pronunciación ni emociones. Responde JSON con exactamente: summary, structure, vocabulary, strength, retryCue. Cada valor debe ser una frase breve, concreta, respetuosa y en español. vocabulary debe mencionar evidencia léxica específica. retryCue debe pedir una acción medible para repetir el intento.",
          },
          {
            role: "user",
            content:
              `Consigna: Cuéntame una decisión pequeña que mejoró tu día.\nTranscripción:\n${text}`,
          },
        ],
      }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) throw response;
    const payload = await response.json() as {
      choices?: Array<{ message?: { content?: string } }>;
    };
    const content = payload.choices?.[0]?.message?.content;
    if (typeof content !== "string") throw new Error("Missing coaching response.");
    const coaching = JSON.parse(content) as Partial<SpeechCoaching>;
    for (const key of ["summary", "structure", "vocabulary", "strength", "retryCue"] as const) {
      if (typeof coaching[key] !== "string" || !coaching[key]?.trim()) {
        throw new Error(`Invalid coaching field: ${key}`);
      }
    }
    return coaching as SpeechCoaching;
  },
});

Deno.serve(handler);
