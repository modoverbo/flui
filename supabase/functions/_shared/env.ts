/**
 * Environment configuration for the Whop Edge Functions. Values are secrets set
 * with `supabase secrets set` (or supabase/functions/.env locally); error
 * messages only ever name missing variables, never values.
 */
import { parseAllowedOrigins } from "./cors.ts";

export const DEFAULT_WHOP_API_BASE_URL = "https://api.whop.com/api/v1";

export type EnvSource = (name: string) => string | undefined;

export interface CheckoutEnv {
  supabaseUrl: string;
  serviceRoleKey: string;
  whopApiKey: string;
  whopApiBaseUrl: string;
  appUrl: string;
  allowedOrigins: string[];
}

export interface WebhookEnv {
  supabaseUrl: string;
  serviceRoleKey: string;
  webhookSecret: string;
  whopCompanyId: string | undefined;
}

function requireAll(get: EnvSource, names: string[]): Record<string, string> {
  const values: Record<string, string> = {};
  const missing: string[] = [];
  for (const name of names) {
    const value = get(name)?.trim();
    if (value) values[name] = value;
    else missing.push(name);
  }
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
  }
  return values;
}

function optional(get: EnvSource, name: string): string | undefined {
  const value = get(name)?.trim();
  return value ? value : undefined;
}

export function readCheckoutEnv(get: EnvSource): CheckoutEnv {
  const values = requireAll(get, [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "WHOP_API_KEY",
    "APP_URL",
  ]);
  const appUrl = values.APP_URL.replace(/\/+$/, "");
  const allowedOrigins = parseAllowedOrigins(get("ALLOWED_ORIGINS"));
  return {
    supabaseUrl: values.SUPABASE_URL,
    serviceRoleKey: values.SUPABASE_SERVICE_ROLE_KEY,
    whopApiKey: values.WHOP_API_KEY,
    whopApiBaseUrl: optional(get, "WHOP_API_BASE_URL") ?? DEFAULT_WHOP_API_BASE_URL,
    appUrl,
    allowedOrigins: allowedOrigins.length > 0 ? allowedOrigins : [new URL(appUrl).origin],
  };
}

export function readWebhookEnv(get: EnvSource): WebhookEnv {
  const values = requireAll(get, [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "WHOP_WEBHOOK_SECRET",
  ]);
  return {
    supabaseUrl: values.SUPABASE_URL,
    serviceRoleKey: values.SUPABASE_SERVICE_ROLE_KEY,
    webhookSecret: values.WHOP_WEBHOOK_SECRET,
    whopCompanyId: optional(get, "WHOP_COMPANY_ID"),
  };
}
