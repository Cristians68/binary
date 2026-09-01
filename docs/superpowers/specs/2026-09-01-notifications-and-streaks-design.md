# Notifications and streaks — design

Date: 2026-09-01
Status: approved, not yet implemented

## Why

The streak, daily-goal, badge and notification features are wired to the UI but
largely not wired to each other. An audit of `lib/` on 2026-09-01 found that
most of the gamification layer cannot fire at all. This document specifies the
repair and the rebuild.

## Audit findings

Each of these was verified by tracing callers across `lib/`, not inferred.

1. **The daily goal is permanently zero.** `dailyGoal.todayPoints` is written
   only by `StreakService.addPoints()`, which is called only by
   `recordLessonComplete()` and `recordQuizPass()`. Neither has a caller in
   `lib/`. The home-screen goal ring reads 0/50 for every user, forever, and
   the server `dailyGoalReminder` consequently fires for 100% of users daily.

2. **Six of nine badges are unreachable.** Only `streak_7`, `streak_30` and
   `streak_100` can be earned, via `HomeScreen` -> `recordLogin` ->
   `_checkStreakBadges`. `quiz_first`, `quiz_perfect`, `quiz_10`,
   `course_first`, `course_3` and `course_all` are awarded only inside the two
   dead methods above. `quizzesPassed` never increments.

3. **The badge counter counts badges that are never displayed.**
   `ProgressService._markCourseComplete` writes `badges.complete_<courseId>`,
   an id present in neither badge list. `badges_screen.dart:11` asserts in a
   comment that "IDs match exactly what StreakService and ProgressService
   award"; they do not. Both `badges_screen.dart` and `profile_screen.dart:70`
   count with `badges.length`, so completing a course shows "1 / 9" with no
   badge lit in the grid.

4. **The local reminder system is entirely dead code.**
   `scheduleStreakReminder()`, `scheduleDailyGoalReminder()` and
   `showBadgeEarnedNotification()` have no callers. The only local
   notification that can fire is course-complete.

5. **The notification settings sheet is partly non-functional.** The master
   toggle writes `notificationsEnabled` to Firestore but never schedules or
   cancels a local notification. The per-type rows beneath it pass a hardcoded
   `true` and are not connected to any state.

6. **Two competing streak writers.** `StreakService.recordLogin()` and
   `ProgressService._updateStreak()` independently implement the same day-diff
   against the same fields. They currently agree by coincidence.

7. **Streak integrity.** The streak derives from device-local `DateTime.now()`.
   Moving the device clock farms streaks and badges; genuine timezone travel
   corrupts them.

8. **Server reminders are not timezone-aware.** `streakReminder` runs at
   `0 18 * * *` UTC for every user — 10:00 in California, 04:00 in Sydney.
   `reminderCandidates()` also loads the entire `users` collection with no
   pagination and sends one message per user rather than multicasting.

## Decisions

| Question | Decision |
|---|---|
| Reminder delivery | Local-first on-device; server push later for what the device cannot know |
| Streak integrity | Server timestamps, client logic |
| Duplicate writers | One writer — `StreakService` |
| Orphan `complete_*` badges | Convert to canonical course badges, then stop writing them |
| Per-type toggles | Real, persisted per type |
| Permission prompt | Priming screen after the first completed lesson |

## Architecture

### Pure logic modules

Follows the established `quiz_logic.dart` / `review_logic.dart` pattern: no
Firebase imports, therefore unit-testable without a device or emulator.

**`lib/screens/streak_logic.dart`**

- `computeStreak({DateTime? lastLogin, required DateTime now})`
  returns `(int current, int longest, bool changed)`
- `needsDailyGoalReset({DateTime? lastReset, required DateTime today})`
- `badgesToAward({streak, quizzesPassed, coursesCompleted, coursesAvailable,
  perfectQuiz, alreadyEarned})` returns the set to award — the single place
  badge eligibility is decided
- `pointsFor(Activity activity)` — lesson 10, quiz 20, one definition

**`lib/screens/notification_prefs.dart`**

A value class holding `master`, `streakReminder`, `dailyGoal`, `newContent`,
`reminderHour` (default 20) and `reminderMinute` (default 0).

Persisted to `users/{uid}.notificationPrefs` as a nested map and mirrored into
SharedPreferences, so scheduling can run at app start before Firestore
resolves. The legacy `notificationsEnabled` boolean continues to be written in
sync, because the deployed-later Cloud Functions read it.

### Server-anchored time

`ServerClock` calibrates once per session: `recordLogin` adds
`lastSeenAt: FieldValue.serverTimestamp()` to the write it already performs,
reads it back, and caches the device-to-server offset. `ServerClock.now()`
returns device time plus that offset. `streak.lastLogin` changes from
`Timestamp.fromDate(now)` to `serverTimestamp()` so the stored anchor is also
authoritative.

**Hard rule: if calibration fails, the streak does not increment.** There is no
fallback to device time, because that fallback is the exploit. The offset is
injectable so tests can drive it directly.

Accepted tradeoff: incrementing a streak requires connectivity. This happens
once per day, in an app that already cannot read its user document offline.

### Notifications

`NotificationService` gains a single entry point, `applyPrefs(prefs)`. It
cancels all managed ids and re-schedules only what is enabled. It is idempotent
and is called on app start and on every preference change. This function is
what makes the settings sheet honest.

Supporting changes:

- Notification ids `1/2/3/4` become named constants.
- `_onNotificationTap` receives a payload route and routes through a global
  navigator key, replacing the current `debugPrint`.
- A `NotificationBackend` seam, mirroring the existing `ServiceBackend`
  (`useFake()` / `reset()`), so scheduling is assertable in tests without a
  device.

**Priming.** New `lib/screens/notification_priming_screen.dart`, shown once
after the first completed lesson, gated by a SharedPreferences flag. The OS
prompt fires only on opt-in. The unconditional `requestPermissions()` call at
`auth_service.dart:246` is removed.

### Wiring the dead code

| Call site | Now calls |
|---|---|
| `quiz_screen._showResults()` on pass | `StreakService.recordQuizPass(score:, total:)` |
| course completion | `StreakService.recordCourseComplete(...)` with real counts |
| `lesson_screen` completion | `StreakService.recordLessonComplete(...)` |
| any badge award | `showBadgeEarnedNotification(...)` |

`ProgressService._updateStreak` is deleted and `completeModule` calls
`StreakService` instead. `_markCourseComplete` stops writing
`badges.complete_*` and keeps `completedCourses`, which is the real data;
course badges derive from its length.

`setDailyTarget()` — currently dead — is wired to a control in the goal
settings UI.

### Migration

On first run of the new code, existing `badges.complete_*` keys are read to
reconstruct `completedCourses` and award the canonical `course_first`,
`course_3` and `course_all`, so existing accounts keep credit. The old keys are
left in place, harmless, because badge counters change from `badges.length` to
counting only known ids. That change alone fixes the "1 / 9 with nothing lit"
display bug in both `badges_screen.dart` and `profile_screen.dart:70`.

### Cloud Functions

Kept in the repo, not deployed — the project is on the Spark plan. The genuine
defects are fixed regardless so the code is correct whenever Blaze lands:

- per-user timezone rather than a fixed `0 18 * * *` UTC schedule
- pagination instead of loading the whole `users` collection
- `sendEachForMulticast` instead of one send per user

The two daily reminders are marked as superseded by local scheduling and gated
behind a dedupe flag so they cannot double-fire on the day they are enabled.
`newContentReminder` and `sendCourseCompleteNotification` remain server-side,
because the device cannot know about new content.

## Testing

New suites:

- `test/streak_logic_test.dart` — day boundaries, same-day, +1, +2, backwards
  clock, DST transitions, and a badge-eligibility table
- `test/notification_prefs_test.dart` — serialization, defaults, migration from
  the legacy `notificationsEnabled` boolean
- `test/notification_schedule_test.dart` — each preference combination maps to
  an exact set of scheduled ids

Extended:

- `test/streak_service_test.dart` — points, `quizzesPassed`, badge awards

**`fake_cloud_firestore` fidelity gap.** Its `set()` and `update()` both route
through `_setRawData`, which splits dotted keys, so an assertion that a nested
map was stored passes whether the code is right or wrong. Dot-notation
correctness is therefore asserted against `expandDotNotation` directly, as is
already done in `test/service_backend_test.dart`.

Every new suite is mutation-tested before its green result is trusted.

`flutter analyze` must stay at zero issues; it is a strict CI gate with no
`--no-fatal-infos`.

## Out of scope

- Changing the `dailyGoal` target default. It stays at 50. Once points actually
  accumulate, that number becomes load-bearing for the first time and there is
  no evidence for the right value; it becomes user-adjustable via
  `setDailyTarget()`, and the default should be revisited with real data.
- Leaderboards, social features, or any new badge beyond the existing nine plus
  derived course badges.
- The Blaze upgrade and function deployment, tracked in `docs/RELEASE.md`.

## Open question

The `dailyGoal` default of 50 points equals five lessons, or two quizzes plus a
lesson, per day. This is a product decision, deliberately left unchanged.
