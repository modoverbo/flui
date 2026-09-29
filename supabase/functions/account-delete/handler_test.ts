import { assertEquals } from "jsr:@std/assert@1.0.19";
import { CancelMembershipError } from "../_shared/whop_membership.ts";
import {
  type AccountDeleteDeps,
  createAccountDeleteHandler,
  type EntitlementSnapshot,
  type StorageObjectEntry,
} from "./handler.ts";

const USER_ID = "5b7f6a3e-2d1c-4b9a-8f0e-1a2b3c4d5e6f";
const OTHER_USER_ID = "9999aaaa-bbbb-cccc-dddd-eeeeffff0000";
const ORIGIN = "http://localhost:3000";
const MEMBERSHIP_ID = "mem_abc123";

const LIVE_ENTITLEMENT: EntitlementSnapshot = {
  whopMembershipId: MEMBERSHIP_ID,
  status: "active",
  cancelAtPeriodEnd: false,
};

/** Records call order and arguments across every dependency so ordering and
 * short-circuiting can be asserted precisely. */
function setup(overrides: Partial<AccountDeleteDeps> = {}) {
  const calls: string[] = [];
  const cancelMembershipCalls: string[] = [];
  const listStorageObjectsCalls: { limit: number; offset: number }[] = [];
  const removeStorageObjectsCalls: string[][] = [];
  const deleteUserCalls: string[] = [];
  let entitlement: EntitlementSnapshot | null = LIVE_ENTITLEMENT;
  // Non-empty by default so the "happy path" test exercises every step,
  // including a real removeStorageObjects call; tests that care about the
  // empty-prefix (idempotent retry) case override this explicitly.
  let storagePages: StorageObjectEntry[][] = [[{ name: "attempt-1.wav" }]];

  const deps: AccountDeleteDeps = {
    allowedOrigins: [ORIGIN],
    getUserId: (token) => Promise.resolve(token === "valid-jwt" ? USER_ID : null),
    getEntitlement: (userId) => {
      calls.push("getEntitlement");
      return Promise.resolve(userId === USER_ID ? entitlement : null);
    },
    cancelMembership: (membershipId) => {
      calls.push("cancelMembership");
      cancelMembershipCalls.push(membershipId);
      return Promise.resolve();
    },
    listStorageObjects: (userId, options) => {
      calls.push("listStorageObjects");
      listStorageObjectsCalls.push(options);
      const pageIndex = Math.floor(options.offset / 100);
      return Promise.resolve(
        userId === USER_ID ? storagePages[pageIndex] ?? [] : [],
      );
    },
    removeStorageObjects: (paths) => {
      calls.push("removeStorageObjects");
      removeStorageObjectsCalls.push(paths);
      return Promise.resolve();
    },
    deleteUser: (userId) => {
      calls.push("deleteUser");
      deleteUserCalls.push(userId);
      return Promise.resolve();
    },
    ...overrides,
  };

  return {
    handler: createAccountDeleteHandler(deps),
    calls,
    cancelMembershipCalls,
    listStorageObjectsCalls,
    removeStorageObjectsCalls,
    deleteUserCalls,
    setEntitlement: (value: EntitlementSnapshot | null) => {
      entitlement = value;
    },
    setStoragePages: (pages: StorageObjectEntry[][]) => {
      storagePages = pages;
    },
  };
}

function post(body?: unknown, headers: Record<string, string> = {}): Request {
  const init: RequestInit = {
    method: "POST",
    headers: { Origin: ORIGIN, Authorization: "Bearer valid-jwt", ...headers },
  };
  if (body !== undefined) {
    init.headers = { ...init.headers, "Content-Type": "application/json" };
    init.body = JSON.stringify(body);
  }
  return new Request("http://localhost/functions/v1/account-delete", init);
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error.code;
}

Deno.test("OPTIONS preflight from an allowed origin returns 204 with CORS headers", async () => {
  const { handler } = setup();
  const response = await handler(
    new Request("http://localhost", { method: "OPTIONS", headers: { Origin: ORIGIN } }),
  );
  assertEquals(response.status, 204);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), ORIGIN);
});

Deno.test("methods other than POST return 405 and call nothing", async () => {
  const { handler, calls } = setup();
  const response = await handler(
    new Request("http://localhost", { method: "GET", headers: { Origin: ORIGIN } }),
  );
  assertEquals(response.status, 405);
  assertEquals(await errorCode(response), "method_not_allowed");
  assertEquals(calls, []);
});

Deno.test("requests from a foreign origin return 403 and call nothing", async () => {
  const { handler, calls } = setup();
  const response = await handler(post(undefined, { Origin: "https://evil.example" }));
  assertEquals(response.status, 403);
  assertEquals(await errorCode(response), "origin_not_allowed");
  assertEquals(calls, []);
});

Deno.test("missing or invalid bearer token returns 401 and calls nothing (no cancel/storage/deleteUser)", async () => {
  const { handler, calls } = setup();
  const missing = await handler(post(undefined, { Authorization: "" }));
  const invalid = await handler(post(undefined, { Authorization: "Bearer forged" }));
  assertEquals([missing.status, await errorCode(missing)], [401, "unauthorized"]);
  assertEquals([invalid.status, await errorCode(invalid)], [401, "unauthorized"]);
  assertEquals(calls, []);
});

Deno.test("a body field naming another user's id is ignored -- deletion always targets the caller's own uid", async () => {
  const { handler, deleteUserCalls } = setup();
  const response = await handler(post({ userId: OTHER_USER_ID, targetUserId: OTHER_USER_ID }));
  assertEquals(response.status, 200);
  assertEquals(deleteUserCalls, [USER_ID]);
});

Deno.test("entitlement read failure returns 503 and calls nothing else", async () => {
  const { handler, calls } = setup({
    getEntitlement: () => {
      calls.push("getEntitlement");
      return Promise.reject(new Error("db down"));
    },
  });
  const response = await handler(post());
  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), "entitlement_unavailable");
  assertEquals(calls, ["getEntitlement"]);
});

Deno.test(
  "full success path: cancel -> list+remove storage -> delete user, in that exact order",
  async () => {
    const { handler, calls, cancelMembershipCalls, removeStorageObjectsCalls, deleteUserCalls } =
      setup();
    const response = await handler(post());
    assertEquals(response.status, 200);
    assertEquals(await response.json(), { status: "deleted" });
    assertEquals(calls, [
      "getEntitlement",
      "cancelMembership",
      "listStorageObjects",
      "removeStorageObjects",
      "deleteUser",
    ]);
    assertEquals(cancelMembershipCalls, [MEMBERSHIP_ID]);
    assertEquals(removeStorageObjectsCalls, [[`${USER_ID}/attempt-1.wav`]]);
    assertEquals(deleteUserCalls, [USER_ID]);
  },
);

Deno.test("no entitlement row skips the cancel call entirely and proceeds to storage+deleteUser", async () => {
  const { handler, setEntitlement, calls } = setup();
  setEntitlement(null);
  const response = await handler(post());
  assertEquals(response.status, 200);
  assertEquals(calls, [
    "getEntitlement",
    "listStorageObjects",
    "removeStorageObjects",
    "deleteUser",
  ]);
});

Deno.test("a canceled or expired entitlement status skips the cancel call", async () => {
  for (const status of ["canceled", "expired"] as const) {
    const { handler, setEntitlement, calls } = setup();
    setEntitlement({ whopMembershipId: MEMBERSHIP_ID, status, cancelAtPeriodEnd: false });
    const response = await handler(post());
    assertEquals(response.status, 200);
    assertEquals(calls, [
      "getEntitlement",
      "listStorageObjects",
      "removeStorageObjects",
      "deleteUser",
    ]);
  }
});

Deno.test("cancel_at_period_end already true skips the cancel call", async () => {
  const { handler, setEntitlement, calls } = setup();
  setEntitlement({ whopMembershipId: MEMBERSHIP_ID, status: "active", cancelAtPeriodEnd: true });
  const response = await handler(post());
  assertEquals(response.status, 200);
  assertEquals(calls, [
    "getEntitlement",
    "listStorageObjects",
    "removeStorageObjects",
    "deleteUser",
  ]);
});

Deno.test("a live status with no stored membership id fails closed without calling Whop, storage, or deleteUser", async () => {
  const { handler, setEntitlement, calls } = setup();
  setEntitlement({ whopMembershipId: null, status: "trialing", cancelAtPeriodEnd: false });
  const response = await handler(post());
  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "membership_id_missing");
  assertEquals(calls, ["getEntitlement"]);
});

Deno.test(
  "cancellation failing with membership_not_found aborts before storage/deleteUser with a distinct code",
  async () => {
    const { handler, calls } = setup({
      cancelMembership: () => {
        calls.push("cancelMembership");
        return Promise.reject(
          new CancelMembershipError("membership_not_found", 404, "unknown to Whop"),
        );
      },
    });
    const response = await handler(post());
    assertEquals(response.status, 502);
    assertEquals(await errorCode(response), "whop_membership_not_found");
    assertEquals(calls, ["getEntitlement", "cancelMembership"]);
  },
);

Deno.test(
  "cancellation failing with any other reason aborts with billing_unavailable, distinct from membership_not_found",
  async () => {
    for (
      const reason of ["network_error", "timeout", "http_error", "unresolved_conflict"] as const
    ) {
      const { handler, calls } = setup({
        cancelMembership: () => {
          calls.push("cancelMembership");
          return Promise.reject(new CancelMembershipError(reason, undefined, "boom"));
        },
      });
      const response = await handler(post());
      assertEquals(response.status, 503);
      assertEquals(await errorCode(response), "billing_unavailable");
      assertEquals(calls, ["getEntitlement", "cancelMembership"]);
    }
  },
);

Deno.test(
  "cancellation failing leaves the account fully intact: no storage removal, no deleteUser call at all",
  async () => {
    const { handler, calls } = setup({
      cancelMembership: () => {
        calls.push("cancelMembership");
        return Promise.reject(new CancelMembershipError("http_error", 500, "boom"));
      },
    });
    await handler(post());
    assertEquals(calls.includes("listStorageObjects"), false);
    assertEquals(calls.includes("removeStorageObjects"), false);
    assertEquals(calls.includes("deleteUser"), false);
  },
);

Deno.test(
  "storage listing failure (after a successful cancellation) aborts before deleteUser with a retryable error",
  async () => {
    const { handler, calls, deleteUserCalls } = setup({
      listStorageObjects: () => {
        calls.push("listStorageObjects");
        return Promise.reject(new Error("storage down"));
      },
    });
    const response = await handler(post());
    assertEquals(response.status, 502);
    assertEquals(await errorCode(response), "storage_cleanup_failed");
    assertEquals(calls, ["getEntitlement", "cancelMembership", "listStorageObjects"]);
    assertEquals(deleteUserCalls, []);
  },
);

Deno.test(
  "storage removal failure (after listing succeeds) aborts before deleteUser with a retryable error",
  async () => {
    const { handler, calls, deleteUserCalls, setStoragePages } = setup({
      removeStorageObjects: () => {
        calls.push("removeStorageObjects");
        return Promise.reject(new Error("remove failed"));
      },
    });
    setStoragePages([[{ name: "attempt-1.wav" }]]);
    const response = await handler(post());
    assertEquals(response.status, 502);
    assertEquals(await errorCode(response), "storage_cleanup_failed");
    assertEquals(calls, [
      "getEntitlement",
      "cancelMembership",
      "listStorageObjects",
      "removeStorageObjects",
    ]);
    assertEquals(deleteUserCalls, []);
  },
);

Deno.test("deleteUser failure returns a distinct retryable error after cancel and storage already succeeded", async () => {
  const { handler, calls } = setup({
    deleteUser: () => {
      calls.push("deleteUser");
      return Promise.reject(new Error("auth admin down"));
    },
  });
  const response = await handler(post());
  assertEquals(response.status, 502);
  assertEquals(await errorCode(response), "account_deletion_failed");
  assertEquals(calls, [
    "getEntitlement",
    "cancelMembership",
    "listStorageObjects",
    "removeStorageObjects",
    "deleteUser",
  ]);
});

Deno.test(
  "lists every storage page under the caller's prefix until exhausted, then removes the full set (defense in depth, U22b.5)",
  async () => {
    const fullPage: StorageObjectEntry[] = Array.from({ length: 100 }, (_, i) => ({
      name: `attempt-${i}.wav`,
    }));
    const lastPage: StorageObjectEntry[] = [{ name: "attempt-final.wav" }];
    const { handler, listStorageObjectsCalls, removeStorageObjectsCalls, setStoragePages } =
      setup();
    setStoragePages([fullPage, fullPage, lastPage]);

    const response = await handler(post());

    assertEquals(response.status, 200);
    assertEquals(
      listStorageObjectsCalls,
      [
        { limit: 100, offset: 0 },
        { limit: 100, offset: 100 },
        { limit: 100, offset: 200 },
      ],
    );
    const removedPaths = removeStorageObjectsCalls.flat();
    assertEquals(removedPaths.length, 201);
    assertEquals(removedPaths[0], `${USER_ID}/attempt-0.wav`);
    assertEquals(removedPaths.at(-1), `${USER_ID}/attempt-final.wav`);
  },
);

Deno.test(
  "an empty storage prefix (idempotent retry after a prior full run) still succeeds without an unnecessary removeStorageObjects call",
  async () => {
    const {
      handler,
      calls,
      listStorageObjectsCalls,
      removeStorageObjectsCalls,
      deleteUserCalls,
      setStoragePages,
    } = setup();
    setStoragePages([[]]);
    const response = await handler(post());
    assertEquals(response.status, 200);
    assertEquals(listStorageObjectsCalls, [{ limit: 100, offset: 0 }]);
    assertEquals(calls.includes("removeStorageObjects"), false);
    assertEquals(removeStorageObjectsCalls, []);
    assertEquals(deleteUserCalls, [USER_ID]);
  },
);
