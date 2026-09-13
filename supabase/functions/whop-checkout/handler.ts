/**
 * POST /functions/v1/whop-checkout
 *
 * Request:  Authorization: Bearer <Supabase user JWT>
 *           { "planId": "monthly" | "quarterly" }
 * Response: 200 { "purchaseUrl": "https://whop.com/checkout/..." }
 * Errors:   { "error": { "code", "message" } } with 400 invalid_body, 401 unauthorized,
 *           403 origin_not_allowed, 404 unknown_plan, 405 method_not_allowed,
 *           409 already_subscribed, 502 upstream_error, 500 internal_error.
 */
import {
  buildCheckoutConfigurationRequest,
  parseCheckoutRequest,
  type WhopCheckoutConfiguration,
  type WhopCheckoutConfigurationRequest,
} from "../_shared/checkout.ts";
import { corsHeaders, isOriginAllowed, preflightResponse } from "../_shared/cors.ts";
import { bearerToken, errorResponse, HttpError, jsonResponse } from "../_shared/http.ts";

export interface CheckoutDeps {
  allowedOrigins: string[];
  appUrl: string;
  /** Resolves the Supabase user id for a JWT, or null when the token is not valid. */
  getUserId(token: string): Promise<string | null>;
  hasAccess(userId: string): Promise<boolean>;
  findActivePlan(planId: string): Promise<{ id: string; whopPlanId: string } | null>;
  createCheckoutConfiguration(
    body: WhopCheckoutConfigurationRequest,
  ): Promise<WhopCheckoutConfiguration>;
  log?: (message: string, details?: Record<string, unknown>) => void;
}

export function createCheckoutHandler(deps: CheckoutDeps): (request: Request) => Promise<Response> {
  const log = deps.log ?? ((message, details) => console.error(message, details ?? {}));

  return async (request) => {
    const origin = request.headers.get("Origin");
    const cors = corsHeaders(origin, deps.allowedOrigins);

    if (request.method === "OPTIONS") {
      return preflightResponse(request, deps.allowedOrigins);
    }

    try {
      if (request.method !== "POST") {
        throw new HttpError(405, "method_not_allowed", "Use POST.");
      }
      // Browsers always send Origin on cross-origin POST; non-browser clients may omit it.
      if (origin !== null && !isOriginAllowed(origin, deps.allowedOrigins)) {
        throw new HttpError(403, "origin_not_allowed", "Origin not allowed.");
      }

      const token = bearerToken(request.headers.get("Authorization"));
      const userId = token ? await deps.getUserId(token) : null;
      if (!userId) {
        throw new HttpError(401, "unauthorized", "Sign in to start a checkout.");
      }

      const body = await request.json().catch(() => {
        throw new HttpError(
          400,
          "invalid_body",
          'Expected a JSON body like { "planId": "monthly" }.',
        );
      });
      const { planId } = parseCheckoutRequest(body);

      const plan = await deps.findActivePlan(planId);
      if (!plan) {
        throw new HttpError(404, "unknown_plan", "This plan is not available.");
      }

      if (await deps.hasAccess(userId)) {
        throw new HttpError(
          409,
          "already_subscribed",
          "This account already has an active subscription or trial.",
        );
      }

      let checkout: WhopCheckoutConfiguration;
      try {
        checkout = await deps.createCheckoutConfiguration(
          buildCheckoutConfigurationRequest({
            whopPlanId: plan.whopPlanId,
            userId,
            appUrl: deps.appUrl,
          }),
        );
      } catch (error) {
        if (error instanceof HttpError) throw error;
        throw new HttpError(502, "upstream_error", "Could not create the checkout.");
      }

      return jsonResponse(200, { purchaseUrl: checkout.purchaseUrl }, cors);
    } catch (error) {
      if (error instanceof HttpError) {
        if (error.status >= 500) {
          log("whop-checkout failed", { code: error.code, message: error.message });
        }
        return errorResponse(error, cors);
      }
      log("whop-checkout unexpected error", {
        message: error instanceof Error ? error.message : String(error),
      });
      return errorResponse(new HttpError(500, "internal_error", "Unexpected error."), cors);
    }
  };
}
