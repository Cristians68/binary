/**
 * Pure decisions for the scheduled reminder functions.
 *
 * No Firestore, no messaging, no clock of its own — every input is an
 * argument. This mirrors the app's `streak_logic.dart`: the rules live here
 * and are tested directly with `npm test`, while index.js only reads
 * documents and sends messages.
 *
 * Extracted because these rules sat inline inside three onSchedule handlers,
 * where the only way to exercise them was to deploy — and the project is on
 * the Spark plan, so they cannot be deployed at all yet.
 */

/** Firestore reads per page. Keeps a large user base off one giant snapshot. */
const PAGE_SIZE = 500;

/** FCM's hard limit for one sendEachForMulticast call. */
const MULTICAST_LIMIT = 500;

/**
 * Whether this user already gets the nudge from their own device.
 *
 * The app writes `usesLocalReminders` whenever it successfully schedules a
 * local reminder. Skipping those users is what stops anyone receiving both a
 * local and a push copy of the same message. A user who never granted
 * notification permission never carries the flag, so the server stays their
 * fallback.
 *
 * @param {object} data A user document.
 * @return {boolean} True when the server should stay quiet.
 */
function isCoveredByLocalReminders(data) {
  return data.usesLocalReminders === true;
}

/**
 * Whether a user may be sent any reminder at all.
 *
 * `notificationsEnabled` is checked here rather than in the query because
 * Firestore's `!=` excludes documents where the field is ABSENT, and the field
 * is only written once a user visits notification settings. Filtering on it
 * server-side silently skipped almost everybody.
 *
 * @param {object} data A user document.
 * @return {boolean} True when a push may be sent.
 */
function isReminderCandidate(data) {
  if (!data || !data.fcmToken) return false;
  if (data.notificationsEnabled === false) return false;
  if (isCoveredByLocalReminders(data)) return false;
  return true;
}

/**
 * The hour of the day where this user is, 0-23.
 *
 * Every reminder used to fire on a fixed UTC cron: `0 18 * * *` is 10:00 in
 * California and 04:00 in Sydney. The app records its own UTC offset, so the
 * handlers can run hourly and pick out the users for whom it is now the right
 * local time.
 *
 * @param {number|undefined} offsetMinutes Minutes ahead of UTC.
 * @param {Date} nowUtc The current instant.
 * @return {number} Local hour, 0-23.
 */
function localHour(offsetMinutes, nowUtc) {
  const offset = Number.isFinite(offsetMinutes) ? offsetMinutes : 0;
  const localMs = nowUtc.getTime() + offset * 60 * 1000;
  return new Date(localMs).getUTCHours();
}

/**
 * The hour this user wants their daily reminders, defaulting to 20:00.
 *
 * @param {object} data A user document.
 * @return {number} Hour, 0-23.
 */
function reminderHourFor(data) {
  const raw = data && data.notificationPrefs &&
    data.notificationPrefs.reminderHour;
  if (!Number.isInteger(raw) || raw < 0 || raw > 23) return 20;
  return raw;
}

/**
 * Whether it is currently this user's chosen reminder hour.
 *
 * @param {object} data A user document.
 * @param {Date} nowUtc The current instant.
 * @return {boolean} True when now is their reminder hour.
 */
function isReminderHourFor(data, nowUtc) {
  const offset = data && data.utcOffsetMinutes;
  return localHour(offset, nowUtc) === reminderHourFor(data);
}

/**
 * The start of this user's local day, expressed as a UTC instant.
 *
 * Comparing `streak.lastLogin` against a UTC midnight told a user in Sydney
 * they had not studied today when they had, and a user in Los Angeles that
 * they had when they had not.
 *
 * @param {number|undefined} offsetMinutes Minutes ahead of UTC.
 * @param {Date} nowUtc The current instant.
 * @return {Date} The instant their local day began.
 */
function startOfLocalDay(offsetMinutes, nowUtc) {
  const offset = Number.isFinite(offsetMinutes) ? offsetMinutes : 0;
  const local = new Date(nowUtc.getTime() + offset * 60 * 1000);
  const localMidnight = Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate(),
  );
  return new Date(localMidnight - offset * 60 * 1000);
}

/**
 * Whether this user still needs a streak nudge.
 *
 * @param {object} data A user document.
 * @param {Date} nowUtc The current instant.
 * @param {function(*): Date} toDate Converts a stored timestamp to a Date.
 * @return {boolean} True when they have not studied today.
 */
function needsStreakReminder(data, nowUtc, toDate) {
  if (!isReminderCandidate(data)) return false;
  if (!isReminderHourFor(data, nowUtc)) return false;

  const lastLogin = data.streak && data.streak.lastLogin;
  if (!lastLogin) return true;

  const dayStart = startOfLocalDay(data.utcOffsetMinutes, nowUtc);
  return toDate(lastLogin) < dayStart;
}

/**
 * Whether this user still needs a daily goal nudge.
 *
 * Lands two hours before the streak reminder so there is still an evening in
 * which to act on it, matching the app's own local schedule.
 *
 * @param {object} data A user document.
 * @param {Date} nowUtc The current instant.
 * @return {boolean} True when they are short of their goal.
 */
function needsDailyGoalReminder(data, nowUtc) {
  if (!isReminderCandidate(data)) return false;

  const goalHour = (reminderHourFor(data) - 2 + 24) % 24;
  const offset = data && data.utcOffsetMinutes;
  if (localHour(offset, nowUtc) !== goalHour) return false;

  const goal = data.dailyGoal || {};
  const target = Number.isFinite(goal.target) ? goal.target : 50;
  const todayPoints = Number.isFinite(goal.todayPoints) ? goal.todayPoints : 0;

  // A target of zero is complete by definition; without this guard every such
  // user would be nudged daily about a goal they cannot fail.
  if (target <= 0) return false;
  return todayPoints < target;
}

/**
 * Points still needed to hit the goal.
 *
 * @param {object} data A user document.
 * @return {number} Remaining points, never below 1.
 */
function pointsRemaining(data) {
  const goal = (data && data.dailyGoal) || {};
  const target = Number.isFinite(goal.target) ? goal.target : 50;
  const todayPoints = Number.isFinite(goal.todayPoints) ? goal.todayPoints : 0;
  return Math.max(1, target - todayPoints);
}

/**
 * Split a list into fixed-size batches.
 *
 * @param {Array} items The list.
 * @param {number} size Maximum batch size.
 * @return {Array<Array>} The batches.
 */
function chunk(items, size = MULTICAST_LIMIT) {
  if (size < 1) throw new RangeError("chunk size must be at least 1");
  const out = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

/**
 * The body of a streak reminder.
 *
 * @param {number} currentStreak Days in a row.
 * @return {string} Message body.
 */
function streakBody(currentStreak) {
  return currentStreak > 0 ?
    `You're on a ${currentStreak}-day streak — open B1nary to keep it going.` :
    "Start a streak today — open B1nary and complete a lesson.";
}

module.exports = {
  PAGE_SIZE,
  MULTICAST_LIMIT,
  chunk,
  isCoveredByLocalReminders,
  isReminderCandidate,
  isReminderHourFor,
  localHour,
  needsDailyGoalReminder,
  needsStreakReminder,
  pointsRemaining,
  reminderHourFor,
  startOfLocalDay,
  streakBody,
};
