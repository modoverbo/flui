/**
 * Edge Function entrypoint: wires the checkout handler to Supabase and Whop.
 * Secrets: WHOP_API_KEY (never sent to clients), WHOP_API_BASE_URL, APP_URL, ALLOWED_ORIGINS.
 */
import { createClient } from "npm:@supabase/supabase-js@2.116.0";
import { createWhopCheckoutConfiguration } from "../_shared/checkout.ts";
import { readCheckoutEnv } from "../_shared/env.ts";
import { createCheckoutHandler } from "./handler.ts";

const env = readCheckoutEnv((name) => Deno.env.get(name));

const admin = createClient(env.supabaseUrl, env.serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const handler = createCheckoutHandler({
  allowedOrigins: env.allowedOrigins,
  appUrl: env.appUrl,

  async getUserId(token) {
    const { data, error } = await admin.auth.getUser(token);
    return error || !data.user ? null : data.user.id;
  },

  async hasAccess(userId) {
    const { data, error } = await admin.rpc("has_access", { uid: userId });
    if (error) throw new Error(`has_access failed: ${error.message}`);
    return data === true;
  },

  async findActivePlan(planId) {
    const { data, error } = await admin
      .from("subscription_plans")
      .select("id, whop_plan_id")
      .eq("id", planId)
      .eq("active", true)
      .maybeSingle();
    if (error) throw new Error(`subscription_plans lookup failed: ${error.message}`);
    return data ? { id: data.id, whopPlanId: data.whop_plan_id } : null;
  },

  createCheckoutConfiguration(body) {
    return createWhopCheckoutConfiguration(
      { fetch, baseUrl: env.whopApiBaseUrl, apiKey: env.whopApiKey },
      body,
    );
  },
});

Deno.serve(handler);
