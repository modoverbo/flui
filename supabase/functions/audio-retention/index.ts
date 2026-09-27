/**
 * POST /functions/v1/audio-retention  (called only by the daily scheduled
 * workflow; JWT verification disabled -- see supabase/config.toml)
 *
 * Authenticates with AUDIO_RETENTION_SECRET (constant-time header compare,
 * see handler.ts) rather than a user JWT. Secrets: SUPABASE_URL,
 * SUPABASE_SERVICE_ROLE_KEY, AUDIO_RETENTION_SECRET.
 */
import { createClient } from "npm:@supabase/supabase-js@2.116.0";
import { createAudioRetentionHandler } from "./handler.ts";

function required(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

const supabaseUrl = required("SUPABASE_URL");
const serviceRoleKey = required("SUPABASE_SERVICE_ROLE_KEY");
// AUDIO_RETENTION_SECRET is deliberately NOT read through required(): a
// missing secret must make every request refuse with 503 (never run open),
// not crash the function at boot -- see handler.ts's own guard.
const secret = Deno.env.get("AUDIO_RETENTION_SECRET")?.trim() || undefined;

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const BUCKET = "speaking-audio";

interface ExpiredMilestoneRow {
  attempt_id: string;
  user_id: string;
  audio_path: string;
}

interface OrphanedObjectRow {
  object_name: string;
}

const handler = createAudioRetentionHandler({
  secret,
  async selectExpiredMilestones(batchSize) {
    const { data, error } = await admin.rpc("select_expired_milestone_audio", {
      p_batch_size: batchSize,
    });
    if (error) throw error;
    return ((data ?? []) as ExpiredMilestoneRow[]).map((row) => ({
      attemptId: row.attempt_id,
      userId: row.user_id,
      audioPath: row.audio_path,
    }));
  },
  async selectOrphanedObjects(batchSize) {
    const { data, error } = await admin.rpc("select_orphaned_speaking_audio", {
      p_batch_size: batchSize,
    });
    if (error) throw error;
    return ((data ?? []) as OrphanedObjectRow[]).map((row) => ({ objectName: row.object_name }));
  },
  async markAttemptDeleted(attemptId, audioPath) {
    const { data, error } = await admin
      .from("speaking_attempts")
      .update({ audio_status: "deleted" })
      .eq("id", attemptId)
      .eq("audio_status", "stored")
      .eq("audio_path", audioPath)
      .select("id");
    if (error) throw error;
    return (data?.length ?? 0) > 0;
  },
  async removeObject(objectName) {
    const { error } = await admin.storage.from(BUCKET).remove([objectName]);
    if (error) throw error;
  },
});

Deno.serve(handler);
