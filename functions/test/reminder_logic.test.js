/**
 * Tests for the scheduled-reminder decisions.
 *
 * Uses Node 20's built-in test runner, so this adds no dependency. Run with
 * `npm test` from functions/.
 *
 * These matter more than usual: the project is on the Spark plan, so none of
 * this can be deployed and none of it can be exercised against a real project.
 * A unit test is the only thing standing between this code and its first run
 * in production.
 */
const test = require("node:test");
const assert = require("node:assert");

const logic = require("../reminder_logic");

/** A Firestore Timestamp stand-in. */
const ts = (date) => ({ toDate: () => date });
const toDate = (t) => t.toDate();

/** A user who is eligible for everything, at UTC. */
const baseUser = (over = {}) => ({
  fcmToken: "token-1",
  utcOffsetMinutes: 0,
  notificationPrefs: { reminderHour: 20 },
  ...over,
});

// 20:30 UTC on a Monday.
const monday2030 = new Date(Date.UTC(2026, 8, 7, 20, 30));

test("isReminderCandidate requires a token", () => {
  assert.equal(logic.isReminderCandidate(baseUser()), true);
  assert.equal(logic.isReminderCandidate(baseUser({ fcmToken: null })), false);
  assert.equal(logic.isReminderCandidate({}), false);
  assert.equal(logic.isReminderCandidate(null), false);
});

test("a missing notificationsEnabled means opted in, not opted out", () => {
  // Firestore's `!=` filter excludes documents where the field is absent, and
  // the field is only written once a user visits notification settings. That
  // silently skipped almost every user.
  const user = baseUser();
  delete user.notificationsEnabled;
  assert.equal(logic.isReminderCandidate(user), true);
});

test("an explicit opt-out is honoured", () => {
  assert.equal(
    logic.isReminderCandidate(baseUser({ notificationsEnabled: false })),
    false,
  );
});

test("a user with local reminders is skipped, so nobody gets both", () => {
  assert.equal(
    logic.isReminderCandidate(baseUser({ usesLocalReminders: true })),
    false,
  );
  // False, not merely absent, must still receive the server copy.
  assert.equal(
    logic.isReminderCandidate(baseUser({ usesLocalReminders: false })),
    true,
  );
});

test("localHour applies the stored offset", () => {
  const noon = new Date(Date.UTC(2026, 8, 7, 12, 0));
  assert.equal(logic.localHour(0, noon), 12);
  assert.equal(logic.localHour(-480, noon), 4); // Los Angeles
  assert.equal(logic.localHour(600, noon), 22); // Sydney
});

test("localHour wraps across midnight in both directions", () => {
  const lateUtc = new Date(Date.UTC(2026, 8, 7, 23, 0));
  assert.equal(logic.localHour(120, lateUtc), 1);

  const earlyUtc = new Date(Date.UTC(2026, 8, 7, 1, 0));
  assert.equal(logic.localHour(-180, earlyUtc), 22);
});

test("a missing or absurd offset falls back to UTC", () => {
  const noon = new Date(Date.UTC(2026, 8, 7, 12, 0));
  assert.equal(logic.localHour(undefined, noon), 12);
  assert.equal(logic.localHour(NaN, noon), 12);
});

test("reminderHourFor defaults to 20 and rejects out-of-range values", () => {
  assert.equal(logic.reminderHourFor({}), 20);
  assert.equal(logic.reminderHourFor(baseUser()), 20);
  assert.equal(
    logic.reminderHourFor({ notificationPrefs: { reminderHour: 7 } }),
    7,
  );
  assert.equal(
    logic.reminderHourFor({ notificationPrefs: { reminderHour: 24 } }),
    20,
  );
  assert.equal(
    logic.reminderHourFor({ notificationPrefs: { reminderHour: -1 } }),
    20,
  );
});

test("the streak reminder fires only in the user's own chosen hour", () => {
  const user = baseUser();
  assert.equal(logic.needsStreakReminder(user, monday2030, toDate), true);

  const oneHourLater = new Date(Date.UTC(2026, 8, 7, 21, 30));
  assert.equal(logic.needsStreakReminder(user, oneHourLater, toDate), false);
});

test("two users in different zones each get 20:00 local", () => {
  // The whole point of the hourly schedule. On the old fixed UTC cron these
  // two received the same push at the same instant, at wildly different local
  // times.
  const sydney = baseUser({ utcOffsetMinutes: 600 });
  const la = baseUser({ utcOffsetMinutes: -480 });

  const tenUtc = new Date(Date.UTC(2026, 8, 7, 10, 0));
  assert.equal(logic.needsStreakReminder(sydney, tenUtc, toDate), true);
  assert.equal(logic.needsStreakReminder(la, tenUtc, toDate), false);

  const fourUtc = new Date(Date.UTC(2026, 8, 8, 4, 0));
  assert.equal(logic.needsStreakReminder(la, fourUtc, toDate), true);
  assert.equal(logic.needsStreakReminder(sydney, fourUtc, toDate), false);
});

test("a user who already studied today is not nudged", () => {
  const user = baseUser({
    streak: { lastLogin: ts(new Date(Date.UTC(2026, 8, 7, 9, 0))) },
  });
  assert.equal(logic.needsStreakReminder(user, monday2030, toDate), false);
});

test("yesterday's login still earns a nudge", () => {
  const user = baseUser({
    streak: { lastLogin: ts(new Date(Date.UTC(2026, 8, 6, 21, 0))) },
  });
  assert.equal(logic.needsStreakReminder(user, monday2030, toDate), true);
});

test("today is the user's local day, not the UTC day", () => {
  // Sydney is UTC+10, so at 10:00 UTC it is 20:00 on the 7th there and their
  // day began at 14:00 UTC on the 6th. A login at 15:00 UTC on the 6th is
  // therefore today for them, and yesterday by a naive UTC comparison.
  const sydney = baseUser({
    utcOffsetMinutes: 600,
    streak: { lastLogin: ts(new Date(Date.UTC(2026, 8, 6, 15, 0))) },
  });
  const tenUtc = new Date(Date.UTC(2026, 8, 7, 10, 0));

  assert.equal(logic.needsStreakReminder(sydney, tenUtc, toDate), false);
});

test("startOfLocalDay is midnight where the user is", () => {
  const tenUtc = new Date(Date.UTC(2026, 8, 7, 10, 0));
  // Sydney's 7 September began at 14:00 UTC on the 6th.
  assert.equal(
    logic.startOfLocalDay(600, tenUtc).toISOString(),
    "2026-09-06T14:00:00.000Z",
  );
});

test("the goal reminder lands two hours before the streak one", () => {
  const user = baseUser();
  const sixThirty = new Date(Date.UTC(2026, 8, 7, 18, 30));

  assert.equal(logic.needsDailyGoalReminder(user, sixThirty), true);
  assert.equal(logic.needsDailyGoalReminder(user, monday2030), false);
});

test("the goal hour wraps rather than going negative", () => {
  const user = baseUser({ notificationPrefs: { reminderHour: 1 } });
  const elevenPm = new Date(Date.UTC(2026, 8, 7, 23, 0));
  assert.equal(logic.needsDailyGoalReminder(user, elevenPm), true);
});

test("a user who has hit their goal is not nudged", () => {
  const user = baseUser({ dailyGoal: { target: 50, todayPoints: 50 } });
  const sixThirty = new Date(Date.UTC(2026, 8, 7, 18, 30));
  assert.equal(logic.needsDailyGoalReminder(user, sixThirty), false);
});

test("a non-positive target is never nudged about", () => {
  const sixThirty = new Date(Date.UTC(2026, 8, 7, 18, 30));

  // target 0 / points 0 is already caught by `todayPoints < target`, so it
  // does not exercise the guard. A corrupt negative points value does: without
  // the `target <= 0` check, -10 < 0 is true and the user is nudged daily
  // about a goal that cannot be met.
  assert.equal(
    logic.needsDailyGoalReminder(
      baseUser({ dailyGoal: { target: 0, todayPoints: -10 } }),
      sixThirty,
    ),
    false,
  );
  assert.equal(
    logic.needsDailyGoalReminder(
      baseUser({ dailyGoal: { target: -5, todayPoints: -10 } }),
      sixThirty,
    ),
    false,
  );
  assert.equal(
    logic.needsDailyGoalReminder(
      baseUser({ dailyGoal: { target: 0, todayPoints: 0 } }),
      sixThirty,
    ),
    false,
  );
});

test("pointsRemaining never advertises zero or a negative", () => {
  assert.equal(
    logic.pointsRemaining({ dailyGoal: { target: 50, todayPoints: 30 } }),
    20,
  );
  assert.equal(
    logic.pointsRemaining({ dailyGoal: { target: 50, todayPoints: 90 } }),
    1,
  );
  assert.equal(logic.pointsRemaining({}), 50);
});

test("chunk splits at the FCM multicast limit", () => {
  const tokens = Array.from({ length: 1201 }, (_, i) => `t${i}`);
  const batches = logic.chunk(tokens);

  assert.equal(batches.length, 3);
  assert.equal(batches[0].length, 500);
  assert.equal(batches[2].length, 201);
  assert.equal(batches.flat().length, tokens.length);
});

test("chunk handles an empty list and rejects a zero size", () => {
  assert.deepEqual(logic.chunk([]), []);
  assert.throws(() => logic.chunk(["a"], 0), RangeError);
});

test("streakBody reads correctly at zero and at one", () => {
  assert.match(logic.streakBody(0), /Start a streak/);
  assert.match(logic.streakBody(1), /1-day streak/);
});
