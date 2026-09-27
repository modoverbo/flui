import { corsHeaders, isOriginAllowed, preflightResponse } from "../_shared/cors.ts";
import { bearerToken, errorResponse, HttpError, jsonResponse } from "../_shared/http.ts";

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

export interface SpeechAnalyzeDeps {
  allowedOrigins: string[];
  getUserId(token: string): Promise<string | null>;
  /** True when the user may spend a paid analysis call. Throws on infrastructure failure. */
  hasAccess(userId: string): Promise<boolean>;
  /**
   * Claims one paid analysis unit for the caller's current UTC day. Returns
   * false once the daily limit is reached. Throws on infrastructure failure.
   * Omitted entirely (no configured daily limit) skips quota enforcement.
   */
  claimDailyAnalysis?(userId: string): Promise<boolean>;
  transcribe(bytes: Uint8Array, mimeType: string): Promise<ProviderTranscript>;
  evaluate(text: string): Promise<SpeechCoaching>;
  log?: (message: string, details?: Record<string, unknown>) => void;
}

const allowedMimeTypes = new Set(["audio/wav", "audio/webm", "audio/ogg", "audio/m4a"]);
const maxDecodedBytes = 5 * 1024 * 1024;

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

      if (deps.claimDailyAnalysis) {
        let allowed: boolean;
        try {
          allowed = await deps.claimDailyAnalysis(userId);
        } catch {
          throw new HttpError(
            503,
            "access_unavailable",
            "Could not verify access. Try again shortly.",
          );
        }
        if (!allowed) {
          throw new HttpError(
            429,
            "daily_limit_reached",
            "You have reached today's analysis limit.",
          );
        }
      }

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
      let analysis: SpeechCoaching;
      try {
        analysis = await deps.evaluate(transcript.text.trim());
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
        analysis,
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
