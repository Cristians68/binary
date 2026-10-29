const { test } = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const { createTrialService, TRIAL_DURATION_MS } = require("../trial_service");
const { COURSE_IDS } = require("../purchase_catalog");

const [courseA, courseB] = [...COURSE_IDS];
const now = Date.parse("2026-10-29T12:00:00Z");
function harness(profile = {}) {
  let data = { name: "Learner", subscriptionPlan: "bundle4", ...profile };
  let time = now;
  let fail = false;
  const start = createTrialService({
    db: {
      collection: () => ({ doc: () => ({}) }),
      runTransaction: async (action) => {
        let write;
        const result = await action({
          get: async () => ({ data: () => data }),
          set: (_ref, value) => { write = value; },
        });
        if (fail) throw new Error("Temporary commit failure");
        if (write) data = { ...data, ...write };
        return result;
      },
    },
    timestamp: Timestamp.fromMillis,
    serverTimestamp: () => Timestamp.fromMillis(time),
    now: () => time,
  });
  return { start, data: () => data, time: (value) => { time = value; },
    fail: (value) => { fail = value; } };
}

test("a trial lasts exactly seven days and preserves purchases and profile", async () => {
  const h = harness();
  const result = await h.start("learner", courseA);
  assert.equal(result.granted, true);
  assert.equal(result.courseId, courseA);
  assert.equal(Date.parse(result.expiresAt), now + TRIAL_DURATION_MS);
  assert.equal(h.data().trialExpiry.toMillis(), now + TRIAL_DURATION_MS);
  assert.equal(h.data().trialStartedAt.toMillis(), now);
  assert.equal(h.data().hasUsedTrial, true);
  assert.equal(h.data().name, "Learner");
  assert.equal(h.data().subscriptionPlan, "bundle4");
});

test("retrying a successful request never extends the expiry", async () => {
  const h = harness();
  const first = await h.start("learner", courseA);
  h.time(now + 3600000);
  assert.deepEqual(await h.start("learner", courseA), first);
  assert.equal(h.data().trialStartedAt.toMillis(), now);
});

test("an active trial cannot switch courses and an expired trial cannot restart", async () => {
  const h = harness();
  await h.start("learner", courseA);
  assert.deepEqual(await h.start("learner", courseB), { granted: false, reason: "already_used" });
  h.time(now + TRIAL_DURATION_MS);
  assert.deepEqual(await h.start("learner", courseA), { granted: false, reason: "already_used" });
  assert.equal(h.data().trialCourseId, courseA);
});

test("historical trial records cannot receive a second trial", async () => {
  for (const profile of [
    { hasUsedTrial: true },
    { trialStartedAt: Timestamp.fromMillis(now - 1) },
    { trialExpiry: Timestamp.fromMillis(now - 1) },
  ]) {
    const h = harness(profile);
    assert.equal((await h.start("learner", courseA)).granted, false);
  }
});

test("signed-out requests and unknown courses cannot consume a trial", async () => {
  const h = harness();
  await assert.rejects(h.start(null, courseA), { code: "unauthenticated" });
  for (const course of [undefined, null, "unknown", "../users/other", {}]) {
    await assert.rejects(h.start("learner", course), { code: "invalid-argument" });
  }
  assert.equal(h.data().hasUsedTrial, undefined);
});

test("failed writes leave the trial available for retry", async () => {
  const h = harness();
  h.fail(true);
  await assert.rejects(h.start("learner", courseA));
  assert.equal(h.data().hasUsedTrial, undefined);
  h.fail(false);
  assert.equal((await h.start("learner", courseA)).granted, true);
});
