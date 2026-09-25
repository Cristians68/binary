const crypto = require("node:crypto");
const {
  COURSE_PRODUCTS, LEGACY_SINGLE, BUNDLE4, ALL, isProduct, validCourses,
  checkoutSelection, PurchaseError,
} = require("./purchase_catalog");

const INTENT_WINDOW_MS = 30 * 60 * 1000;

// The v1 non_subscriptions map is the current non-refunded purchase inventory.
// Do not use one shared entitlement's product_identifier: it can name only one
// of several independently owned courses. Unknown products never grant access.
function readPurchases(response) {
  const items = response?.subscriber?.non_subscriptions;
  const checkedAt = response?.request_date_ms;
  if (!items || typeof items !== "object" || Array.isArray(items) ||
      !Number.isSafeInteger(checkedAt) || checkedAt <= 0) {
    throw new PurchaseError("unavailable", "The purchase service returned an incomplete response. Please try again.");
  }
  const purchases = [];
  for (const [productId, entries] of Object.entries(items)) {
    if (!isProduct(productId)) continue;
    if (!Array.isArray(entries)) {
      throw new PurchaseError("unavailable", "The purchase service returned an incomplete response. Please try again.");
    }
    for (const entry of entries) {
      // Defensive handling if RevenueCat includes explicit revocation fields.
      if (entry?.refunded_at || entry?.revoked_at) continue;
      const purchasedAt = Date.parse(entry?.purchase_date);
      if (typeof entry?.id !== "string" || !entry.id ||
          typeof entry.store !== "string" || !entry.store ||
          typeof entry.is_sandbox !== "boolean" || !Number.isFinite(purchasedAt)) {
        throw new PurchaseError("unavailable", "The purchase service returned an incomplete response. Please try again.");
      }
      const key = crypto.createHash("sha256")
        .update(JSON.stringify([entry.store, entry.is_sandbox, productId, entry.id]))
        .digest("hex");
      purchases.push({ productId, key, purchasedAt });
    }
  }
  return { checkedAt, purchases };
}

function resultFor(data) {
  return {
    subscriptionPlan: data.subscriptionPlan || "none",
    purchasedCourseIds: data.purchasedCourseIds || [],
    activeProductIds: data.purchaseProductIds || [],
    unresolvedProductIds: data.unresolvedPurchaseProductIds || [],
  };
}

// Dependencies let tests exercise the actual transaction and checkout paths
// without a production project or a RevenueCat secret.
function createPurchaseService({ db, fetchCustomer, serverTimestamp, now = Date.now }) {
  async function refresh(uid) {
    const { checkedAt, purchases } = readPurchases(await fetchCustomer(uid));
    const userRef = db.collection("users").doc(uid);
    const stateRef = userRef.collection("purchaseState").doc("current");
    const selectionProducts = [LEGACY_SINGLE, BUNDLE4];
    const intentRefs = selectionProducts.map((id) => userRef.collection("purchaseIntents").doc(id));
    const bindingRefs = purchases.map((p) => db.collection("purchase_bindings").doc(p.key));

    return db.runTransaction(async (tx) => {
      const [stateSnap, ...snaps] = await tx.getAll(stateRef, ...intentRefs, ...bindingRefs);
      const previous = stateSnap.data() || {};
      // A slower request can finish after a newer refund/transfer refresh.
      // RevenueCat's request time, not event time, orders complete snapshots.
      if ((previous.revenueCatCheckedAtMs || 0) > checkedAt) return resultFor(previous);

      const intents = new Map(selectionProducts.map((id, i) => [id, snaps[i].data()]));
      const owned = new Set();
      const unresolved = new Set();
      const bundles = new Set();
      let all = false;
      purchases.forEach((purchase, i) => {
        const { productId } = purchase;
        if (productId === ALL) { all = true; return; }
        if (Object.hasOwn(COURSE_PRODUCTS, productId)) {
          owned.add(COURSE_PRODUCTS[productId]);
          return;
        }

        const count = productId === BUNDLE4 ? 4 : 1;
        const existing = snaps[selectionProducts.length + i].data();
        let courseIds = existing?.courseIds;
        if (!existing) {
          const intent = intents.get(productId);
          // Intents live in a server-only subcollection. Never consume the old
          // client-writable pendingCourseId/pendingBundleCourseIds fields.
          // A choice made AFTER a historical receipt cannot reassign it.
          if (intent && validCourses(intent.courseIds, count) &&
              Number.isFinite(intent.createdAtMs) &&
              purchase.purchasedAt >= intent.createdAtMs - 60000 &&
              purchase.purchasedAt <= intent.createdAtMs + INTENT_WINDOW_MS) {
            courseIds = intent.courseIds;
          }
          if (validCourses(courseIds, count)) {
            tx.create(bindingRefs[i], { productId, courseIds, createdAt: serverTimestamp() });
          }
        }
        if (!validCourses(courseIds, count) || (existing && existing.productId !== productId)) {
          unresolved.add(productId);
          return;
        }
        courseIds.forEach((id) => {
          owned.add(id);
          if (productId === BUNDLE4) bundles.add(id);
        });
      });

      const purchasedCourseIds = [...owned].sort();
      const update = {
        subscriptionPlan: all ? "all" : bundles.size ? "bundle4" : owned.size ? "single" : "none",
        purchasedCourseIds,
        // Preserve compatibility for older clients; new clients use the union.
        subscribedCourseId: purchasedCourseIds[0] || null,
        bundleCourseIds: [...bundles].sort(),
        purchaseProductIds: [...new Set(purchases.map((p) => p.productId))].sort(),
        unresolvedPurchaseProductIds: [...unresolved].sort(),
        revenueCatCheckedAtMs: checkedAt,
        subscriptionUpdatedAt: serverTimestamp(),
      };
      tx.set(stateRef, update);
      tx.set(userRef, {
        subscriptionPlan: update.subscriptionPlan,
        purchasedCourseIds,
        subscribedCourseId: update.subscribedCourseId,
        bundleCourseIds: update.bundleCourseIds,
        subscriptionUpdatedAt: update.subscriptionUpdatedAt,
      }, { merge: true });
      return resultFor(update);
    });
  }

  async function prepare(uid, data) {
    const selection = checkoutSelection(data);
    // Every checkout, including All Courses, verifies that the server and its
    // RevenueCat credentials work BEFORE opening the store payment sheet.
    const state = await refresh(uid);
    const alreadyOwned = state.subscriptionPlan === "all" ||
      (selection.courseIds.length > 0 && selection.courseIds.every((id) => state.purchasedCourseIds.includes(id)));
    if (alreadyOwned) return { ok: true, alreadyOwned: true };
    if (state.activeProductIds.includes(selection.productId)) {
      throw new PurchaseError("failed-precondition", "This purchase already belongs to your account. Restore purchases to recover its original courses, or contact support if they remain locked.");
    }
    if (selection.productId === BUNDLE4) {
      const ref = db.collection("users").doc(uid).collection("purchaseIntents").doc(BUNDLE4);
      await db.runTransaction(async (tx) => {
        const old = (await tx.get(ref)).data();
        const same = old && JSON.stringify(old.courseIds) === JSON.stringify(selection.courseIds);
        // Keep a checkout from another device from silently changing the four
        // courses while its App Store sheet is still open.
        if (old && !same && now() - old.createdAtMs < INTENT_WINDOW_MS) {
          throw new PurchaseError("failed-precondition", "A bundle checkout is already in progress. Restore purchases first, or try the new selection in 30 minutes.");
        }
        tx.set(ref, { ...selection, createdAtMs: same && now() - old.createdAtMs < INTENT_WINDOW_MS ? old.createdAtMs : now() });
      });
    }
    return { ok: true, alreadyOwned: false };
  }

  return { refresh, prepare };
}

module.exports = { readPurchases, createPurchaseService, INTENT_WINDOW_MS };
