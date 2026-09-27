import { assertEquals } from "jsr:@std/assert@1.0.19";
import {
  type AudioRetentionDeps,
  createAudioRetentionHandler,
  type ExpiredMilestoneAudio,
  type OrphanedAudioObject,
  RETENTION_SECRET_HEADER,
} from "./handler.ts";

const SECRET = "retention-test-secret";

function setup(overrides: Partial<AudioRetentionDeps> = {}) {
  const calls: string[] = [];
  const markAttemptDeletedResults = new Map<string, boolean | Error>();
  const removeObjectFailures = new Set<string>();

  const baseDeps: AudioRetentionDeps = {
    secret: SECRET,
    selectExpiredMilestones: () => Promise.resolve([]),
    selectOrphanedObjects: () => Promise.resolve([]),
    markAttemptDeleted(attemptId, audioPath) {
      calls.push(`markAttemptDeleted:${attemptId}:${audioPath}`);
      const outcome = markAttemptDeletedResults.get(attemptId);
      if (outcome instanceof Error) return Promise.reject(outcome);
      return Promise.resolve(outcome ?? true);
    },
    removeObject(objectName) {
      calls.push(`removeObject:${objectName}`);
      if (removeObjectFailures.has(objectName)) {
        return Promise.reject(new Error("storage remove failed"));
      }
      return Promise.resolve();
    },
    ...overrides,
  };

  return {
    handler: createAudioRetentionHandler(baseDeps),
    calls,
    markAttemptDeletedResults,
    removeObjectFailures,
  };
}

function post(headers: Record<string, string> = {}, search = "") {
  return new Request(`http://localhost/functions/v1/audio-retention${search}`, {
    method: "POST",
    headers,
  });
}

function milestone(
  attemptId: string,
  userId = "u1",
  audioPath = `${userId}/${attemptId}.wav`,
): ExpiredMilestoneAudio {
  return { attemptId, userId, audioPath };
}

function orphan(objectName: string): OrphanedAudioObject {
  return { objectName };
}

Deno.test("auth: missing header is rejected with 401, no selection is ever attempted", async () => {
  const selectCalls: string[] = [];
  const { handler } = setup({
    selectExpiredMilestones: () => {
      selectCalls.push("expired");
      return Promise.resolve([]);
    },
    selectOrphanedObjects: () => {
      selectCalls.push("orphans");
      return Promise.resolve([]);
    },
  });
  const response = await handler(post());
  assertEquals(response.status, 401);
  assertEquals(selectCalls, []);
});

Deno.test("auth: wrong secret is rejected with 401", async () => {
  const { handler } = setup();
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: "not-the-secret" }));
  assertEquals(response.status, 401);
});

Deno.test("auth: correct secret is accepted", async () => {
  const { handler } = setup();
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  assertEquals(response.status, 200);
});

Deno.test("auth: a missing configured secret refuses with 503, never runs open, even with a header present", async () => {
  const selectCalls: string[] = [];
  const { handler } = setup({
    secret: undefined,
    selectExpiredMilestones: () => {
      selectCalls.push("expired");
      return Promise.resolve([]);
    },
    selectOrphanedObjects: () => {
      selectCalls.push("orphans");
      return Promise.resolve([]);
    },
  });
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: "anything-at-all" }));
  assertEquals(response.status, 503);
  assertEquals(selectCalls, [], "misconfiguration must never fall through to a selection call");
});

Deno.test("only method POST is accepted", async () => {
  const { handler } = setup();
  const response = await handler(
    new Request("http://localhost/functions/v1/audio-retention", {
      method: "GET",
      headers: { [RETENTION_SECRET_HEADER]: SECRET },
    }),
  );
  assertEquals(response.status, 405);
});

Deno.test("selection results are acted on exactly: row update runs before object removal, in order", async () => {
  const { handler, calls } = setup({
    selectExpiredMilestones: () => Promise.resolve([milestone("a1")]),
  });
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  assertEquals(response.status, 200);
  assertEquals(calls, ["markAttemptDeleted:a1:u1/a1.wav", "removeObject:u1/a1.wav"]);
});

Deno.test("a row-update failure (guarded update matched no row) skips object removal entirely", async () => {
  const { handler, calls, markAttemptDeletedResults } = setup({
    selectExpiredMilestones: () => Promise.resolve([milestone("a1")]),
  });
  markAttemptDeletedResults.set("a1", false);
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  const body = await response.json();
  assertEquals(
    calls,
    ["markAttemptDeleted:a1:u1/a1.wav"],
    "removeObject must never run after a failed guarded update",
  );
  assertEquals(body.expiredMilestones, { seen: 1, acted: 0, failed: 1 });
});

Deno.test("a row-update that throws also skips object removal and is counted as failed", async () => {
  const { handler, calls, markAttemptDeletedResults } = setup({
    selectExpiredMilestones: () => Promise.resolve([milestone("a1")]),
  });
  markAttemptDeletedResults.set("a1", new Error("db unavailable"));
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  const body = await response.json();
  assertEquals(calls, ["markAttemptDeleted:a1:u1/a1.wav"]);
  assertEquals(body.expiredMilestones, { seen: 1, acted: 0, failed: 1 });
});

Deno.test("per-item failures never abort the batch: the remaining expired-milestone items still process", async () => {
  const { handler, calls, markAttemptDeletedResults } = setup({
    selectExpiredMilestones: () =>
      Promise.resolve([milestone("a1"), milestone("a2"), milestone("a3")]),
  });
  markAttemptDeletedResults.set("a2", new Error("transient failure"));
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  const body = await response.json();
  assertEquals(calls, [
    "markAttemptDeleted:a1:u1/a1.wav",
    "removeObject:u1/a1.wav",
    "markAttemptDeleted:a2:u1/a2.wav",
    "markAttemptDeleted:a3:u1/a3.wav",
    "removeObject:u1/a3.wav",
  ]);
  assertEquals(body.expiredMilestones, { seen: 3, acted: 2, failed: 1 });
});

Deno.test("per-item failures never abort the orphan batch either", async () => {
  const { handler, calls, removeObjectFailures } = setup({
    selectOrphanedObjects: () =>
      Promise.resolve([orphan("o1.wav"), orphan("o2.wav"), orphan("o3.wav")]),
  });
  removeObjectFailures.add("o2.wav");
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  const body = await response.json();
  assertEquals(calls, ["removeObject:o1.wav", "removeObject:o2.wav", "removeObject:o3.wav"]);
  assertEquals(body.orphans, { seen: 3, acted: 2, failed: 1 });
});

Deno.test("orphans are only ever removed, never trigger a row update", async () => {
  const { handler, calls } = setup({
    selectOrphanedObjects: () => Promise.resolve([orphan("o1.wav")]),
  });
  await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  assertEquals(calls, ["removeObject:o1.wav"]);
});

Deno.test("the function only acts on exactly what selection returned, nothing else", async () => {
  const { handler, calls } = setup({
    selectExpiredMilestones: () => Promise.resolve([milestone("expired-only")]),
    selectOrphanedObjects: () => Promise.resolve([orphan("orphan-only.wav")]),
  });
  await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  assertEquals(calls, [
    "markAttemptDeleted:expired-only:u1/expired-only.wav",
    "removeObject:u1/expired-only.wav",
    "removeObject:orphan-only.wav",
  ]);
});

Deno.test("dry-run mode selects but never mutates, and reports seen counts with zero acted/failed", async () => {
  const { handler, calls } = setup({
    selectExpiredMilestones: () => Promise.resolve([milestone("a1")]),
    selectOrphanedObjects: () => Promise.resolve([orphan("o1.wav")]),
  });
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }, "?dryRun=true"));
  const body = await response.json();
  assertEquals(calls, [], "dry run must never call markAttemptDeleted or removeObject");
  assertEquals(body.dryRun, true);
  assertEquals(body.expiredMilestones, { seen: 1, acted: 0, failed: 0 });
  assertEquals(body.orphans, { seen: 1, acted: 0, failed: 0 });
});

Deno.test("an empty selection on both sides returns an all-zero, non-dry-run result", async () => {
  const { handler } = setup();
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  const body = await response.json();
  assertEquals(body, {
    dryRun: false,
    expiredMilestones: { seen: 0, acted: 0, failed: 0 },
    orphans: { seen: 0, acted: 0, failed: 0 },
  });
});

// Security review finding F1 (defense in depth): the Edge Function must
// never trust a selected item's audioPath to already belong to its userId,
// even though the DB selection is now itself scoped to the row's own
// canonical path.
Deno.test("an expired-milestone item whose audioPath belongs to a different user's folder is skipped, never updated or removed", async () => {
  const item: ExpiredMilestoneAudio = {
    attemptId: "a1",
    userId: "victim-uid",
    audioPath: "attacker-uid/a1.wav",
  };
  const { handler, calls } = setup({
    selectExpiredMilestones: () => Promise.resolve([item]),
  });
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  const body = await response.json();
  assertEquals(
    calls,
    [],
    "neither markAttemptDeleted nor removeObject may run for a foreign-owned path",
  );
  assertEquals(body.expiredMilestones, { seen: 1, acted: 0, failed: 1 });
});

Deno.test("an expired-milestone item whose audioPath filename does not match its own attemptId is skipped, never updated or removed", async () => {
  const item: ExpiredMilestoneAudio = {
    attemptId: "a1",
    userId: "u1",
    audioPath: "u1/some-other-attempt.wav",
  };
  const { handler, calls } = setup({
    selectExpiredMilestones: () => Promise.resolve([item]),
  });
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  const body = await response.json();
  assertEquals(
    calls,
    [],
    "a mismatched filename stem must never be acted on, even inside the right folder",
  );
  assertEquals(body.expiredMilestones, { seen: 1, acted: 0, failed: 1 });
});

Deno.test("an expired-milestone item shaped exactly like <userId>/<attemptId>.<ext> is still processed normally", async () => {
  const item = milestone("a1", "u1");
  const { handler, calls } = setup({
    selectExpiredMilestones: () => Promise.resolve([item]),
  });
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  assertEquals(response.status, 200);
  assertEquals(calls, ["markAttemptDeleted:a1:u1/a1.wav", "removeObject:u1/a1.wav"]);
});

// Security review finding F4: the fake previously ignored the audioPath
// argument entirely, so a mutant that reconstructed a path from attemptId
// instead of forwarding the selected item's own audioPath would still pass.
Deno.test("markAttemptDeleted receives the exact selected audioPath, not one derived from the attempt id", async () => {
  const item = milestone("f7c2-attempt", "7b1e2f90-aaaa-bbbb-cccc-111122223333");
  const { handler, calls } = setup({
    selectExpiredMilestones: () => Promise.resolve([item]),
  });
  const response = await handler(post({ [RETENTION_SECRET_HEADER]: SECRET }));
  assertEquals(response.status, 200);
  assertEquals(calls, [
    `markAttemptDeleted:${item.attemptId}:${item.audioPath}`,
    `removeObject:${item.audioPath}`,
  ]);
});
