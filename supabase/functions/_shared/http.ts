/** Typed HTTP helpers shared by the Whop Edge Functions. */

export type ErrorCode =
  | "method_not_allowed"
  | "origin_not_allowed"
  | "unauthorized"
  | "access_required"
  | "access_unavailable"
  | "invalid_body"
  | "invalid_payload"
  | "invalid_signature"
  | "unknown_plan"
  | "already_subscribed"
  | "invalid_audio"
  | "no_speech"
  | "payload_too_large"
  | "daily_limit_reached"
  | "rate_limited"
  | "upstream_error"
  | "internal_error";

/** An error that maps directly to an HTTP response `{ error: { code, message } }`. */
export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "HttpError";
  }
}

export function jsonResponse(
  status: number,
  body: unknown,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json; charset=utf-8" },
  });
}

export function errorResponse(error: HttpError, headers: Record<string, string> = {}): Response {
  return jsonResponse(
    error.status,
    { error: { code: error.code, message: error.message } },
    headers,
  );
}

/** Extracts the token from `Authorization: Bearer <token>`, or null when absent or malformed. */
export function bearerToken(header: string | null): string | null {
  const match = header?.match(/^Bearer\s+(\S+)\s*$/i);
  return match ? match[1] : null;
}
