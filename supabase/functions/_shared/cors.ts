/**
 * CORS for browser calls from the flui web app. Origins come from an explicit
 * allow-list (`ALLOWED_ORIGINS`); wildcards are intentionally not supported.
 */

const ALLOWED_HEADERS = "authorization, x-client-info, apikey, content-type";
const ALLOWED_METHODS = "POST, OPTIONS";

export function parseAllowedOrigins(raw: string | undefined): string[] {
  return (raw ?? "")
    .split(",")
    .map((origin) => origin.trim().replace(/\/+$/, ""))
    .filter((origin) => origin.length > 0);
}

export function isOriginAllowed(origin: string | null, allowed: readonly string[]): boolean {
  return origin !== null && origin !== "*" && allowed.includes(origin);
}

export function corsHeaders(
  origin: string | null,
  allowed: readonly string[],
): Record<string, string> {
  if (!isOriginAllowed(origin, allowed)) {
    return { Vary: "Origin" };
  }
  return {
    "Access-Control-Allow-Origin": origin as string,
    "Access-Control-Allow-Methods": ALLOWED_METHODS,
    "Access-Control-Allow-Headers": ALLOWED_HEADERS,
    "Access-Control-Max-Age": "600",
    Vary: "Origin",
  };
}

export function preflightResponse(request: Request, allowed: readonly string[]): Response {
  const origin = request.headers.get("Origin");
  const status = isOriginAllowed(origin, allowed) ? 204 : 403;
  return new Response(null, { status, headers: corsHeaders(origin, allowed) });
}
