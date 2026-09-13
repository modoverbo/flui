/** Checkout request validation and the Whop checkout-configuration API client. */
import { HttpError } from "./http.ts";

const PLAN_ID_PATTERN = /^[a-z][a-z0-9_]{0,63}$/;
const WHOP_ORIGIN = "https://whop.com";

export interface CheckoutRequest {
  planId: string;
}

/** Body sent to `POST {WHOP_API_BASE_URL}/checkout_configurations`. */
export interface WhopCheckoutConfigurationRequest {
  plan_id: string;
  metadata: { app_user_id: string };
  redirect_url: string;
}

export interface WhopCheckoutConfiguration {
  id: string;
  purchaseUrl: string;
}

export interface WhopClientOptions {
  fetch: (input: Request | URL | string, init?: RequestInit) => Promise<Response>;
  baseUrl: string;
  apiKey: string;
}

export function parseCheckoutRequest(body: unknown): CheckoutRequest {
  const planId = typeof body === "object" && body !== null && !Array.isArray(body)
    ? (body as Record<string, unknown>).planId
    : undefined;
  if (typeof planId !== "string" || !PLAN_ID_PATTERN.test(planId)) {
    throw new HttpError(400, "invalid_body", 'Expected a JSON body like { "planId": "monthly" }.');
  }
  return { planId };
}

export function buildCheckoutConfigurationRequest(input: {
  whopPlanId: string;
  userId: string;
  appUrl: string;
}): WhopCheckoutConfigurationRequest {
  return {
    plan_id: input.whopPlanId,
    // Whop copies checkout metadata to the membership it creates; the webhook
    // uses app_user_id to find the flui user.
    metadata: { app_user_id: input.userId },
    redirect_url: `${input.appUrl.replace(/\/+$/, "")}/checkout/return`,
  };
}

/** Whop may return an absolute URL or a path such as `/checkout/ch_xxx/`. */
export function normalizePurchaseUrl(raw: string): string {
  const url = new URL(raw, WHOP_ORIGIN);
  if (url.protocol !== "https:") {
    throw new HttpError(502, "upstream_error", "Whop returned an unexpected checkout URL.");
  }
  return url.toString();
}

export async function createWhopCheckoutConfiguration(
  client: WhopClientOptions,
  body: WhopCheckoutConfigurationRequest,
): Promise<WhopCheckoutConfiguration> {
  const endpoint = `${client.baseUrl.replace(/\/+$/, "")}/checkout_configurations`;
  let response: Response;
  try {
    response = await client.fetch(endpoint, {
      method: "POST",
      headers: { Authorization: `Bearer ${client.apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch {
    throw new HttpError(502, "upstream_error", "Could not reach the payment provider.");
  }

  const payload = await response.json().catch(() => null) as Record<string, unknown> | null;
  if (!response.ok) {
    throw new HttpError(
      502,
      "upstream_error",
      `The payment provider rejected the checkout (${response.status}).`,
    );
  }
  if (typeof payload?.purchase_url !== "string" || typeof payload?.id !== "string") {
    throw new HttpError(
      502,
      "upstream_error",
      "The payment provider returned an incomplete checkout.",
    );
  }
  return { id: payload.id, purchaseUrl: normalizePurchaseUrl(payload.purchase_url) };
}
