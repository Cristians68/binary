/** Server-authoritative purchases. RevenueCat is the source of truth. */
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("node:crypto");
const { fetchCustomer } = require("./revenuecat_client");
const { createPurchaseService } = require("./purchase_reconciliation");
const { COURSE_IDS, PurchaseError } = require("./purchase_catalog");

const REVENUECAT_WEBHOOK_SECRET = defineSecret("REVENUECAT_WEBHOOK_SECRET");
const REVENUECAT_SECRET_API_KEY = defineSecret("REVENUECAT_SECRET_API_KEY");
const db = () => admin.firestore();
const service = () => createPurchaseService({
  db: db(),
  fetchCustomer: (uid) => fetchCustomer(uid, REVENUECAT_SECRET_API_KEY.value()),
  serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
});

function secretMatches(provided, expected) {
  if (typeof provided !== "string" || !provided || typeof expected !== "string" || !expected) return false;
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// Reconcile the CURRENT inventory instead of granting/revoking the event's
// product. A delayed purchase event must never undo a newer refund or transfer.
const RECONCILE_EVENTS = new Set([
  "INITIAL_PURCHASE", "RENEWAL", "NON_RENEWING_PURCHASE", "UNCANCELLATION",
  "PRODUCT_CHANGE", "TRANSFER", "EXPIRATION", "CANCELLATION", "REFUND",
  "REFUND_REVERSED", "SUBSCRIPTION_PAUSED", "SUBSCRIPTION_EXTENDED",
]);

function eventUserIds(event) {
  const ids = event.type === "TRANSFER"
    ? [...(event.transferred_from || []), ...(event.transferred_to || [])]
    : [event.app_user_id, event.original_app_user_id, ...(event.aliases || [])];
  return [...new Set(ids.filter((id) => typeof id === "string" && id.length > 0 &&
    id.length <= 128 && !id.includes("/") && !id.startsWith("$RCAnonymousID:")))];
}

exports.revenueCatWebhook = onRequest(
  { secrets: [REVENUECAT_WEBHOOK_SECRET, REVENUECAT_SECRET_API_KEY], cors: false, timeoutSeconds: 120 },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).send("Method not allowed"); return; }
    if (!secretMatches(req.get("Authorization"), REVENUECAT_WEBHOOK_SECRET.value())) {
      res.status(401).send("Unauthorized"); return;
    }
    const event = req.body?.event;
    if (!event || typeof event.id !== "string" || !event.id || event.id.length > 256 ||
        typeof event.type !== "string" ||
        [event.aliases, event.transferred_from, event.transferred_to]
          .some((ids) => ids != null && (!Array.isArray(ids) || ids.length > 100))) {
      res.status(400).send("Invalid event"); return;
    }
    if (!RECONCILE_EVENTS.has(event.type)) { res.status(200).send("Ignored"); return; }

    const eventKey = crypto.createHash("sha256").update(event.id).digest("hex");
    const seenRef = db().collection("processed_rc_events").doc(eventKey);
    try {
      if ((await seenRef.get()).exists) { res.status(200).send("Duplicate ignored"); return; }
      const purchaseService = service();
      for (const uid of eventUserIds(event)) {
        // Do not recreate deleted accounts or create profiles for RC aliases
        // that are not Firebase users. Other Auth errors must be retried.
        try { await admin.auth().getUser(uid); } catch (error) {
          if (error.code === "auth/user-not-found") continue;
          throw error;
        }
        await purchaseService.refresh(uid);
      }
      // Mark processed ONLY after every write succeeds. Doing this before
      // processing permanently swallowed retries after an API/Firestore error.
      await seenRef.set({ type: event.type, receivedAt: admin.firestore.FieldValue.serverTimestamp() });
      res.status(200).send("OK");
    } catch (error) {
      logger.error("revenueCatWebhook: reconciliation failed", { code: error.code || "internal" });
      res.status(500).send("Reconciliation failed; retry required");
    }
  }
);

function purchaseCallable(action) {
  return onCall({ secrets: [REVENUECAT_SECRET_API_KEY], timeoutSeconds: 30 }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in to manage purchases.");
    try {
      await admin.auth().getUser(uid);
      return await action(service(), uid, request.data);
    } catch (error) {
      if (error instanceof PurchaseError) throw new HttpsError(error.code, error.message);
      if (error.code === "auth/user-not-found") throw new HttpsError("unauthenticated", "Sign in again.");
      logger.error("Purchase verification failed", { code: error.code || "internal" });
      throw new HttpsError("unavailable", "Could not verify purchases. Please try again shortly.");
    }
  });
}

// Older clients without a product ID must update. The generic single IAP is
// restore-only; each new course purchase has its own immutable product ID.
exports.setPendingPurchase = purchaseCallable((purchases, uid, data) => purchases.prepare(uid, data));
exports.refreshEntitlement = purchaseCallable((purchases, uid) => purchases.refresh(uid));

// Legacy one-time trial. The normal free preview remains Module 1 of every
// course. Clients cannot extend or reset this server-owned trial.
exports.startTrial = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to start a trial.");
  const courseId = request.data?.courseId;
  if (!COURSE_IDS.has(courseId)) throw new HttpsError("invalid-argument", "A valid courseId is required.");
  const ref = db().collection("users").doc(uid);
  return db().runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data() || {};
    if (data.hasUsedTrial === true) return { granted: false, reason: "already_used" };
    const expiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    tx.set(ref, {
      trialCourseId: courseId,
      trialExpiry: admin.firestore.Timestamp.fromDate(expiry),
      trialStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      hasUsedTrial: true,
    }, { merge: true });
    return { granted: true, expiresAt: expiry.toISOString() };
  });
});
