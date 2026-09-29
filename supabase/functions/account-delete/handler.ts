/**
 * Deletes the CALLER's own account (U22b; decisions #434, #894). Every step
 * fails closed and the exact order below is a safety contract, not an
 * implementation detail: cancel the Whop membership (fail closed) -> wipe
 * every object under `speaking-audio/<uid>/` -> delete the auth user. A
 * failure at any step stops before the next one runs -- the account is only
 * ever deleted once billing is confirmed stopped (or was never live) and
 * storage is confirmed empty.
 *
 * Only the bearer token's own uid is ever a deletion target. The request
 * body is never read for identity, so a client can never ask to delete
 * another account by sending a `userId`/`targetUserId` field.
 */
import { corsHeaders, isOriginAllowed, preflightResponse } from "../_shared/cors.ts";
import { bearerToken, errorResponse, HttpError, jsonResponse } from "../_shared/http.ts";
import { CancelMembershipError } from "../_shared/whop_membership.ts";

/** Whop membership statuses that still renew and therefore still bill (design D22). */
const LIVE_STATUSES = new Set(["trialing", "active", "past_due"]);

/** Page size for listing objects under the caller's storage prefix (U22b.5). */
const LIST_PAGE_SIZE = 100;

/** Batch size for removing listed objects. */
const REMOVE_BATCH_SIZE = 100;

export interface EntitlementSnapshot {
  whopMembershipId: string | null;
  status: "trialing" | "active" | "past_due" | "canceled" | "expired";
  cancelAtPeriodEnd: boolean;
}

export interface StorageObjectEntry {
  name: string;
}

export interface AccountDeleteDeps {
  allowedOrigins: string[];
  /** Resolves the Supabase user id for a JWT, or null when the token is not valid. */
  getUserId(token: string): Promise<string | null>;
  /** Reads the caller's current entitlement row, or null when none exists. Throws on infrastructure failure. */
  getEntitlement(userId: string): Promise<EntitlementSnapshot | null>;
  /**
   * Cancels the Whop membership at the end of its current billing period.
   * Rejects with `CancelMembershipError` (see `_shared/whop_membership.ts`)
   * on any ambiguous or unexpected response -- the caller must abort.
   */
  cancelMembership(membershipId: string): Promise<void>;
  /**
   * Lists one page of objects under `<uid>/` in the speaking-audio bucket.
   * The caller paginates by increasing `offset` until a page shorter than
   * `limit` is returned.
   */
  listStorageObjects(
    userId: string,
    options: { limit: number; offset: number },
  ): Promise<StorageObjectEntry[]>;
  /** Removes the given full object paths. Idempotent: an already-missing object is not an error. */
  removeStorageObjects(paths: string[]): Promise<void>;
  deleteUser(userId: string): Promise<void>;
  log?: (message: string, details?: Record<string, unknown>) => void;
}

/**
 * Maps a rejected `cancelMembership` call to a fail-closed HTTP response.
 * `membership_not_found` gets its own machine code (distinct from every
 * other reason) so the caller can route the user to support rather than a
 * generic "try again" message -- a 404 means the stored id or environment is
 * misconfigured, not that billing was actually resolved.
 */
function cancelErrorToHttpError(error: unknown): HttpError {
  if (error instanceof CancelMembershipError && error.reason === "membership_not_found") {
    return new HttpError(
      502,
      "whop_membership_not_found",
      "Whop does not recognize the stored membership. Contact support before retrying.",
    );
  }
  return new HttpError(
    503,
    "billing_unavailable",
    "Could not confirm the Whop membership cancellation. Try again shortly.",
  );
}

/**
 * Lists every object under `<uid>/` in the speaking-audio bucket, paginating
 * until a page shorter than `LIST_PAGE_SIZE` is returned (U22b.5: defense in
 * depth -- every object is listed, not only ones a `stored` row references,
 * so an orphan left by a failed status update is caught too).
 */
async function listAllObjectPaths(
  deps: Pick<AccountDeleteDeps, "listStorageObjects">,
  userId: string,
): Promise<string[]> {
  const paths: string[] = [];
  let offset = 0;
  let page: StorageObjectEntry[];
  do {
    page = await deps.listStorageObjects(userId, { limit: LIST_PAGE_SIZE, offset });
    for (const entry of page) paths.push(`${userId}/${entry.name}`);
    offset += LIST_PAGE_SIZE;
  } while (page.length === LIST_PAGE_SIZE);
  return paths;
}

/**
 * Removes every listed path in bounded batches. A no-op when `paths` is
 * empty (idempotent retry after a prior full run already emptied the
 * prefix) -- no unnecessary removeStorageObjects call is made.
 */
async function removeAllObjects(
  deps: Pick<AccountDeleteDeps, "removeStorageObjects">,
  paths: string[],
): Promise<void> {
  for (let index = 0; index < paths.length; index += REMOVE_BATCH_SIZE) {
    await deps.removeStorageObjects(paths.slice(index, index + REMOVE_BATCH_SIZE));
  }
}

export function createAccountDeleteHandler(
  deps: AccountDeleteDeps,
): (request: Request) => Promise<Response> {
  const log = deps.log ?? ((message, details) => console.error(message, details ?? {}));

  return async (request) => {
    const origin = request.headers.get("Origin");
    const cors = corsHeaders(origin, deps.allowedOrigins);
    if (request.method === "OPTIONS") return preflightResponse(request, deps.allowedOrigins);

    try {
      if (request.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST.");
      if (origin !== null && !isOriginAllowed(origin, deps.allowedOrigins)) {
        throw new HttpError(403, "origin_not_allowed", "Origin not allowed.");
      }

      const token = bearerToken(request.headers.get("Authorization"));
      const userId = token ? await deps.getUserId(token) : null;
      if (!userId) throw new HttpError(401, "unauthorized", "Sign in to delete your account.");

      let entitlement: EntitlementSnapshot | null;
      try {
        entitlement = await deps.getEntitlement(userId);
      } catch {
        throw new HttpError(
          503,
          "entitlement_unavailable",
          "Could not verify your billing status. Try again shortly.",
        );
      }

      if (
        entitlement !== null && LIVE_STATUSES.has(entitlement.status) &&
        !entitlement.cancelAtPeriodEnd
      ) {
        const membershipId = entitlement.whopMembershipId;
        if (!membershipId) {
          throw new HttpError(
            500,
            "membership_id_missing",
            "Your account may still be billed and cannot be deleted automatically. Contact support.",
          );
        }
        try {
          await deps.cancelMembership(membershipId);
        } catch (error) {
          throw cancelErrorToHttpError(error);
        }
      }

      let paths: string[];
      try {
        paths = await listAllObjectPaths(deps, userId);
        await removeAllObjects(deps, paths);
      } catch {
        throw new HttpError(
          502,
          "storage_cleanup_failed",
          "Could not remove your stored audio. Try again shortly.",
        );
      }

      try {
        await deps.deleteUser(userId);
      } catch {
        throw new HttpError(
          502,
          "account_deletion_failed",
          "Could not delete your account. Try again shortly.",
        );
      }

      return jsonResponse(200, { status: "deleted" }, cors);
    } catch (error) {
      if (error instanceof HttpError) {
        if (error.status >= 500) log("account-delete failed", { code: error.code });
        return errorResponse(error, cors);
      }
      log("account-delete unexpected error");
      return errorResponse(new HttpError(500, "internal_error", "Unexpected error."), cors);
    }
  };
}
