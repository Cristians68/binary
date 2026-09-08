const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Server-authoritative entitlements (RevenueCat webhook, trial, pending purchase).
const entitlements = require("./entitlements");

exports.revenueCatWebhook = entitlements.revenueCatWebhook;
exports.startTrial = entitlements.startTrial;
exports.setPendingPurchase = entitlements.setPendingPurchase;
exports.refreshEntitlement = entitlements.refreshEntitlement;

// Account deletion (Firestore denies client-side deletes; see functions/account.js).
const account = require("./account");
exports.deleteAccount = account.deleteAccount;

const logic = require("./reminder_logic");

/**
 * Walk every user document in pages, calling `visit` with each one.
 *
 * This used to load the whole `users` collection into one snapshot. That is
 * fine at a few hundred users and a memory ceiling at a few hundred thousand,
 * and a scheduled function that dies halfway sends a partial batch with no
 * indication which half.
 *
 * @param {function(FirebaseFirestore.QueryDocumentSnapshot): void} visit
 *   Called once per document.
 * @return {Promise<void>} Resolves when every page has been visited.
 */
async function forEachUser(visit) {
  let cursor = null;
  for (;;) {
    let query = db
      .collection("users")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(logic.PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    if (snap.empty) return;

    for (const doc of snap.docs) visit(doc);

    if (snap.docs.length < logic.PAGE_SIZE) return;
    cursor = snap.docs[snap.docs.length - 1];
  }
}

/**
 * Send one notification to many tokens.
 *
 * The handlers used to build one `messaging.send()` promise per user. FCM
 * takes 500 tokens per multicast, so this is up to 500x fewer round trips, and
 * the per-token response tells us exactly which tokens are dead.
 *
 * @param {Array<{token: string, body: string}>} targets Recipients.
 * @param {string} title Notification title.
 * @param {object} data Data payload.
 * @return {Promise<number>} How many were accepted.
 */
async function sendAll(targets, title, data = {}) {
  let sent = 0;

  // Bodies differ per user (streak length, points remaining), so group by body
  // and multicast each group.
  const byBody = new Map();
  for (const t of targets) {
    if (!byBody.has(t.body)) byBody.set(t.body, []);
    byBody.get(t.body).push(t.token);
  }

  for (const [body, tokens] of byBody) {
    for (const batch of logic.chunk(tokens)) {
      const res = await messaging.sendEachForMulticast({
        tokens: batch,
        notification: { title, body },
        data,
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      });
      sent += res.successCount;
      await pruneDeadTokens(batch, res.responses);
    }
  }

  return sent;
}

/**
 * Delete tokens FCM has told us are no longer registered.
 *
 * @param {Array<string>} tokens The tokens sent to, in order.
 * @param {Array<object>} responses The per-token results, in the same order.
 * @return {Promise<void>} Resolves once dead tokens are cleared.
 */
async function pruneDeadTokens(tokens, responses) {
  const dead = [];
  responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error && r.error.code;
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      dead.push(tokens[i]);
    }
  });
  if (dead.length === 0) return;

  await Promise.allSettled(
    dead.map((token) =>
      db
        .collection("users")
        .where("fcmToken", "==", token)
        .get()
        .then((snap) =>
          Promise.all(
            snap.docs.map((doc) =>
              doc.ref.update({
                fcmToken: admin.firestore.FieldValue.delete(),
              })
            )
          )
        )
    )
  );
}

/** Converts a Firestore Timestamp to a Date. */
const toDate = (ts) => ts.toDate();

// ─────────────────────────────────────────────────────────────────────────────
// STREAK REMINDER — runs hourly; sends to users for whom it is their chosen
// local hour and who have not studied today.
//
// It used to run once at 18:00 UTC for everybody, which is 10:00 in California
// and 04:00 in Sydney.
// ─────────────────────────────────────────────────────────────────────────────
exports.streakReminder = onSchedule("0 * * * *", async () => {
  const now = new Date();
  const targets = [];

  await forEachUser((doc) => {
    const data = doc.data();
    if (!logic.needsStreakReminder(data, now, toDate)) return;
    const currentStreak = (data.streak && data.streak.current) || 0;
    targets.push({
      token: data.fcmToken,
      body: logic.streakBody(currentStreak),
    });
  });

  const sent = await sendAll(targets, "🔥 Don't break your streak!", {
    type: "streak_reminder",
  });
  console.log(`Streak reminders sent to ${sent} of ${targets.length} users`);
});

// ─────────────────────────────────────────────────────────────────────────────
// DAILY GOAL REMINDER — runs hourly; lands two hours before each user's own
// streak reminder, so there is still an evening in which to act on it.
// ─────────────────────────────────────────────────────────────────────────────
exports.dailyGoalReminder = onSchedule("0 * * * *", async () => {
  const now = new Date();
  const targets = [];

  await forEachUser((doc) => {
    const data = doc.data();
    if (!logic.needsDailyGoalReminder(data, now)) return;
    targets.push({
      token: data.fcmToken,
      body:
        `You're ${logic.pointsRemaining(data)} pts away from your goal — ` +
        "a quick lesson will do it!",
    });
  });

  const sent = await sendAll(targets, "🎯 Daily goal check-in", {
    type: "daily_goal_reminder",
  });
  console.log(`Daily goal reminders sent to ${sent} of ${targets.length}`);
});

// ─────────────────────────────────────────────────────────────────────────────
// NEW CONTENT AVAILABLE — Mondays at 09:00 local time.
//
// This one stays server-side even for users with local reminders, because the
// device cannot know when new content has landed.
// ─────────────────────────────────────────────────────────────────────────────
exports.newContentReminder = onSchedule("0 * * * *", async () => {
  const now = new Date();
  const targets = [];

  await forEachUser((doc) => {
    const data = doc.data();
    if (!data || !data.fcmToken) return;
    if (data.notificationsEnabled === false) return;

    const offset = data.utcOffsetMinutes;
    if (logic.localHour(offset, now) !== 9) return;
    const local = new Date(
      now.getTime() + (Number.isFinite(offset) ? offset : 0) * 60 * 1000
    );
    if (local.getUTCDay() !== 1) return;

    targets.push({
      token: data.fcmToken,
      body: "Fresh lessons and quizzes are waiting for you in Binary.",
    });
  });

  const sent = await sendAll(targets, "📚 New content this week", {
    type: "new_content",
  });
  console.log(`New content reminders sent to ${sent} of ${targets.length}`);
});

// ─────────────────────────────────────────────────────────────────────────────
// COURSE COMPLETE — callable function triggered from the app
// Call this after a course is fully completed
// ─────────────────────────────────────────────────────────────────────────────
exports.sendCourseCompleteNotification = onCall(async (request) => {
  const { courseTitle } = request.data;
  // A bare Error surfaces to the client as an opaque INTERNAL; HttpsError
  // gives the app a code it can actually branch on.
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  if (typeof courseTitle !== "string" || courseTitle.length > 200) {
    throw new HttpsError("invalid-argument", "A valid courseTitle is required.");
  }

  const userDoc = await db.collection("users").doc(uid).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) return { sent: false };

  const sent = await sendAll(
    [{
      token,
      body: `You've completed ${courseTitle}. Your certificate is ready.`,
    }],
    "🎓 Course complete!",
    { type: "course_complete" }
  );

  return { sent: sent > 0 };
});