/// Tests for the half of notifications that touches the device.
///
/// `remindersFor` — which reminders *should* exist — is covered in
/// `notification_schedule_test.dart`. This file covers what
/// `NotificationService.applyPrefs` actually does with that list, and the tap
/// routing that a payload triggers. Both were previously untestable: every
/// call went straight into `flutter_local_notifications`, which throws
/// `MissingPluginException` off-device, and the tap handler was a `debugPrint`.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary/screens/notification_backend.dart';
import 'package:binary/screens/notification_prefs.dart';
import 'package:binary/screens/notification_schedule.dart';
import 'package:binary/screens/notification_service.dart';
import 'package:binary/screens/service_backend.dart';

const uid = 'test-uid';

void main() {
  late FakeNotificationBackend backend;
  late FakeFirebaseFirestore db;

  setUp(() {
    backend = FakeNotificationBackend();
    NotificationBackendHolder.useFake(backend);
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: uid);
    pendingNotificationRoute.value = null;
  });

  tearDown(() {
    NotificationBackendHolder.reset();
    ServiceBackend.reset();
    pendingNotificationRoute.value = null;
  });

  group('applyPrefs', () {
    test('the default preferences schedule all three reminders', () async {
      await NotificationService.applyPrefs(NotificationPrefs.defaults);

      expect(backend.liveIds,
          {kIdStreakReminder, kIdDailyGoal, kIdNewContent});
    });

    test('turning the master switch off leaves nothing scheduled', () async {
      await NotificationService.applyPrefs(NotificationPrefs.defaults);
      await NotificationService.applyPrefs(
          const NotificationPrefs(master: false));

      // The bug this whole feature exists to kill: the old master switch wrote
      // a Firestore flag and never cancelled a single notification, so a user
      // who turned reminders off kept receiving them.
      expect(backend.liveIds, isEmpty);
    });

    test('turning one type off removes only that one', () async {
      await NotificationService.applyPrefs(NotificationPrefs.defaults);
      await NotificationService.applyPrefs(
          const NotificationPrefs(streakReminder: false));

      expect(backend.liveIds, {kIdDailyGoal, kIdNewContent});
      expect(backend.liveIds, isNot(contains(kIdStreakReminder)));
    });

    test('turning a type back on restores it', () async {
      await NotificationService.applyPrefs(
          const NotificationPrefs(newContent: false));
      expect(backend.liveIds, isNot(contains(kIdNewContent)));

      await NotificationService.applyPrefs(NotificationPrefs.defaults);
      expect(backend.liveIds, contains(kIdNewContent));
    });

    test('it is idempotent — applying twice schedules each id once', () async {
      await NotificationService.applyPrefs(NotificationPrefs.defaults);
      backend.clear();
      await NotificationService.applyPrefs(NotificationPrefs.defaults);

      final ids = backend.scheduled.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every managed id is cancelled before rescheduling', () async {
      await NotificationService.applyPrefs(NotificationPrefs.defaults);

      // Cancelling the managed ids specifically, rather than cancelAll(), is
      // what stops an unrelated settings change wiping a badge notification
      // the user has not yet dismissed.
      expect(backend.cancelled.toSet(), kManagedReminderIds.toSet());
      expect(backend.cancelled, isNot(contains(kIdBadgeEarned)));
      expect(backend.cancelled, isNot(contains(kIdCourseComplete)));
    });

    test('the chosen reminder time reaches the scheduled reminder', () async {
      await NotificationService.applyPrefs(
        const NotificationPrefs(reminderHour: 7, reminderMinute: 30),
      );

      final streak =
          backend.scheduled.firstWhere((r) => r.id == kIdStreakReminder);
      expect(streak.hour, 7);
      expect(streak.minute, 30);
    });

    test('a schedulable user is flagged so the server does not double up',
        () async {
      await NotificationService.applyPrefs(NotificationPrefs.defaults);

      final data = (await db.collection('users').doc(uid).get()).data();
      expect(data?['usesLocalReminders'], isTrue);
    });

    test('a user with everything off is not flagged', () async {
      await NotificationService.applyPrefs(
          const NotificationPrefs(master: false));

      final data = (await db.collection('users').doc(uid).get()).data();
      // reminderCandidates() skips flagged users, so a user with no local
      // reminders must NOT carry the flag or they get no nudge at all.
      expect(data?['usesLocalReminders'], isFalse);
    });
  });

  group('one-off notifications', () {
    test('a badge notification carries the badges route', () async {
      await NotificationService.showBadgeEarnedNotification('Graduate', '🎓');

      expect(backend.shown.single.id, kIdBadgeEarned);
      expect(backend.shown.single.payload, routeBadges);
    });

    test('course complete carries the progress route', () async {
      await NotificationService.showCourseCompleteNotification('Cloud');

      expect(backend.shown.single.id, kIdCourseComplete);
      expect(backend.shown.single.payload, routeProgress);
    });
  });

  group('tap routing', () {
    test('a known route becomes the pending route', () {
      NotificationService.handlePayload(routeCourses);
      expect(pendingNotificationRoute.value, routeCourses);
    });

    test('an unknown payload is ignored', () {
      // Payloads are persisted by the OS and survive an app update, so one
      // written by an older build can arrive at a newer one.
      NotificationService.handlePayload('/definitely-not-a-route');
      expect(pendingNotificationRoute.value, isNull);
    });

    test('null and empty payloads are ignored', () {
      NotificationService.handlePayload(null);
      expect(pendingNotificationRoute.value, isNull);
      NotificationService.handlePayload('');
      expect(pendingNotificationRoute.value, isNull);
    });

    test('every scheduled reminder carries a route that resolves', () {
      // Guards against a reminder shipping a payload the whitelist rejects,
      // which would silently make that notification a dead end again.
      for (final reminder in remindersFor(NotificationPrefs.defaults)) {
        expect(kNotificationRoutes, contains(reminder.payload));
        expect(tabIndexForRoute(reminder.payload), isNotNull);
      }
    });

    test('each route maps to the tab its screen lives on', () {
      expect(tabIndexForRoute(routeHome), 0);
      expect(tabIndexForRoute(routeCourses), 1);
      expect(tabIndexForRoute(routeProgress), 2);
      // Badges is not a tab; it is pushed on top of Progress.
      expect(tabIndexForRoute(routeBadges), 2);
      expect(routePushesBadges(routeBadges), isTrue);
      expect(routePushesBadges(routeProgress), isFalse);
    });

    test('an unroutable string has no tab', () {
      expect(tabIndexForRoute('/nope'), isNull);
    });
  });

  group('the fake backend itself', () {
    // FakeNotificationBackend is the instrument every assertion above depends
    // on, so its ordering behaviour is checked directly rather than assumed.
    test('a cancel after a schedule kills the id', () async {
      await backend.schedule(remindersFor(NotificationPrefs.defaults).first);
      final id = backend.scheduled.first.id;
      expect(backend.liveIds, contains(id));

      await backend.cancel(id);
      expect(backend.liveIds, isNot(contains(id)));
    });

    test('a schedule after a cancel revives the id', () async {
      final reminder = remindersFor(NotificationPrefs.defaults).first;
      await backend.cancel(reminder.id);
      await backend.schedule(reminder);
      expect(backend.liveIds, contains(reminder.id));
    });
  });
}
