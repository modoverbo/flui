import { createClient } from "npm:@supabase/supabase-js@2.116.0";
import { parseAllowedOrigins } from "../_shared/cors.ts";
import { createSpeechAnalyzeHandler } from "./handler.ts";
import { createGroqProvider } from "./groq.ts";

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

const groq = createGroqProvider(groqApiKey, { timeoutMs: 15_000 });

// Unset -> no quota enforcement (existing unlimited behavior). Set to a
// non-numeric value -> also treated as unset, never crashes the function.
const dailyLimitRaw = Deno.env.get("SPEECH_ANALYZE_DAILY_LIMIT")?.trim();
const dailyLimit = dailyLimitRaw && Number.isFinite(Number(dailyLimitRaw))
  ? Number(dailyLimitRaw)
  : undefined;

const handler = createSpeechAnalyzeHandler({
  allowedOrigins,
  async getUserId(token) {
    const { data, error } = await admin.auth.getUser(token);
    return error || !data.user ? null : data.user.id;
  },
  async hasAccess(userId) {
    const { data, error } = await admin.rpc("has_access", { uid: userId });
    if (error) throw error;
    if (typeof data !== "boolean") {
      throw new Error("has_access returned a non-boolean value.");
    }
    return data;
  },
  claimDailyAnalysis: dailyLimit === undefined ? undefined : async (userId) => {
    const { data, error } = await admin.rpc("claim_speech_analysis", {
      p_user_id: userId,
      p_daily_limit: dailyLimit,
    });
    if (error) throw error;
    if (typeof data !== "boolean") {
      throw new Error("claim_speech_analysis returned a non-boolean value.");
    }
    return data;
  },
  transcribe: groq.transcribe,
  evaluate: groq.evaluate,
});

Deno.serve(handler);
