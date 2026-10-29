const { COURSE_IDS, PurchaseError } = require("./purchase_catalog");

const TRIAL_DURATION_MS = 7 * 24 * 60 * 60 * 1000;

function createTrialService({ db, timestamp, serverTimestamp, now = Date.now }) {
  return async (uid, courseId) => {
    if (!uid) throw new PurchaseError("unauthenticated", "Sign in to start a trial.");
    if (!COURSE_IDS.has(courseId)) {
      throw new PurchaseError("invalid-argument", "Choose a course for your trial.");
    }
    const ref = db.collection("users").doc(uid);
    return db.runTransaction(async (tx) => {
      const data = (await tx.get(ref)).data() || {};
      const time = now();
      // A lost response may be retried. Return the original grant without
      // changing its course or extending its expiry.
      if (data.hasUsedTrial === true || data.trialStartedAt != null || data.trialExpiry != null) {
        const expiry = data.trialExpiry?.toMillis?.();
        if (data.trialCourseId === courseId && expiry > time) {
          return { granted: true, courseId, expiresAt: new Date(expiry).toISOString() };
        }
        return { granted: false, reason: "already_used" };
      }
      const expiry = time + TRIAL_DURATION_MS;
      tx.set(ref, {
        trialCourseId: courseId,
        trialExpiry: timestamp(expiry),
        trialStartedAt: serverTimestamp(),
        hasUsedTrial: true,
      }, { merge: true });
      return { granted: true, courseId, expiresAt: new Date(expiry).toISOString() };
    });
  };
}

module.exports = { createTrialService, TRIAL_DURATION_MS };
