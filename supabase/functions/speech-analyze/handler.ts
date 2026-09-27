import { corsHeaders, isOriginAllowed, preflightResponse } from "../_shared/cors.ts";
import { bearerToken, errorResponse, HttpError, jsonResponse } from "../_shared/http.ts";
import behaviorCodesData from "./behavior_codes.json" with { type: "json" };

export interface TranscriptWord {
  text: string;
  start: number;
  end: number;
}

export interface ProviderTranscript {
  text: string;
  durationSeconds: number;
  words: TranscriptWord[];
}

export interface SpeechCoaching {
  summary: string;
  structure: string;
  vocabulary: string;
  strength: string;
  retryCue: string;
}

/** One sanitized `observations[]` entry in the response payload (design §9). */
export interface SpeechObservation {
  skill: string;
  code: string;
  polarity: string;
  evidence?: string;
}

/** A published challenge's server-resolved prompt context (D18). */
export interface ChallengeContext {
  prompt: string;
  skill: string;
  focus: string;
  focusBehaviors: string[];
}

export interface SpeechEvaluation {
  coaching: SpeechCoaching;
  /**
   * Raw, not-yet-sanitized AI-reported observations. Untyped on purpose:
   * this is untrusted provider output, sanitized against the closed
   * `BehaviorCode` catalog by `sanitizeObservations` below before ever
   * reaching a response (never fails the response, design §9).
   */
  observations: unknown;
}

export interface SpeechAnalyzeDeps {
  allowedOrigins: string[];
  getUserId(token: string): Promise<string | null>;
  /** True when the user may spend a paid analysis call. Throws on infrastructure failure. */
  hasAccess(userId: string): Promise<boolean>;
  /**
   * Claims one paid analysis unit for the caller's current UTC day. Returns
   * false once the daily limit is reached. Throws on infrastructure failure.
   * Required (not optional): a caller must always enforce some limit, so no
   * wiring path can silently ship with the quota disabled.
   */
  claimDailyAnalysis(userId: string): Promise<boolean>;
  /**
   * Loads a published challenge's server-resolved prompt context (D18).
   * Returns null when `challengeId` does not resolve to a published
   * challenge. Not called at all when the request omits `challengeId`.
   */
  loadChallenge(challengeId: string): Promise<ChallengeContext | null>;
  transcribe(bytes: Uint8Array, mimeType: string): Promise<ProviderTranscript>;
  evaluate(text: string, challenge?: ChallengeContext): Promise<SpeechEvaluation>;
  log?: (message: string, details?: Record<string, unknown>) => void;
}

const allowedMimeTypes = new Set(["audio/wav", "audio/webm", "audio/ogg", "audio/m4a"]);
const maxDecodedBytes = 5 * 1024 * 1024;

interface WireBehaviorCode {
  wireCode: string;
  area: string;
  polarity: string;
}

// Voice/fluency behaviors are always measured client-side, never AI-judged
// (design D12) -- only thinking/language codes are trusted from `evaluate`.
const aiObservableCodes = new Map<string, WireBehaviorCode>(
  (behaviorCodesData as WireBehaviorCode[])
    .filter((entry) => entry.area === "thinking" || entry.area === "language")
    .map((entry) => [entry.wireCode, entry]),
);

const maxObservations = 6;
const maxEvidenceLength = 160;

/**
 * Sanitizes raw AI-reported observations against the closed catalog: unknown
 * codes, skill/polarity mismatches, and non-string fields are dropped;
 * evidence is truncated rather than rejected; the result never exceeds
 * `maxObservations`. Never throws -- a malformed `observations` value (e.g.
 * not an array) sanitizes to an empty array (design §9, "never failing the
 * response").
 */
function sanitizeObservations(raw: unknown): SpeechObservation[] {
  if (!Array.isArray(raw)) return [];
  const sanitized: SpeechObservation[] = [];
  for (const entry of raw) {
    if (sanitized.length >= maxObservations) break;
    if (entry === null || typeof entry !== "object") continue;
    const record = entry as Record<string, unknown>;
    const { code, skill, polarity } = record;
    if (typeof code !== "string" || typeof skill !== "string" || typeof polarity !== "string") {
      continue;
    }
    const known = aiObservableCodes.get(code);
    if (!known || known.area !== skill || known.polarity !== polarity) continue;
    const evidenceRaw = record.evidence;
    const evidence = typeof evidenceRaw === "string" && evidenceRaw.trim().length > 0
      ? evidenceRaw.trim().slice(0, maxEvidenceLength)
      : undefined;
    sanitized.push(evidence ? { skill, code, polarity, evidence } : { skill, code, polarity });
  }
  return sanitized;
}

/** Runs the Whisper transcription call and maps provider/empty-speech errors. */
async function transcribeAudio(
  deps: Pick<SpeechAnalyzeDeps, "transcribe">,
  bytes: Uint8Array,
  mimeType: string,
): Promise<ProviderTranscript> {
  let transcript: ProviderTranscript;
  try {
    transcript = await deps.transcribe(bytes, mimeType);
  } catch (error) {
    if (error instanceof Response && error.status === 429) {
      throw new HttpError(429, "rate_limited", "Speech analysis is busy. Try again shortly.");
    }
    throw new HttpError(502, "upstream_error", "Speech analysis is temporarily unavailable.");
  }
  if (!transcript.text.trim()) {
    throw new HttpError(422, "no_speech", "No speech was detected.");
  }
  return transcript;
}

export function createSpeechAnalyzeHandler(
  deps: SpeechAnalyzeDeps,
): (request: Request) => Promise<Response> {
  const log = deps.log ?? ((message, details) => console.error(message, details ?? {}));

  return async (request) => {
    const origin = request.headers.get("Origin");
    const cors = corsHeaders(origin, deps.allowedOrigins);
    if (request.method === "OPTIONS") return preflightResponse(request, deps.allowedOrigins);

    try {
      if (request.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST.");
      if (origin !== null && !isOriginAllowed(origin, deps.allowedOrigins)) {
        throw new HttpError(403, "origin_not_allowed", "Origin not allowed.");
      }
      const token = bearerToken(request.headers.get("Authorization"));
      const userId = token ? await deps.getUserId(token) : null;
      if (!userId) throw new HttpError(401, "unauthorized", "Sign in to analyze speech.");

      let hasAccess: boolean;
      try {
        hasAccess = await deps.hasAccess(userId);
      } catch {
        throw new HttpError(
          503,
          "access_unavailable",
          "Could not verify access. Try again shortly.",
        );
      }
      if (!hasAccess) {
        throw new HttpError(
          403,
          "access_required",
          "An active subscription or trial is required.",
        );
      }

      const body = await request.json().catch(() => {
        throw new HttpError(400, "invalid_body", "Expected a JSON audio payload.");
      }) as Record<string, unknown>;
      const audioBase64 = body.audioBase64;
      const mimeType = body.mimeType;
      const durationMs = body.durationMs;
      if (
        typeof audioBase64 !== "string" || typeof mimeType !== "string" ||
        typeof durationMs !== "number" || !allowedMimeTypes.has(mimeType) ||
        durationMs < 500 || durationMs > 60_000
      ) {
        throw new HttpError(400, "invalid_audio", "Audio payload is not supported.");
      }
      if (audioBase64.length > Math.ceil(maxDecodedBytes * 4 / 3) + 4) {
        throw new HttpError(413, "payload_too_large", "Audio payload is too large.");
      }
      let bytes: Uint8Array;
      try {
        bytes = Uint8Array.from(atob(audioBase64), (character) => character.charCodeAt(0));
      } catch {
        throw new HttpError(400, "invalid_audio", "Audio payload is not valid base64.");
      }
      if (bytes.length === 0 || bytes.length > maxDecodedBytes) {
        throw new HttpError(
          bytes.length === 0 ? 400 : 413,
          bytes.length === 0 ? "invalid_audio" : "payload_too_large",
          bytes.length === 0 ? "Audio payload is empty." : "Audio payload is too large.",
        );
      }

      const challengeIdRaw = body.challengeId;
      if (
        challengeIdRaw !== undefined &&
        (typeof challengeIdRaw !== "string" || challengeIdRaw.length === 0)
      ) {
        throw new HttpError(400, "invalid_body", "challengeId must be a non-empty string.");
      }
      let challenge: ChallengeContext | undefined;
      if (typeof challengeIdRaw === "string") {
        challenge = (await deps.loadChallenge(challengeIdRaw)) ?? undefined;
        if (!challenge) {
          throw new HttpError(400, "unknown_challenge", "That challenge is not available.");
        }
      }

      let quotaAllowed: boolean;
      try {
        quotaAllowed = await deps.claimDailyAnalysis(userId);
      } catch {
        throw new HttpError(
          503,
          "access_unavailable",
          "Could not verify access. Try again shortly.",
        );
      }
      if (!quotaAllowed) {
        throw new HttpError(
          429,
          "daily_limit_reached",
          "You have reached today's analysis limit.",
        );
      }

      const transcript = await transcribeAudio(deps, bytes, mimeType);

      let evaluation: SpeechEvaluation;
      try {
        evaluation = await deps.evaluate(transcript.text.trim(), challenge);
      } catch (error) {
        if (error instanceof Response && error.status === 429) {
          throw new HttpError(429, "rate_limited", "Speech analysis is busy. Try again shortly.");
        }
        throw new HttpError(502, "upstream_error", "Speech analysis is temporarily unavailable.");
      }
      return jsonResponse(200, {
        text: transcript.text.trim(),
        durationMs: Math.round(transcript.durationSeconds * 1000),
        words: transcript.words,
        analysis: evaluation.coaching,
        observations: sanitizeObservations(evaluation.observations),
      }, cors);
    } catch (error) {
      if (error instanceof HttpError) {
        if (error.status >= 500) log("speech-analyze failed", { code: error.code });
        return errorResponse(error, cors);
      }
      log("speech-analyze unexpected error");
      return errorResponse(new HttpError(500, "internal_error", "Unexpected error."), cors);
    }
  };
}
