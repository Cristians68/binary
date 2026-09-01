import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/notification_prefs.dart';
import 'package:binary/screens/notification_schedule.dart';

Set<int> idsFor(NotificationPrefs p) =>
    remindersFor(p).map((r) => r.id).toSet();

void main() {
  group('remindersFor', () {
    test('schedules all three by default', () {
      expect(
        idsFor(NotificationPrefs.defaults),
        {kIdDailyGoal, kIdStreakReminder, kIdNewContent},
      );
    });

    test('the master switch off schedules nothing at all', () {
      // The whole point of the rebuild: the settings toggle must actually
      // remove notifications from the device, not just write a flag.
      expect(
        remindersFor(const NotificationPrefs(master: false)),
        isEmpty,
      );
    });

    test('master off wins even with every type enabled', () {
      expect(
        idsFor(const NotificationPrefs(
          master: false,
          streakReminder: true,
          dailyGoal: true,
          newContent: true,
        )),
        isEmpty,
      );
    });

    group('each toggle removes exactly its own reminder', () {
      test('streak off', () {
        expect(
          idsFor(const NotificationPrefs(streakReminder: false)),
          {kIdDailyGoal, kIdNewContent},
        );
      });
      test('daily goal off', () {
        expect(
          idsFor(const NotificationPrefs(dailyGoal: false)),
          {kIdStreakReminder, kIdNewContent},
        );
      });
      test('new content off', () {
        expect(
          idsFor(const NotificationPrefs(newContent: false)),
          {kIdDailyGoal, kIdStreakReminder},
        );
      });
    });

    test('every combination of the three toggles yields the matching set', () {
      for (final streak in [true, false]) {
        for (final goal in [true, false]) {
          for (final content in [true, false]) {
            final prefs = NotificationPrefs(
              streakReminder: streak,
              dailyGoal: goal,
              newContent: content,
            );
            final expected = <int>{
              if (goal) kIdDailyGoal,
              if (streak) kIdStreakReminder,
              if (content) kIdNewContent,
            };
            expect(idsFor(prefs), expected,
                reason: 'streak=$streak goal=$goal content=$content');
          }
        }
      }
    });

    test('ids are unique so no reminder silently replaces another', () {
      final ids = remindersFor(NotificationPrefs.defaults).map((r) => r.id);
      expect(ids.toSet().length, ids.length);
    });

    test('every scheduled id is one the apply step knows to cancel', () {
      // A reminder scheduled under an id absent from kManagedReminderIds
      // could never be turned off again.
      for (final r in remindersFor(NotificationPrefs.defaults)) {
        expect(kManagedReminderIds, contains(r.id),
            reason: '${r.id} would be orphaned on the device');
      }
    });

    test('the chosen reminder time drives the streak reminder', () {
      final r = remindersFor(const NotificationPrefs(
        reminderHour: 7,
        reminderMinute: 30,
      )).firstWhere((r) => r.id == kIdStreakReminder);
      expect(r.hour, 7);
      expect(r.minute, 30);
    });

    test('the goal check-in lands two hours before the streak reminder', () {
      final list = remindersFor(const NotificationPrefs(reminderHour: 20));
      final goal = list.firstWhere((r) => r.id == kIdDailyGoal);
      final streak = list.firstWhere((r) => r.id == kIdStreakReminder);
      expect(goal.hour, 18);
      expect(streak.hour, 20);
    });

    test('reminder hours stay valid for every chosen hour', () {
      for (var h = 0; h < 24; h++) {
        for (final r in remindersFor(NotificationPrefs(reminderHour: h))) {
          expect(r.hour, inInclusiveRange(0, 23), reason: 'chosen hour $h');
          expect(r.minute, inInclusiveRange(0, 59));
        }
      }
    });

    test('new content is weekly on a Monday and ignores the chosen time', () {
      final r = remindersFor(const NotificationPrefs(reminderHour: 6))
          .firstWhere((r) => r.id == kIdNewContent);
      expect(r.repeat, Repeat.weekly);
      expect(r.weekday, DateTime.monday);
      expect(r.hour, 9);
    });

    test('the daily reminders repeat daily with no weekday', () {
      for (final r in remindersFor(NotificationPrefs.defaults)
          .where((r) => r.id != kIdNewContent)) {
        expect(r.repeat, Repeat.daily);
        expect(r.weekday, isNull);
      }
    });

    test('every reminder carries a tappable route', () {
      for (final r in remindersFor(NotificationPrefs.defaults)) {
        expect(r.payload, startsWith('/'));
        expect(r.title, isNotEmpty);
        expect(r.body, isNotEmpty);
      }
    });
  });

  group('notification ids', () {
    test('the one-off ids are not managed as repeating reminders', () {
      // Cancelling the managed set must not wipe a badge or course-complete
      // notification the user is currently looking at.
      expect(kManagedReminderIds, isNot(contains(kIdBadgeEarned)));
      expect(kManagedReminderIds, isNot(contains(kIdCourseComplete)));
    });

    test('all five ids are distinct', () {
      final all = {
        kIdStreakReminder,
        kIdDailyGoal,
        kIdCourseComplete,
        kIdBadgeEarned,
        kIdNewContent,
      };
      expect(all.length, 5);
    });
  });
}
