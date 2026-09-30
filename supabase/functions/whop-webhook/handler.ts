/**
 * POST /functions/v1/whop-webhook  (called by Whop; JWT verification disabled)
 *
 * 1. Verify the Standard Webhooks signature with WHOP_WEBHOOK_SECRET (401 otherwise).
 * 2. Record the event by `webhook-id` (idempotency; Whop delivers at least once), storing only a
 *    minimized payload (ids, status, app user id) so no buyer PII is kept.
 * 3. Map membership events to `entitlements` (see _shared/whop_events.ts).
 * 4. Answer 200 for anything handled or deliberately ignored; 500 on storage
 *    failures so that Whop retries (the event stays pending and is reprocessed).
 *
 * Response bodies: { status: "applied" | "duplicate" } | { status: "ignored" | "skipped", reason }.
 */
import { errorResponse, HttpError, jsonResponse } from "../_shared/http.ts";
import { verifyWebhook, WebhookVerificationError } from "../_shared/standard_webhooks.ts";
import {
  decideEntitlementWrite,
  type EntitlementRow,
  entitlementUpdateFromEvent,
  isForeignAccount,
  minimizeWhopPayload,
  parseWhopEnvelope,
  type StoredEntitlement,
} from "../_shared/whop_events.ts";

export interface WebhookRepository {
  /** Stores the event if new. Returns whether it is new, stored but unprocessed, or already processed. */
  recordEvent(
    event: { webhookId: string; eventType: string; payload: unknown },
  ): Promise<"new" | "pending" | "processed">;
  markProcessed(webhookId: string): Promise<void>;
  getEntitlement(userId: string): Promise<StoredEntitlement | null>;
  /** Upserts by user_id. Reports constraint problems that retrying cannot fix. */
  saveEntitlement(row: EntitlementRow): Promise<"saved" | "unknown_user" | "membership_conflict">;
}

export interface WebhookHandlerDeps {
  secret: string;
  companyId?: string;
  repository: WebhookRepository;
  now?: () => Date;
  log?: (message: string, details?: Record<string, unknown>) => void;
}

export function createWebhookHandler(
  deps: WebhookHandlerDeps,
): (request: Request) => Promise<Response> {
  const now = deps.now ?? (() => new Date());
  const log = deps.log ?? ((message, details) => console.log(message, details ?? {}));
  const { repository } = deps;

  return async (request) => {
    if (request.method !== "POST") {
      return errorResponse(new HttpError(405, "method_not_allowed", "Use POST."));
    }

    const body = await request.text();
    try {
      await verifyWebhook({ secret: deps.secret, headers: request.headers, body, now: now() });
    } catch (error) {
      if (error instanceof WebhookVerificationError) {
        log("whop-webhook rejected signature", { reason: error.message });
        return errorResponse(new HttpError(401, "invalid_signature", "Invalid webhook signature."));
      }
      throw error;
    }

    let payload: unknown;
    try {
      payload = JSON.parse(body);
    } catch {
      return errorResponse(new HttpError(400, "invalid_payload", "Body is not valid JSON."));
    }

    const webhookId = request.headers.get("webhook-id") as string;
    try {
      const envelope = parseWhopEnvelope(payload);

      const recorded = await repository.recordEvent({
        webhookId,
        eventType: envelope.type,
        // Never the raw body: it carries the buyer's identity and outlives account deletion.
        payload: minimizeWhopPayload(envelope),
      });
      if (recorded === "processed") {
        return jsonResponse(200, { status: "duplicate" });
      }

      const finish = async (result: Record<string, string>) => {
        await repository.markProcessed(webhookId);
        log("whop-webhook handled", { webhookId, type: envelope.type, ...result });
        return jsonResponse(200, result);
      };

      if (isForeignAccount(envelope, deps.companyId)) {
        return await finish({ status: "ignored", reason: "foreign_account" });
      }

      const mapping = entitlementUpdateFromEvent(envelope, now());
      if (mapping.kind === "ignore") {
        return await finish({ status: "ignored", reason: mapping.reason });
      }

      // TODO(trial-reminder): on membership.trial_ending_soon, send the user a reminder
      // (email) before the first charge. Required for consumer transparency; see
      // docs/adr/0004-whop-payments-and-entitlements.md. Not implemented in the MVP.

      const decision = decideEntitlementWrite(
        await repository.getEntitlement(mapping.update.userId),
        mapping.update,
      );
      if (decision.kind === "skip") {
        return await finish({ status: "skipped", reason: decision.reason });
      }

      const saved = await repository.saveEntitlement(decision.row);
      if (saved !== "saved") {
        return await finish({ status: "ignored", reason: saved });
      }
      return await finish({ status: "applied" });
    } catch (error) {
      if (error instanceof HttpError) {
        return errorResponse(error);
      }
      log("whop-webhook failed", {
        webhookId,
        message: error instanceof Error ? error.message : String(error),
      });
      return errorResponse(new HttpError(500, "internal_error", "Could not process the webhook."));
    }
  };
}
