/**
 * POST /functions/v1/account-delete
 *
 * Deletes the CALLER's own account (U22b; decisions #434, #894). Fails
 * closed at every step -- see handler.ts for the exact order and rationale.
 * Request:  Authorization: Bearer <Supabase user JWT> (no body required;
 *           any body is ignored, never used to target another user).
 * Response: 200 { "status": "deleted" }.
 * Errors:   { "error": { "code", "message" } } with 401 unauthorized,
 *           403 origin_not_allowed, 405 method_not_allowed,
 *           500 membership_id_missing, 502 whop_membership_not_found,
 *           502 storage_cleanup_failed, 502 account_deletion_failed,
 *           503 entitlement_unavailable, 503 billing_unavailable.
 * Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, WHOP_API_KEY,
 *          WHOP_API_BASE_URL (optional), ALLOWED_ORIGINS (optional).
 */
import { createClient } from "npm:@supabase/supabase-js@2.116.0";
import { parseAllowedOrigins } from "../_shared/cors.ts";
import { DEFAULT_WHOP_API_BASE_URL } from "../_shared/env.ts";
import { cancelMembership as cancelWhopMembership } from "../_shared/whop_membership.ts";
import { createAccountDeleteHandler, type EntitlementSnapshot } from "./handler.ts";

function required(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

const supabaseUrl = required("SUPABASE_URL");
const serviceRoleKey = required("SUPABASE_SERVICE_ROLE_KEY");
const whopApiKey = required("WHOP_API_KEY");
const whopApiBaseUrl = Deno.env.get("WHOP_API_BASE_URL")?.trim() || DEFAULT_WHOP_API_BASE_URL;
const origins = parseAllowedOrigins(Deno.env.get("ALLOWED_ORIGINS"));
const allowedOrigins = origins.length > 0 ? origins : ["http://localhost:3000"];

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const BUCKET = "speaking-audio";

interface EntitlementRow {
  whop_membership_id: string | null;
  status: "trialing" | "active" | "past_due" | "canceled" | "expired";
  cancel_at_period_end: boolean;
}

const handler = createAccountDeleteHandler({
  allowedOrigins,
  async getUserId(token) {
    const { data, error } = await admin.auth.getUser(token);
    return error || !data.user ? null : data.user.id;
  },
  async getEntitlement(userId) {
    const { data, error } = await admin
      .from("entitlements")
      .select("whop_membership_id, status, cancel_at_period_end")
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throw error;
    if (!data) return null;
    const row = data as EntitlementRow;
    const snapshot: EntitlementSnapshot = {
      whopMembershipId: row.whop_membership_id,
      status: row.status,
      cancelAtPeriodEnd: row.cancel_at_period_end,
    };
    return snapshot;
  },
  async cancelMembership(membershipId) {
    await cancelWhopMembership(
      { fetch, baseUrl: whopApiBaseUrl, apiKey: whopApiKey },
      membershipId,
    );
  },
  async listStorageObjects(userId, { limit, offset }) {
    const { data, error } = await admin.storage.from(BUCKET).list(userId, {
      limit,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw error;
    return (data ?? []).map((entry) => ({ name: entry.name }));
  },
  async removeStorageObjects(paths) {
    const { error } = await admin.storage.from(BUCKET).remove(paths);
    if (error) throw error;
  },
  async deleteUser(userId) {
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  },
});

Deno.serve(handler);
