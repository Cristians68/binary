const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─────────────────────────────────────────────────────────────────────────────
// Helper: send FCM to a single token
// ─────────────────────────────────────────────────────────────────────────────
async function sendToToken(token, title, body, data = {}) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data,
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
  } catch (err) {
    // Token invalid — clean it up
    if (
      err.code === "messaging/invalid-registration-token" ||
      err.code === "messaging/registration-token-not-registered"
    ) {
      await db
        .collection("users")
        .where("fcmToken", "==", token)
        .get()
        .then((snap) =>
          snap.docs.forEach((doc) =>
            doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() })
          )
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STREAK REMINDER — runs daily at 18:00 UTC (6 PM)
// Sends only to users who haven't logged in today
// ─────────────────────────────────────────────────────────────────────────────
exports.streakReminder = onSchedule("0 18 * * *", async () => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayTs = admin.firestore.Timestamp.fromDate(today);

  const usersSnap = await db
    .collection("users")
    .where("fcmToken", "!=", null)
    .where("notificationsEnabled", "!=", false)
    .get();

  const sends = [];

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const token = data.fcmToken;
    if (!token) continue;

    // Skip users who have already logged in today
    const lastLogin = data?.streak?.lastLogin;
    if (lastLogin && lastLogin.toDate() >= todayTs.toDate()) continue;

    const currentStreak = data?.streak?.current ?? 0;
    const title = "🔥 Don't break your streak!";
    const body =
      currentStreak > 0
        ? `You're on a ${currentStreak}-day streak — open Binary to keep it going.`
        : "Start a streak today — open Binary and complete a lesson.";

    sends.push(sendToToken(token, title, body, { type: "streak_reminder" }));
  }

  await Promise.allSettled(sends);
  console.log(`Streak reminders sent to ${sends.length} users`);
});

// ─────────────────────────────────────────────────────────────────────────────
// DAILY GOAL REMINDER — runs daily at 20:00 UTC (8 PM)
// Sends only to users who haven't hit their daily goal today
// ─────────────────────────────────────────────────────────────────────────────
exports.dailyGoalReminder = onSchedule("0 20 * * *", async () => {
  const usersSnap = await db
    .collection("users")
    .where("fcmToken", "!=", null)
    .where("notificationsEnabled", "!=", false)
    .get();

  const sends = [];

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const token = data.fcmToken;
    if (!token) continue;

    const goal = data.dailyGoal ?? {};
    const target = goal.target ?? 50;
    const todayPoints = goal.todayPoints ?? 0;

    // Skip users who have already hit their goal
    if (todayPoints >= target) continue;

    const remaining = target - todayPoints;
    const title = "🎯 Daily goal check-in";
    const body = `You're ${remaining} pts away from your goal — a quick lesson will do it!`;

    sends.push(
      sendToToken(token, title, body, { type: "daily_goal_reminder" })
    );
  }

  await Promise.allSettled(sends);
  console.log(`Daily goal reminders sent to ${sends.length} users`);
});

// ─────────────────────────────────────────────────────────────────────────────
// NEW CONTENT AVAILABLE — runs every Monday at 09:00 UTC
// ─────────────────────────────────────────────────────────────────────────────
exports.newContentReminder = onSchedule("0 9 * * 1", async () => {
  const usersSnap = await db
    .collection("users")
    .where("fcmToken", "!=", null)
    .where("notificationsEnabled", "!=", false)
    .get();

  const sends = [];

  for (const doc of usersSnap.docs) {
    const token = doc.data().fcmToken;
    if (!token) continue;
    sends.push(
      sendToToken(
        token,
        "📚 New content this week",
        "Fresh lessons and quizzes are waiting for you in Binary.",
        { type: "new_content" }
      )
    );
  }

  await Promise.allSettled(sends);
  console.log(`New content reminders sent to ${sends.length} users`);
});

// ─────────────────────────────────────────────────────────────────────────────
// COURSE COMPLETE — callable function triggered from the app
// Call this after a course is fully completed
// ─────────────────────────────────────────────────────────────────────────────
exports.sendCourseCompleteNotification = onCall(async (request) => {
  const { courseTitle } = request.data;
  const uid = request.auth?.uid;
  if (!uid) throw new Error("Unauthenticated");

  const userDoc = await db.collection("users").doc(uid).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) return { sent: false };

  await sendToToken(
    token,
    "🎓 Course complete!",
    `You've completed ${courseTitle}. Your certificate is ready.`,
    { type: "course_complete" }
  );

  return { sent: true };
});