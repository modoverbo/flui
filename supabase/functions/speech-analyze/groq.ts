import type {
  ChallengeContext,
  ProviderTranscript,
  SpeechCoaching,
  SpeechEvaluation,
} from "./handler.ts";
import behaviorCodesData from "./behavior_codes.json" with { type: "json" };

/** Transcription and evaluation calls to the Groq API, shared by `index.ts` and `local.ts`. */
export interface GroqProvider {
  transcribe(bytes: Uint8Array, mimeType: string): Promise<ProviderTranscript>;
  evaluate(text: string, challenge?: ChallengeContext): Promise<SpeechEvaluation>;
}

interface WireBehaviorCode {
  wireCode: string;
  area: string;
  polarity: string;
}

// Voice/fluency behaviors are always measured client-side, never AI-judged
// (design D12) -- the LLM is only offered thinking/language codes to pick
// from, closing the vocabulary it can report observations against.
const allowedCodesPrompt = (behaviorCodesData as WireBehaviorCode[])
  .filter((entry) => entry.area === "thinking" || entry.area === "language")
  .map((entry) => `${entry.wireCode} (${entry.area}, ${entry.polarity})`)
  .join(", ");

const defaultPrompt = "Cuéntame una decisión pequeña que mejoró tu día.";

const coachingSystemPrompt =
  `Eres un entrenador de comunicación oral en español. Evalúa únicamente la evidencia del texto; no inventes tono, pronunciación ni emociones. Responde JSON con exactamente: summary, structure, vocabulary, strength, retryCue, observations. Cada valor de summary, structure, vocabulary, strength y retryCue debe ser una frase breve, concreta, respetuosa y en español. vocabulary debe mencionar evidencia léxica específica. retryCue debe pedir una acción medible para repetir el intento. observations es un arreglo de hasta 6 objetos {skill, code, polarity, evidence}, usando EXCLUSIVAMENTE estos códigos exactos, sin inventar otros: ${allowedCodesPrompt}. evidence es opcional, en español, de máximo 160 caracteres, citando algo concreto del texto. Nunca incluyas un número, porcentaje o puntaje en ningún campo.`;

/** Builds a `GroqProvider` for `apiKey`. `timeoutMs`, when set, aborts a stalled Groq call. */
export function createGroqProvider(
  apiKey: string,
  options: { timeoutMs?: number } = {},
): GroqProvider {
  const signal = () =>
    options.timeoutMs !== undefined ? AbortSignal.timeout(options.timeoutMs) : undefined;

  return {
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
        headers: { Authorization: `Bearer ${apiKey}` },
        body: form,
        signal: signal(),
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
    async evaluate(text, challenge): Promise<SpeechEvaluation> {
      const prompt = challenge?.prompt ?? defaultPrompt;
      const focusHint = challenge
        ? `\nÁrea de enfoque de este reto: ${challenge.skill} — ${challenge.focus}.`
        : "";
      const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          temperature: 0.2,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: coachingSystemPrompt },
            {
              role: "user",
              content: `Consigna: ${prompt}${focusHint}\nTranscripción:\n${text}`,
            },
          ],
        }),
        signal: signal(),
      });
      if (!response.ok) throw response;
      const payload = await response.json() as {
        choices?: Array<{ message?: { content?: string } }>;
      };
      const content = payload.choices?.[0]?.message?.content;
      if (typeof content !== "string") throw new Error("Missing coaching response.");
      const parsed = JSON.parse(content) as Partial<SpeechCoaching> & { observations?: unknown };
      for (const key of ["summary", "structure", "vocabulary", "strength", "retryCue"] as const) {
        if (typeof parsed[key] !== "string" || !parsed[key]?.trim()) {
          throw new Error(`Invalid coaching field: ${key}`);
        }
      }
      const { observations, ...coaching } = parsed;
      return { coaching: coaching as SpeechCoaching, observations: observations ?? [] };
    },
  };
}
