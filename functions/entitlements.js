/**
 * Server-authoritative entitlements.
 *
 * Before this module existed, `users/{uid}.subscriptionPlan` was written by the
 * app itself. Because the client must also write streaks, FCM tokens, and
 * enrolments to that same document, Firestore rules had to allow client writes
 * to it — which meant any signed-in user could set their own plan to "all" and
 * unlock the paid catalogue for free.
 *
 * Entitlement fields are now written ONLY here, via the Admin SDK (which
 * bypasses security rules). firestore.rules blocks the client from touching
 * them. RevenueCat is the source of truth; Firestore is a cache of it.
 */

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

// Set with:  firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
// Then paste the same value into RevenueCat → Integrations → Webhooks →
// Authorization header.
const REVENUECAT_WEBHOOK_SECRET = defineSecret("REVENUECAT_WEBHOOK_SECRET");

const db = () => admin.firestore();

// Must stay in sync with lib/screens/subscription_service.dart
const PRODUCT_SINGLE = "binary_course_single";
const PRODUCT_BUNDLE4 = "binary_bundle_4";
const PRODUCT_BUNDLE_ALL = "binary_bundle_all";

const TRIAL_DAYS = 7;

/** Map a RevenueCat product identifier to our internal plan string. */
function planForProduct(productId) {
  switch (productId) {
    case PRODUCT_BUNDLE_ALL:
      return "all";
    case PRODUCT_BUNDLE4:
      return "bundle4";
    case PRODUCT_SINGLE:
      return "single";
    default:
      return null;
  }
}

/** Constant-time comparison so the secret can't be recovered by timing. */
function secretMatches(provided, expected) {
  if (typeof provided !== "string" || provided.length === 0) return false;
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

// Event types that mean "this user currently has access".
const GRANT_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "NON_RENEWING_PURCHASE",
  "UNCANCELLATION",
  "PRODUCT_CHANGE",
  "TRANSFER",
]);

// Event types that mean "revoke access now".
const REVOKE_EVENTS = new Set(["EXPIRATION", "REFUND", "SUBSCRIPTION_PAUSED"]);

/**
 * RevenueCat webhook. This is the ONLY path that grants a paid entitlement.
 *
 * RevenueCat retries on non-2xx, so we return 200 for anything we have
 * deliberately decided to ignore, and only 4xx/5xx for genuine failures.
 */
exports.revenueCatWebhook = onRequest(
  { secrets: [REVENUECAT_WEBHOOK_SECRET], cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    if (!secretMatches(req.get("Authorization"), REVENUECAT_WEBHOOK_SECRET.value())) {
      logger.warn("revenueCatWebhook: rejected request with bad Authorization");
      res.status(401).send("Unauthorized");
      return;
    }

    const event = req.body && req.body.event;
    if (!event) {
      res.status(400).send("Missing event");
      return;
    }

    const uid = event.app_user_id;
    if (!uid) {
      logger.warn("revenueCatWebhook: event without app_user_id", {
        type: event.type,
      });
      res.status(200).send("Ignored: no app_user_id");
      return;
    }

    // ── Replay / duplicate protection ────────────────────────────────────────
    // The Authorization check above proves the SENDER, not the FRESHNESS. Two
    // distinct problems remain without this:
    //
    //   1. Replay. Anyone who can capture one valid request body can resend it.
    //      Most events are harmless to repeat because the writes below are
    //      absolute (set/merge), not incremental -- but a stale GRANT replayed
    //      after a REFUND would silently restore paid access to a refunded user.
    //   2. Retries. RevenueCat re-delivers on any non-2xx, so the same event can
    //      legitimately arrive several times.
    //
    // A conditional create on the event id is the whole fix: `create()` fails if
    // the document already exists, and that check-and-write is atomic in
    // Firestore, so two concurrent deliveries of the same event cannot both win.
    // First delivery proceeds; every later one short-circuits to 200 (200, not
    // 4xx -- a duplicate is success from RevenueCat's point of view, and a non-2xx
    // would put it into a retry loop).
    const eventId = event.id || null;
    if (eventId) {
      const seenRef = db().collection("processed_rc_events").doc(String(eventId));
      try {
        await seenRef.create({
          type: event.type,
          uid,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        // ALREADY_EXISTS is gRPC status 6 (verified against both google-gax and
        // @grpc/grpc-js). Accept the string form too: the numeric code is what
        // Firestore surfaces today, but treating a duplicate as an unhandled
        // error would return 500 and put RevenueCat into a permanent retry loop
        // for that event — so this branch is matched defensively.
        const dup = err && (err.code === 6 || err.code === "ALREADY_EXISTS"
          || /ALREADY_EXISTS|already exists/i.test(String(err.message || "")));
        if (dup) {
          logger.info(`revenueCatWebhook: duplicate event ${eventId} ignored`);
          res.status(200).send("Duplicate ignored");
          return;
        }
        throw err;
      }
    } else {
      // RevenueCat always sends an id; its absence means a malformed or forged
      // body. Process it (losing dedup) but make the anomaly visible.
      logger.warn("revenueCatWebhook: event without id — dedup skipped", {
        type: event.type,
        uid,
      });
    }

    const ref = db().collection("users").doc(uid);

    try {
      if (REVOKE_EVENTS.has(event.type)) {
        await ref.set(
          {
            subscriptionPlan: "none",
            subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            subscribedCourseId: admin.firestore.FieldValue.delete(),
            bundleCourseIds: admin.firestore.FieldValue.delete(),
          },
          { merge: true }
        );
        logger.info(`Revoked entitlement for ${uid} (${event.type})`);
        res.status(200).send("Revoked");
        return;
      }

      if (!GRANT_EVENTS.has(event.type)) {
        // TEST, BILLING_ISSUE, SUBSCRIBER_ALIAS etc. — nothing to do.
        res.status(200).send("Ignored");
        return;
      }

      const plan = planForProduct(event.product_id);
      if (!plan) {
        logger.warn("revenueCatWebhook: unknown product", {
          productId: event.product_id,
          uid,
        });
        res.status(200).send("Ignored: unknown product");
        return;
      }

      const update = {
        subscriptionPlan: plan,
        subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastRevenueCatEvent: event.type,
      };

      // Which course(s) a purchase unlocks is a client-side choice made at
      // checkout, so the app records the intent in a pending field and we
      // promote it here once payment is confirmed. This keeps the client
      // unable to grant access on its own.
      const snap = await ref.get();
      const data = snap.data() || {};

      if (plan === "single") {
        const pending = data.pendingCourseId;
        if (pending) {
          update.subscribedCourseId = pending;
          update.pendingCourseId = admin.firestore.FieldValue.delete();
        }
      }

      if (plan === "bundle4") {
        const pending = data.pendingBundleCourseIds;
        if (Array.isArray(pending) && pending.length > 0) {
          update.bundleCourseIds = pending.slice(0, 4);
          update.pendingBundleCourseIds = admin.firestore.FieldValue.delete();
        }
      }

      await ref.set(update, { merge: true });
      logger.info(`Granted "${plan}" to ${uid} (${event.type})`);
      res.status(200).send("OK");
    } catch (err) {
      logger.error("revenueCatWebhook failed", err);
      res.status(500).send("Internal error");
    }
  }
);

/**
 * Start the one-time free trial.
 *
 * Previously the client wrote trialExpiry/hasUsedTrial directly, so a user
 * could reset hasUsedTrial and farm unlimited trials. The transaction here
 * makes "one trial per account" actually enforceable.
 */
exports.startTrial = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to start a trial.");
  }

  const courseId = request.data && request.data.courseId;
  if (typeof courseId !== "string" || courseId.length === 0 || courseId.length > 128) {
    throw new HttpsError("invalid-argument", "A valid courseId is required.");
  }

  const ref = db().collection("users").doc(uid);

  return db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() || {};

    if (data.hasUsedTrial === true) {
      return { granted: false, reason: "already_used" };
    }

    const expiry = new Date(Date.now() + TRIAL_DAYS * 24 * 60 * 60 * 1000);

    tx.set(
      ref,
      {
        trialCourseId: courseId,
        trialExpiry: admin.firestore.Timestamp.fromDate(expiry),
        trialStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        hasUsedTrial: true,
      },
      { merge: true }
    );

    return { granted: true, expiresAt: expiry.toISOString() };
  });
});

/**
 * Record which course(s) the user is about to buy, so the webhook can attach
 * the purchase to them. Writing this field grants nothing on its own.
 */
exports.setPendingPurchase = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const { courseId, courseIds } = request.data || {};
  const update = {};

  if (typeof courseId === "string" && courseId.length > 0 && courseId.length <= 128) {
    update.pendingCourseId = courseId;
  }

  if (Array.isArray(courseIds) && courseIds.length > 0) {
    const clean = courseIds
      .filter((c) => typeof c === "string" && c.length > 0 && c.length <= 128)
      .slice(0, 4);
    if (clean.length > 0) update.pendingBundleCourseIds = clean;
  }

  if (Object.keys(update).length === 0) {
    throw new HttpsError("invalid-argument", "Nothing to record.");
  }

  await db().collection("users").doc(uid).set(update, { merge: true });
  return { ok: true };
});

/**
 * Reconciliation fallback: if a webhook was missed (RevenueCat outage, user
 * reinstalled before delivery), the app can ask the server to re-check. The
 * server queries RevenueCat directly — the client's claim is never trusted.
 */
exports.refreshEntitlement = onCall(
  { secrets: [REVENUECAT_WEBHOOK_SECRET] },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in first.");
    }

    // NOTE: requires a RevenueCat *secret* API key (sk_...) stored as its own
    // secret. Left unimplemented deliberately rather than shipping a stub that
    // silently grants access. See docs/SECURITY.md.
    throw new HttpsError(
      "unimplemented",
      "Entitlement refresh is handled by the RevenueCat webhook."
    );
  }
);
