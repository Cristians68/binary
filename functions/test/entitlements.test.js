const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const { purchaseStore } = require("./purchase_store");

function stub(id, exports) {
  const file = require.resolve(id, { paths: [path.join(__dirname, "..")] });
  require.cache[file] = { id: file, filename: file, loaded: true, exports };
}
function harness() {
  const store = purchaseStore();
  const refreshed = [];
  const prepared = [];
  let failUid;
  const missing = new Set();
  stub("firebase-functions/v2/https", {
    onRequest: (_, handler) => handler,
    onCall: (options, handler) => handler || options,
    HttpsError: class extends Error { constructor(code, message) { super(message); this.code = code; } },
  });
  stub("firebase-functions/params", { defineSecret: (name) => ({ value: () => name === "REVENUECAT_WEBHOOK_SECRET" ? "secret" : "sk_test" }) });
  stub("firebase-functions", { logger: { error() {}, warn() {}, info() {} } });
  const firestore = () => store.db;
  firestore.FieldValue = { serverTimestamp: () => "now" };
  stub("firebase-admin", {
    firestore,
    auth: () => ({ getUser: async (uid) => {
      if (missing.has(uid)) throw Object.assign(new Error("gone"), { code: "auth/user-not-found" });
      return { uid };
    } }),
  });
  stub("./purchase_reconciliation", { createPurchaseService: () => ({
    refresh: async (uid) => { refreshed.push(uid); if (uid === failUid) throw new Error("temporary"); return {}; },
    prepare: async (uid, data) => { prepared.push({ uid, data }); return { ok: true }; },
  }) });
  delete require.cache[require.resolve("../entitlements")];
  const handlers = require("../entitlements");
  return { ...store, ...handlers, refreshed, prepared, missing,
    fail: (uid) => { failUid = uid; },
    deliver: async (event, { method = "POST", secret = "secret" } = {}) => {
      const response = { status(code) { this.code = code; return this; }, send(body) { this.body = body; return this; } };
      await handlers.revenueCatWebhook({ method, get: () => secret, body: { event } }, response);
      return response;
    },
  };
}
const event = (type = "NON_RENEWING_PURCHASE") => ({ id: "event-1", type, app_user_id: "u1", product_id: "binary_course_itsm" });

test("webhook rejects unauthorized, non-POST and missing-ID events before work", async () => {
  const h = harness();
  assert.equal((await h.deliver(event(), { secret: "wrong" })).code, 401);
  assert.equal((await h.deliver(event(), { method: "GET" })).code, 405);
  assert.equal((await h.deliver({ type: "CANCELLATION", app_user_id: "u1" })).code, 400);
  assert.deepEqual(h.refreshed, []);
});

test("a failed refresh does not consume the event and its retry completes", async () => {
  const h = harness();
  h.fail("u1");
  assert.equal((await h.deliver(event())).code, 500);
  assert.equal(h.docs.size, 0);
  h.fail(null);
  assert.equal((await h.deliver(event())).code, 200);
  assert.equal(h.docs.size, 1);
  assert.equal((await h.deliver(event())).body, "Duplicate ignored");
  assert.deepEqual(h.refreshed, ["u1", "u1"]);
});

test("TRANSFER without app_user_id reconciles both former and new owners", async () => {
  const h = harness();
  const transferred = { id: "transfer-1", type: "TRANSFER",
    transferred_from: ["u1", "$RCAnonymousID:old"], transferred_to: ["u2", "u2"] };
  assert.equal((await h.deliver(transferred)).code, 200);
  assert.deepEqual(h.refreshed, ["u1", "u2"]);
});

test("partial transfer failure retries both accounts instead of losing the second owner", async () => {
  const h = harness();
  h.fail("u2");
  const transfer = { id: "transfer-1", type: "TRANSFER", transferred_from: ["u1"], transferred_to: ["u2"] };
  assert.equal((await h.deliver(transfer)).code, 500);
  assert.equal(h.docs.size, 0);
  h.fail(null);
  assert.equal((await h.deliver(transfer)).code, 200);
  assert.deepEqual(h.refreshed, ["u1", "u2", "u1", "u2"]);
});

test("refund and pause events reconcile current ownership rather than blindly revoke everything", async () => {
  for (const type of ["CANCELLATION", "EXPIRATION", "SUBSCRIPTION_PAUSED", "REFUND_REVERSED"]) {
    const h = harness();
    assert.equal((await h.deliver(event(type))).code, 200);
    assert.deepEqual(h.refreshed, ["u1"]);
    assert.equal(h.docs.has("users/u1"), false, "only the reconciler may change access");
  }
});

test("known aliases are reconciled once and deleted accounts are skipped", async () => {
  const h = harness();
  h.missing.add("deleted");
  await h.deliver({ ...event(), original_app_user_id: "u1", aliases: ["u1", "u2", "deleted", "$RCAnonymousID:x"] });
  assert.deepEqual(h.refreshed, ["u1", "u2"]);
});

test("callables use the verified Firebase identity, never a payload's uid", async () => {
  const h = harness();
  await assert.rejects(h.refreshEntitlement({ data: { uid: "victim" } }), { code: "unauthenticated" });
  await h.refreshEntitlement({ auth: { uid: "signed-in" }, data: { uid: "victim" } });
  assert.deepEqual(h.refreshed, ["signed-in"]);
  await h.setPendingPurchase({ auth: { uid: "signed-in" }, data: { uid: "victim", productId: "binary_bundle_all" } });
  assert.equal(h.prepared[0].uid, "signed-in");
});

test("a deleted account cannot recreate its purchase data with an old ID token", async () => {
  const h = harness();
  h.missing.add("deleted");
  await assert.rejects(h.refreshEntitlement({ auth: { uid: "deleted" } }), { code: "unauthenticated" });
  assert.deepEqual(h.refreshed, []);
});
