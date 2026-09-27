import { errorResponse, HttpError, jsonResponse } from "../_shared/http.ts";

/** Header carrying the shared retention secret (compared in constant time). */
export const RETENTION_SECRET_HEADER = "x-audio-retention-secret";

/** Bounds how many rows/objects one invocation acts on, matching the DB selection functions' default. */
export const DEFAULT_BATCH_SIZE = 500;

export interface ExpiredMilestoneAudio {
  attemptId: string;
  userId: string;
  audioPath: string;
}

export interface OrphanedAudioObject {
  objectName: string;
}

export interface RetentionBucketCounts {
  seen: number;
  /** Milestones actually expired, or orphans actually removed. */
  acted: number;
  failed: number;
}

export interface AudioRetentionResult {
  dryRun: boolean;
  expiredMilestones: RetentionBucketCounts;
  orphans: RetentionBucketCounts;
}

export interface AudioRetentionDeps {
  /**
   * Configured shared secret. Undefined/empty means audio retention is
   * misconfigured -- every request refuses with 503, and nothing is ever
   * selected or mutated. Never falls back to "no secret means open".
   */
  secret: string | undefined;
  /** Selects weekly-milestone attempts whose stored audio is older than 90 days (never diagnosis baselines; decision #430). */
  selectExpiredMilestones(batchSize: number): Promise<ExpiredMilestoneAudio[]>;
  /** Selects speaking-audio objects unreferenced by a stored row, older than the 24h grace period (decision #522). */
  selectOrphanedObjects(batchSize: number): Promise<OrphanedAudioObject[]>;
  /**
   * Marks exactly one attempt's row stored -> deleted, guarded by both id and
   * the exact audio_path just selected. Returns false when the guarded
   * update matched no row (e.g. the row already changed since selection) --
   * the caller must then NOT remove the storage object.
   */
  markAttemptDeleted(attemptId: string, audioPath: string): Promise<boolean>;
  /** Removes one object from the speaking-audio bucket. Idempotent: an already-missing object is not an error. */
  removeObject(objectName: string): Promise<void>;
  log?: (message: string, details?: Record<string, unknown>) => void;
}

function timingSafeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  let diff = left.length ^ right.length;
  for (let i = 0; i < Math.max(left.length, right.length); i++) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * Extensions the DB write-side guard trigger accepts for a canonical
 * speaking_attempts audio_path (see the `in (...)` list in
 * speaking_attempts_guard_audio, migration
 * 20260913121100_speaking_attempts_integrity.sql). Kept in sync with that
 * list so this Edge Function's own ownership check never accepts a shape
 * the DB trigger would reject going forward.
 */
const CANONICAL_AUDIO_EXTENSIONS = ["wav", "webm", "ogg", "mp4"] as const;

/**
 * Defense in depth (security review finding F1, hardened further per H1):
 * even though DB selection is scoped to a row's own canonical
 * <user_id>/<id>.<ext> path, this Edge Function independently verifies
 * ownership before ever calling removeObject with service-role
 * credentials -- it never trusts a selected item's audioPath to already be
 * safe, in case the DB-side guard is ever bypassed, weakened, or acting on
 * pre-fix data.
 *
 * This is an EXACT match against `${userId}/${attemptId}.${ext}` for ext in
 * CANONICAL_AUDIO_EXTENSIONS -- not "starts with the user's folder and the
 * part before the last dot equals the attempt id", which silently accepted
 * any suffix after that last dot (no extension at all, an extension
 * embedding a raw or percent-encoded path separator, or an extension
 * outside the allowed set) as if it were already a validated extension.
 */
function isOwnCanonicalPath(item: ExpiredMilestoneAudio): boolean {
  return CANONICAL_AUDIO_EXTENSIONS.some(
    (ext) => item.audioPath === `${item.userId}/${item.attemptId}.${ext}`,
  );
}

async function processExpiredMilestones(
  deps: Pick<AudioRetentionDeps, "markAttemptDeleted" | "removeObject" | "log">,
  items: ExpiredMilestoneAudio[],
  dryRun: boolean,
  log: NonNullable<AudioRetentionDeps["log"]>,
): Promise<RetentionBucketCounts> {
  if (dryRun) return { seen: items.length, acted: 0, failed: 0 };
  let acted = 0;
  let failed = 0;
  for (const item of items) {
    if (!isOwnCanonicalPath(item)) {
      failed++;
      log(
        "audio-retention: expired-milestone item failed the ownership check, object left in place",
        {
          attemptId: item.attemptId,
        },
      );
      continue;
    }
    try {
      // Row update FIRST, then object removal: an attempt still reachable by
      // the guarded update is the only one whose object may be removed.
      const updated = await deps.markAttemptDeleted(item.attemptId, item.audioPath);
      if (!updated) {
        failed++;
        log("audio-retention: expired-milestone row update matched no row, object left in place", {
          attemptId: item.attemptId,
        });
        continue;
      }
      await deps.removeObject(item.audioPath);
      acted++;
    } catch (error) {
      failed++;
      log("audio-retention: failed to expire milestone audio", {
        attemptId: item.attemptId,
        message: errorMessage(error),
      });
    }
  }
  return { seen: items.length, acted, failed };
}

async function processOrphans(
  deps: Pick<AudioRetentionDeps, "removeObject" | "log">,
  items: OrphanedAudioObject[],
  dryRun: boolean,
  log: NonNullable<AudioRetentionDeps["log"]>,
): Promise<RetentionBucketCounts> {
  if (dryRun) return { seen: items.length, acted: 0, failed: 0 };
  let acted = 0;
  let failed = 0;
  for (const item of items) {
    try {
      await deps.removeObject(item.objectName);
      acted++;
    } catch (error) {
      failed++;
      log("audio-retention: failed to remove orphaned object", {
        objectName: item.objectName,
        message: errorMessage(error),
      });
    }
  }
  return { seen: items.length, acted, failed };
}

/**
 * Daily audio-retention sweep (decisions #430, #522): expires weekly
 * milestone audio older than 90 days (never diagnosis baselines) and
 * reconciles speaking-audio storage orphans older than a 24 h grace period.
 * Invoked only by the scheduled workflow, authenticated with a shared
 * secret compared in constant time -- never a user JWT.
 */
export function createAudioRetentionHandler(
  deps: AudioRetentionDeps,
): (request: Request) => Promise<Response> {
  const log = deps.log ?? ((message, details) => console.error(message, details ?? {}));

  return async (request) => {
    try {
      if (request.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST.");

      if (!deps.secret) {
        throw new HttpError(
          503,
          "access_unavailable",
          "Audio retention is not configured.",
        );
      }
      const provided = request.headers.get(RETENTION_SECRET_HEADER);
      if (!provided || !timingSafeEqual(provided, deps.secret)) {
        throw new HttpError(401, "unauthorized", "Invalid retention secret.");
      }

      const dryRun = new URL(request.url).searchParams.get("dryRun") === "true";

      const expiredItems = await deps.selectExpiredMilestones(DEFAULT_BATCH_SIZE);
      const expiredMilestones = await processExpiredMilestones(deps, expiredItems, dryRun, log);

      const orphanItems = await deps.selectOrphanedObjects(DEFAULT_BATCH_SIZE);
      const orphans = await processOrphans(deps, orphanItems, dryRun, log);

      const result: AudioRetentionResult = { dryRun, expiredMilestones, orphans };
      log("audio-retention run complete", { ...result });
      return jsonResponse(200, result);
    } catch (error) {
      if (error instanceof HttpError) {
        if (error.status >= 500) log("audio-retention failed", { code: error.code });
        return errorResponse(error);
      }
      log("audio-retention unexpected error", { message: errorMessage(error) });
      return errorResponse(new HttpError(500, "internal_error", "Unexpected error."));
    }
  };
}
