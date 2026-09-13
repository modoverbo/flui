/**
 * Standard Webhooks signature verification (https://www.standardwebhooks.com/),
 * as used by Whop.
 *
 * Whop signs `{webhook-id}.{webhook-timestamp}.{raw body}` with HMAC-SHA256 and
 * sends `webhook-signature: v1,<base64>` (several space-separated signatures are
 * allowed). Whop's key is the raw UTF-8 bytes of the whole secret string
 * (e.g. `ws_...`), which is what Whop's SDK obtains with
 * `new Webhook(btoa(secret))` from the `standardwebhooks` package. The tests
 * check compatibility against that reference implementation.
 */

const DEFAULT_TOLERANCE_SECONDS = 5 * 60;
const encoder = new TextEncoder();

export class WebhookVerificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WebhookVerificationError";
  }
}

export interface VerifyWebhookOptions {
  secret: string;
  headers: Headers;
  /** The raw request body, exactly as received. */
  body: string;
  now?: Date;
  toleranceSeconds?: number;
}

async function hmacBase64(secret: string, content: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(content)));
  let binary = "";
  for (const byte of signature) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function timingSafeEqual(a: string, b: string): boolean {
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  let diff = left.length ^ right.length;
  for (let i = 0; i < Math.max(left.length, right.length); i++) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

/** Produces a `v1,<base64>` signature. Used by tests and local tooling. */
export async function signWebhook(
  secret: string,
  webhookId: string,
  timestampSeconds: number,
  body: string,
): Promise<string> {
  return `v1,${await hmacBase64(secret, `${webhookId}.${timestampSeconds}.${body}`)}`;
}

/** Resolves when the signature is valid; throws WebhookVerificationError otherwise. */
export async function verifyWebhook(options: VerifyWebhookOptions): Promise<void> {
  const { secret, headers, body } = options;
  if (!secret) {
    throw new Error("Webhook secret is not configured.");
  }

  const webhookId = headers.get("webhook-id");
  const timestampHeader = headers.get("webhook-timestamp");
  const signatureHeader = headers.get("webhook-signature");
  if (!webhookId || !timestampHeader || !signatureHeader) {
    throw new WebhookVerificationError("Missing required headers");
  }

  const timestamp = Number(timestampHeader);
  if (!Number.isInteger(timestamp)) {
    throw new WebhookVerificationError("Invalid webhook timestamp");
  }
  const nowSeconds = Math.floor((options.now ?? new Date()).getTime() / 1000);
  const tolerance = options.toleranceSeconds ?? DEFAULT_TOLERANCE_SECONDS;
  if (Math.abs(nowSeconds - timestamp) > tolerance) {
    throw new WebhookVerificationError("Message timestamp outside the allowed tolerance");
  }

  const expected = await signWebhook(secret, webhookId, timestamp, body);
  const candidates = signatureHeader.split(" ").filter((candidate) => candidate.startsWith("v1,"));
  let matched = false;
  for (const candidate of candidates) {
    // Compare every candidate so timing does not reveal which one matched.
    matched = timingSafeEqual(candidate, expected) || matched;
  }
  if (!matched) {
    throw new WebhookVerificationError("No matching signature found");
  }
}
