import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.19";
import { Webhook } from "npm:standardwebhooks@1.1.1";
import { signWebhook, verifyWebhook, WebhookVerificationError } from "./standard_webhooks.ts";

// Whop signing secrets look like `ws_...` and are used as raw key bytes.
const SECRET = "ws_test_1234567890abcdefghijklmnopqrstuvwxyz";
const BODY = JSON.stringify({ id: "msg_1", type: "membership.activated", data: { id: "mem_1" } });
const NOW = new Date("2026-09-13T12:00:00Z");
const NOW_SECONDS = Math.floor(NOW.getTime() / 1000);

function headers(id: string, timestamp: number, signature: string): Headers {
  return new Headers({
    "webhook-id": id,
    "webhook-timestamp": String(timestamp),
    "webhook-signature": signature,
  });
}

Deno.test("verifyWebhook accepts a signature produced the way Whop's SDK does it (standardwebhooks with btoa(secret))", async () => {
  const reference = new Webhook(btoa(SECRET));
  const signature = reference.sign("msg_1", NOW, BODY);
  await verifyWebhook({
    secret: SECRET,
    headers: headers("msg_1", NOW_SECONDS, signature),
    body: BODY,
    now: NOW,
  });
});

Deno.test("signWebhook matches the standardwebhooks reference implementation", async () => {
  const reference = new Webhook(btoa(SECRET));
  assertEquals(
    await signWebhook(SECRET, "msg_2", NOW_SECONDS, BODY),
    reference.sign("msg_2", NOW, BODY),
  );
});

Deno.test("verifyWebhook accepts when any of several signatures matches", async () => {
  const good = await signWebhook(SECRET, "msg_3", NOW_SECONDS, BODY);
  await verifyWebhook({
    secret: SECRET,
    headers: headers("msg_3", NOW_SECONDS, `v1,AAAA ${good} v2,ignored`),
    body: BODY,
    now: NOW,
  });
});

Deno.test("verifyWebhook rejects a tampered body", async () => {
  const signature = await signWebhook(SECRET, "msg_4", NOW_SECONDS, BODY);
  await assertRejects(
    () =>
      verifyWebhook({
        secret: SECRET,
        headers: headers("msg_4", NOW_SECONDS, signature),
        body: BODY.replace("activated", "deactivated"),
        now: NOW,
      }),
    WebhookVerificationError,
  );
});

Deno.test("verifyWebhook rejects a signature made with another secret", async () => {
  const signature = await signWebhook("ws_other_secret", "msg_5", NOW_SECONDS, BODY);
  await assertRejects(
    () =>
      verifyWebhook({
        secret: SECRET,
        headers: headers("msg_5", NOW_SECONDS, signature),
        body: BODY,
        now: NOW,
      }),
    WebhookVerificationError,
  );
});

Deno.test("verifyWebhook rejects when a signature is reused with another webhook id", async () => {
  const signature = await signWebhook(SECRET, "msg_6", NOW_SECONDS, BODY);
  await assertRejects(
    () =>
      verifyWebhook({
        secret: SECRET,
        headers: headers("msg_other", NOW_SECONDS, signature),
        body: BODY,
        now: NOW,
      }),
    WebhookVerificationError,
  );
});

Deno.test("verifyWebhook rejects missing headers", async () => {
  await assertRejects(
    () => verifyWebhook({ secret: SECRET, headers: new Headers(), body: BODY, now: NOW }),
    WebhookVerificationError,
    "Missing required headers",
  );
});

Deno.test("verifyWebhook rejects timestamps outside the five-minute tolerance", async () => {
  for (const timestamp of [NOW_SECONDS - 301, NOW_SECONDS + 301]) {
    const signature = await signWebhook(SECRET, "msg_7", timestamp, BODY);
    await assertRejects(
      () =>
        verifyWebhook({
          secret: SECRET,
          headers: headers("msg_7", timestamp, signature),
          body: BODY,
          now: NOW,
        }),
      WebhookVerificationError,
      "timestamp",
    );
  }
});

Deno.test("verifyWebhook accepts timestamps inside the tolerance", async () => {
  const timestamp = NOW_SECONDS - 299;
  const signature = await signWebhook(SECRET, "msg_8", timestamp, BODY);
  await verifyWebhook({
    secret: SECRET,
    headers: headers("msg_8", timestamp, signature),
    body: BODY,
    now: NOW,
  });
});

Deno.test("verifyWebhook rejects a non-numeric timestamp", async () => {
  await assertRejects(
    () =>
      verifyWebhook({
        secret: SECRET,
        headers: headers("msg_9", NaN, "v1,AAAA"),
        body: BODY,
        now: NOW,
      }),
    WebhookVerificationError,
  );
});

Deno.test("verifyWebhook refuses to run without a secret", async () => {
  await assertRejects(
    () =>
      verifyWebhook({
        secret: "",
        headers: headers("msg_10", NOW_SECONDS, "v1,AAAA"),
        body: BODY,
        now: NOW,
      }),
    Error,
    "secret",
  );
});
