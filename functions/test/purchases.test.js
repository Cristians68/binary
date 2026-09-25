const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { purchaseStore } = require("./purchase_store");
const { createPurchaseService, readPurchases } = require("../purchase_reconciliation");
const { checkoutSelection, COURSE_PRODUCTS, BUNDLE4, ALL, LEGACY_SINGLE } = require("../purchase_catalog");
const { fetchCustomer } = require("../revenuecat_client");

const now = Date.parse("2026-09-24T12:00:00Z");
const four = Object.values(COURSE_PRODUCTS).slice(0, 4).sort();
const receipt = (id = "rc-receipt-1", time = now) => ({
  id, store: "app_store", is_sandbox: true, purchase_date: new Date(time).toISOString(),
});
const inventory = (items = {}, time = now) => ({ request_date_ms: time, subscriber: { non_subscriptions: items } });
function harness() {
  const store = purchaseStore();
  let response = inventory();
  let failure;
  const calls = [];
  const service = createPurchaseService({
    db: store.db, serverTimestamp: () => "server-timestamp", now: () => now,
    fetchCustomer: async (uid) => { calls.push(uid); if (failure) throw failure; return response; },
  });
  return { ...store, ...service, calls,
    response: (value) => { response = value; }, failure: (value) => { failure = value; },
    user: (uid = "u1") => store.docs.get(`users/${uid}`),
  };
}

test("every Flutter course has exactly the same server product ID", () => {
  const source = fs.readFileSync(path.join(__dirname, "../../lib/course_catalog.dart"), "utf8");
  const courses = [...source.matchAll(/id: '([^']+)',\s+code: '([^']+)'/g)];
  assert.equal(courses.length, 7);
  assert.deepEqual(Object.fromEntries(courses.map(([, id, code]) => [`binary_course_${code.toLowerCase()}`, id])), COURSE_PRODUCTS);
});

test("checkout rejects unknown, mismatched, duplicate and legacy products", () => {
  for (const choice of [
    {}, { productId: LEGACY_SINGLE, courseId: "itil-v4" },
    { productId: "anything", courseId: "itil-v4" },
    { productId: "binary_course_itsm", courseId: "csm" },
    { productId: BUNDLE4, courseIds: ["csm", "csm", "csm", "csm"] },
    { productId: BUNDLE4, courseIds: [...four.slice(0, 3), "unknown"] },
    { productId: ALL, courseId: "csm" },
  ]) assert.throws(() => checkoutSelection(choice));
});

test("two independently purchased courses both remain accessible", async () => {
  const h = harness();
  h.response(inventory({ binary_course_itsm: [receipt()], binary_course_scrm: [receipt("r2")] }));
  const result = await h.refresh("u1");
  assert.deepEqual(result.purchasedCourseIds, ["csm", "itil-v4"]);
  assert.deepEqual(h.user().purchasedCourseIds, ["csm", "itil-v4"]);
  assert.equal(h.user().subscriptionPlan, "single");
});

test("refunding one course removes only that course, then a full refund clears access", async () => {
  const h = harness();
  h.response(inventory({ binary_course_itsm: [receipt()], binary_course_scrm: [receipt("r2")] }));
  await h.refresh("u1");
  h.response(inventory({ binary_course_scrm: [receipt("r2")] }, now + 1));
  await h.refresh("u1");
  assert.deepEqual(h.user().purchasedCourseIds, ["csm"]);
  assert.equal(h.user().subscribedCourseId, "csm");
  h.response(inventory({}, now + 2));
  await h.refresh("u1");
  assert.equal(h.user().subscriptionPlan, "none");
  assert.equal(h.user().subscribedCourseId, null);
  assert.deepEqual(h.user().bundleCourseIds, []);
});

test("a slower pre-refund response cannot re-grant revoked access", async () => {
  const h = harness();
  await h.refresh("u1");
  h.response(inventory({ [ALL]: [receipt()] }, now - 1));
  assert.equal((await h.refresh("u1")).subscriptionPlan, "none");
  assert.equal(h.user().subscriptionPlan, "none");
});

test("client-written ordering and pending fields cannot affect verification", async () => {
  const h = harness();
  h.docs.set("users/u1", { revenueCatCheckedAtMs: Number.MAX_SAFE_INTEGER,
    pendingBundleCourseIds: four, subscriptionPlan: "all" });
  h.response(inventory({ [BUNDLE4]: [receipt()] }));
  const result = await h.refresh("u1");
  assert.equal(result.subscriptionPlan, "none");
  assert.deepEqual(result.unresolvedProductIds, [BUNDLE4]);
});

test("malformed or failed API responses never revoke a valid purchase", async () => {
  const h = harness();
  h.response(inventory({ [ALL]: [receipt()] }));
  await h.refresh("u1");
  for (const broken of [{}, { subscriber: {} }, inventory({ [ALL]: {} }), inventory({ [ALL]: [{}] })]) {
    h.response(broken);
    await assert.rejects(h.refresh("u1"));
    assert.equal(h.user().subscriptionPlan, "all");
  }
  h.failure(new Error("offline"));
  await assert.rejects(h.refresh("u1"));
  assert.equal(h.user().subscriptionPlan, "all");
});

test("unknown and explicitly refunded products grant nothing", async () => {
  const h = harness();
  h.response(inventory({ unknown: [receipt()], binary_course_itsm: [{ ...receipt(), refunded_at: new Date(now).toISOString() }] }));
  assert.equal((await h.refresh("u1")).subscriptionPlan, "none");
});

test("checkout verifies the backend even for All Courses and does not create intent on failure", async () => {
  const h = harness();
  h.failure(new Error("API unavailable"));
  await assert.rejects(h.prepare("u1", { productId: ALL }));
  assert.deepEqual(h.calls, ["u1"]);
  assert.equal(h.docs.size, 0);
});

test("already owned courses and All Courses are detected before charging again", async () => {
  const h = harness();
  h.response(inventory({ [ALL]: [receipt()] }));
  assert.equal((await h.prepare("u1", { productId: "binary_course_itsm", courseId: "itil-v4" })).alreadyOwned, true);
  assert.equal((await h.prepare("u1", { productId: BUNDLE4, courseIds: four })).alreadyOwned, true);
  assert.equal((await h.refresh("u1")).subscriptionPlan, "all");
});

test("verified bundle binds its four choices and follows the receipt on transfer", async () => {
  const h = harness();
  await h.prepare("u1", { productId: BUNDLE4, courseIds: four });
  h.response(inventory({ [BUNDLE4]: [receipt()] }, now + 1));
  assert.deepEqual((await h.refresh("u1")).purchasedCourseIds, four);
  assert.equal([...h.docs.keys()].filter((key) => key.startsWith("purchase_bindings/")).length, 1);
  h.response(inventory({}, now + 2));
  await h.refresh("u1");
  h.docs.set(`users/u2/purchaseIntents/${BUNDLE4}`, { courseIds: Object.values(COURSE_PRODUCTS).slice(3), createdAtMs: now });
  h.response(inventory({ [BUNDLE4]: [receipt()] }, now + 3));
  assert.deepEqual((await h.refresh("u2")).purchasedCourseIds, four);
  assert.equal(h.user().subscriptionPlan, "none");
  assert.deepEqual(h.user("u2").purchasedCourseIds, four);
});

test("a second bundle checkout cannot change an existing purchase", async () => {
  const h = harness();
  await h.prepare("u1", { productId: BUNDLE4, courseIds: four });
  h.response(inventory({ [BUNDLE4]: [receipt()] }, now + 1));
  await h.refresh("u1");
  await assert.rejects(h.prepare("u1", { productId: BUNDLE4, courseIds: Object.values(COURSE_PRODUCTS).slice(3) }), { code: "failed-precondition" });
  assert.deepEqual(h.user().purchasedCourseIds, four);
});

test("a checkout from a second device cannot replace a pending bundle selection", async () => {
  const h = harness();
  await h.prepare("u1", { productId: BUNDLE4, courseIds: four });
  await assert.rejects(h.prepare("u1", { productId: BUNDLE4, courseIds: Object.values(COURSE_PRODUCTS).slice(3) }), { code: "failed-precondition" });
  assert.deepEqual(h.docs.get(`users/u1/purchaseIntents/${BUNDLE4}`).courseIds, four);
});

test("a recent intent cannot reassign an older unbound receipt", async () => {
  const h = harness();
  h.docs.set(`users/u1/purchaseIntents/${BUNDLE4}`, { courseIds: four, createdAtMs: now });
  h.response(inventory({ [BUNDLE4]: [receipt("old", now - 86400000)] }));
  assert.deepEqual((await h.refresh("u1")).unresolvedProductIds, [BUNDLE4]);
  assert.equal(h.user().subscriptionPlan, "none");
});

test("a failed transaction creates neither a binding nor an entitlement; retry recovers", async () => {
  const h = harness();
  await h.prepare("u1", { productId: BUNDLE4, courseIds: four });
  h.response(inventory({ [BUNDLE4]: [receipt()] }, now + 1));
  h.setFailCommit(true);
  await assert.rejects(h.refresh("u1"));
  assert.equal(h.user().subscriptionPlan, "none");
  assert.equal([...h.docs.keys()].some((key) => key.startsWith("purchase_bindings/")), false);
  h.setFailCommit(false);
  assert.deepEqual((await h.refresh("u1")).purchasedCourseIds, four);
});

test("legacy single-course receipts restore only their previously verified binding", async () => {
  const h = harness();
  const response = inventory({ [LEGACY_SINGLE]: [receipt()] });
  const key = readPurchases(response).purchases[0].key;
  h.docs.set(`purchase_bindings/${key}`, { productId: LEGACY_SINGLE, courseIds: ["csm"] });
  h.response(response);
  assert.deepEqual((await h.refresh("u1")).purchasedCourseIds, ["csm"]);
});

test("RevenueCat requests use the authenticated ID, URL encoding, a secret and a deadline", async () => {
  const result = await fetchCustomer("user?# a", "sk_test", async (url, options) => {
    assert.equal(url, "https://api.revenuecat.com/v1/subscribers/user%3F%23%20a");
    assert.equal(options.headers.Authorization, "Bearer sk_test");
    assert.equal(options.redirect, "error");
    assert.ok(options.signal instanceof AbortSignal);
    return { ok: true, json: async () => inventory() };
  });
  assert.deepEqual(result, inventory());
});

test("invalid keys, HTTP failures and timeouts fail closed without leaking upstream details", async () => {
  await assert.rejects(fetchCustomer("u1", "appl_public", () => assert.fail("must not fetch")), { code: "failed-precondition" });
  for (const fetcher of [
    async () => ({ ok: false, status: 401 }),
    async () => { throw new Error("private response sk_secret user@email.example"); },
  ]) {
    await assert.rejects(fetchCustomer("u1", "sk_test", fetcher), (error) => {
      assert.equal(error.code, "unavailable");
      assert.doesNotMatch(error.message, /sk_secret|email/);
      return true;
    });
  }
});
