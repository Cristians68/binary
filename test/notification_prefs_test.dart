import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/notification_prefs.dart';
import 'package:binary/screens/notification_schedule.dart';

void main() {
  group('NotificationPrefs defaults', () {
    test('everything is on at 20:00', () {
      const p = NotificationPrefs.defaults;
      expect(p.master, isTrue);
      expect(p.streakReminder, isTrue);
      expect(p.dailyGoal, isTrue);
      expect(p.newContent, isTrue);
      expect(p.reminderHour, 20);
      expect(p.reminderMinute, 0);
    });
  });

  group('fromMap', () {
    test('an absent map yields the defaults', () {
      expect(NotificationPrefs.fromMap(null), NotificationPrefs.defaults);
      expect(NotificationPrefs.fromMap({}), NotificationPrefs.defaults);
    });

    test('a user who opted out before this feature stays opted out', () {
      // The only signal for a pre-existing user is the legacy top-level
      // boolean. Ignoring it would silently re-enable notifications for
      // everyone who had turned them off.
      final p = NotificationPrefs.fromMap(null, legacyEnabled: false);
      expect(p.master, isFalse);
    });

    test('an explicit prefs map wins over the legacy boolean', () {
      final p = NotificationPrefs.fromMap(
        {'master': true},
        legacyEnabled: false,
      );
      expect(p.master, isTrue);
    });

    test('round-trips through toMap', () {
      const p = NotificationPrefs(
        master: true,
        streakReminder: false,
        dailyGoal: true,
        newContent: false,
        reminderHour: 7,
        reminderMinute: 45,
      );
      expect(NotificationPrefs.fromMap(p.toMap()), p);
    });

    test('round-trips through json', () {
      const p = NotificationPrefs(streakReminder: false, reminderHour: 6);
      expect(NotificationPrefs.fromJson(p.toJson()), p);
    });

    test('malformed json falls back to defaults rather than throwing', () {
      expect(NotificationPrefs.fromJson('not json'),
          NotificationPrefs.defaults);
      expect(NotificationPrefs.fromJson('[1,2,3]'), NotificationPrefs.defaults);
      expect(NotificationPrefs.fromJson(null), NotificationPrefs.defaults);
      expect(NotificationPrefs.fromJson(''), NotificationPrefs.defaults);
    });

    test('a non-boolean flag falls back instead of crashing', () {
      final p = NotificationPrefs.fromMap({'streakReminder': 'yes'});
      expect(p.streakReminder, isTrue);
    });

    group('reminder time is coerced into range', () {
      // An out-of-range hour reaches zonedSchedule and throws, which would
      // take down every reminder rather than just the malformed one.
      test('hour 24 falls back to 20',
          () => expect(
              NotificationPrefs.fromMap({'reminderHour': 24}).reminderHour, 20));
      test('negative hour falls back to 20',
          () => expect(
              NotificationPrefs.fromMap({'reminderHour': -1}).reminderHour, 20));
      test('minute 60 falls back to 0',
          () => expect(
              NotificationPrefs.fromMap({'reminderMinute': 60}).reminderMinute,
              0));
      test('a string hour falls back to 20',
          () => expect(
              NotificationPrefs.fromMap({'reminderHour': '8'}).reminderHour,
              20));
      test('hour 0 is valid and kept',
          () => expect(
              NotificationPrefs.fromMap({'reminderHour': 0}).reminderHour, 0));
      test('hour 23 is valid and kept',
          () => expect(
              NotificationPrefs.fromMap({'reminderHour': 23}).reminderHour, 23));
    });
  });

  group('anySchedulable', () {
    test('false when the master switch is off even if types are on', () {
      expect(const NotificationPrefs(master: false).anySchedulable, isFalse);
    });
    test('false when every type is off', () {
      expect(
        const NotificationPrefs(
                streakReminder: false, dailyGoal: false, newContent: false)
            .anySchedulable,
        isFalse,
      );
    });
    test('true when one type survives', () {
      expect(
        const NotificationPrefs(
                streakReminder: false, dailyGoal: false, newContent: true)
            .anySchedulable,
        isTrue,
      );
    });
  });

  group('copyWith', () {
    test('changes only the named field', () {
      const p = NotificationPrefs.defaults;
      final q = p.copyWith(dailyGoal: false);
      expect(q.dailyGoal, isFalse);
      expect(q.streakReminder, p.streakReminder);
      expect(q.reminderHour, p.reminderHour);
    });

    test('can turn a flag back on', () {
      const p = NotificationPrefs(dailyGoal: false);
      expect(p.copyWith(dailyGoal: true).dailyGoal, isTrue);
    });
  });

  group('goalHourFor', () {
    test('is two hours before the reminder', () {
      expect(goalHourFor(20), 18);
      expect(goalHourFor(9), 7);
    });

    test('wraps rather than going negative', () {
      // A negative hour would throw inside zonedSchedule.
      expect(goalHourFor(1), 23);
      expect(goalHourFor(0), 22);
      expect(goalHourFor(2), 0);
    });

    test('always lands in a valid hour range', () {
      for (var h = 0; h < 24; h++) {
        expect(goalHourFor(h), inInclusiveRange(0, 23), reason: 'hour $h');
      }
    });
  });
}
