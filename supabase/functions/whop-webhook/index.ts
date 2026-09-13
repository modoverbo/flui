/**
 * Edge Function entrypoint: wires the webhook handler to the database with the
 * service role. Secrets: WHOP_WEBHOOK_SECRET, optional WHOP_COMPANY_ID.
 */
import { createClient } from "npm:@supabase/supabase-js@2.116.0";
import { readWebhookEnv } from "../_shared/env.ts";
import type { StoredEntitlement } from "../_shared/whop_events.ts";
import { createWebhookHandler, type WebhookRepository } from "./handler.ts";

const env = readWebhookEnv((name) => Deno.env.get(name));

const admin = createClient(env.supabaseUrl, env.serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const FOREIGN_KEY_VIOLATION = "23503";
const UNIQUE_VIOLATION = "23505";

const repository: WebhookRepository = {
  async recordEvent({ webhookId, eventType, payload }) {
    const { data: inserted, error } = await admin
      .from("whop_webhook_events")
      .upsert(
        { webhook_id: webhookId, event_type: eventType, payload },
        { onConflict: "webhook_id", ignoreDuplicates: true },
      )
      .select("webhook_id");
    if (error) throw new Error(`recording webhook failed: ${error.message}`);
    if (inserted && inserted.length > 0) return "new";

    const { data: existing, error: readError } = await admin
      .from("whop_webhook_events")
      .select("processed_at")
      .eq("webhook_id", webhookId)
      .single();
    if (readError) throw new Error(`reading webhook failed: ${readError.message}`);
    return existing.processed_at ? "processed" : "pending";
  },

  async markProcessed(webhookId) {
    const { error } = await admin
      .from("whop_webhook_events")
      .update({ processed_at: new Date().toISOString() })
      .eq("webhook_id", webhookId);
    if (error) throw new Error(`marking webhook processed failed: ${error.message}`);
  },

  async getEntitlement(userId) {
    const { data, error } = await admin
      .from("entitlements")
      .select(
        "user_id, whop_membership_id, whop_plan_id, status, current_period_end, trial_ends_at, cancel_at_period_end, last_event_at",
      )
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throw new Error(`reading entitlement failed: ${error.message}`);
    return data as StoredEntitlement | null;
  },

  async saveEntitlement(row) {
    const { error } = await admin.from("entitlements").upsert(row, { onConflict: "user_id" });
    if (!error) return "saved";
    if (error.code === FOREIGN_KEY_VIOLATION) return "unknown_user";
    if (error.code === UNIQUE_VIOLATION) return "membership_conflict";
    throw new Error(`saving entitlement failed: ${error.message}`);
  },
};

Deno.serve(
  createWebhookHandler({ secret: env.webhookSecret, companyId: env.whopCompanyId, repository }),
);
