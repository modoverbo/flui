import { parseAllowedOrigins } from "../_shared/cors.ts";
import { createSpeechAnalyzeHandler } from "./handler.ts";
import { createGroqProvider } from "./groq.ts";

const groqApiKey = Deno.env.get("GROQ_API_KEY")?.trim();
if (!groqApiKey) throw new Error("Missing GROQ_API_KEY in .env.local");

const groq = createGroqProvider(groqApiKey);

const handler = createSpeechAnalyzeHandler({
  allowedOrigins: parseAllowedOrigins("http://127.0.0.1:3000,http://localhost:3000"),
  getUserId: (token) => Promise.resolve(token === "local-dev" ? "local-developer" : null),
  hasAccess: () => Promise.resolve(true),
  claimDailyAnalysis: () => Promise.resolve(true),
  loadChallenge: () => Promise.resolve(null),
  transcribe: groq.transcribe,
  evaluate: groq.evaluate,
});

Deno.serve({ hostname: "127.0.0.1", port: 8787 }, handler);
