import 'notification_prefs.dart';

/// Stable notification ids.
///
/// These were bare literals (`1`, `2`, `3`, `4`) passed to `zonedSchedule` and
/// `cancel` at four separate call sites. An id reused by accident silently
/// replaces an existing notification, so they are named and centralised.
const int kIdStreakReminder = 1;
const int kIdDailyGoal = 2;
const int kIdCourseComplete = 3;
const int kIdBadgeEarned = 4;
const int kIdNewContent = 5;

/// Every id this app schedules on a repeating basis.
///
/// `applyPrefs` cancels exactly these before rescheduling, rather than calling
/// `cancelAll()`, so a one-off notification already on screen (a badge the user
/// just earned) is not wiped by an unrelated settings change.
const List<int> kManagedReminderIds = [
  kIdStreakReminder,
  kIdDailyGoal,
  kIdNewContent,
];

/// How often a reminder repeats.
enum Repeat { daily, weekly }

/// A reminder that should exist on the device, described without reference to
/// any plugin so the decision can be tested on its own.
class ScheduledReminder {
  final int id;
  final String title;
  final String body;
  final int hour;
  final int minute;
  final Repeat repeat;

  /// Weekday for [Repeat.weekly], using `DateTime.monday`..`DateTime.sunday`.
  final int? weekday;

  /// Route pushed when the user taps the notification.
  final String payload;

  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.payload,
    this.weekday,
  });

  @override
  bool operator ==(Object other) =>
      other is ScheduledReminder &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.hour == hour &&
      other.minute == minute &&
      other.repeat == repeat &&
      other.weekday == weekday &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(
      id, title, body, hour, minute, repeat, weekday, payload);

  @override
  String toString() =>
      'ScheduledReminder($id, ${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}, $repeat)';
}

/// The daily goal check-in lands two hours before the streak reminder, so the
/// user still has an evening in which to act on it. This preserves the
/// original fixed 18:00 / 20:00 pairing while making the pair movable.
int goalHourFor(int reminderHour) => (reminderHour - 2) % 24;

/// Exactly the reminders that should be scheduled for [prefs].
///
/// Pure. `applyPrefs` cancels [kManagedReminderIds] and then schedules this
/// list, which is what makes the settings toggles real: turning one off
/// removes it from this list, and the next apply deletes it from the device.
List<ScheduledReminder> remindersFor(NotificationPrefs prefs) {
  if (!prefs.master) return const [];

  final out = <ScheduledReminder>[];

  if (prefs.dailyGoal) {
    out.add(ScheduledReminder(
      id: kIdDailyGoal,
      title: '🎯 Daily goal check-in',
      body: "You haven't hit today's goal yet — a quick lesson will do it.",
      hour: goalHourFor(prefs.reminderHour),
      minute: prefs.reminderMinute,
      repeat: Repeat.daily,
      payload: '/home',
    ));
  }

  if (prefs.streakReminder) {
    out.add(ScheduledReminder(
      id: kIdStreakReminder,
      title: '🔥 Keep your streak alive',
      body: 'Open Binary and complete a lesson to keep your streak going.',
      hour: prefs.reminderHour,
      minute: prefs.reminderMinute,
      repeat: Repeat.daily,
      payload: '/home',
    ));
  }

  if (prefs.newContent) {
    out.add(const ScheduledReminder(
      id: kIdNewContent,
      title: '📚 New week, new lessons',
      body: 'Fresh lessons and quizzes are waiting in Binary.',
      hour: 9,
      minute: 0,
      repeat: Repeat.weekly,
      weekday: DateTime.monday,
      payload: '/courses',
    ));
  }

  return out;
}
