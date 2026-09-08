/// The two guarantees that make the streak worth having.
///
/// 1. A streak day is decided by the server clock, so it cannot be farmed by
///    moving the device clock — and, critically, an uncalibrated clock blocks
///    the write rather than falling back to device time. The fallback IS the
///    exploit, so its absence needs a test that would notice it coming back.
///
/// 2. Course badges survive the change of storage scheme, so an account that
///    finished a course under the old `badges.complete_<courseId>` key still
///    gets credit.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary/course_catalog.dart';
import 'package:binary/screens/notification_backend.dart';
import 'package:binary/screens/server_clock.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:binary/screens/streak_logic.dart';
import 'package:binary/screens/streak_service.dart';

const uid = 'test-uid';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: uid);
    // Badge awards fire notifications; keep them off the platform channel.
    NotificationBackendHolder.useFake(FakeNotificationBackend());
  });

  tearDown(() {
    ServiceBackend.reset();
    ServerClock.reset();
    NotificationBackendHolder.reset();
  });

  DocumentReference<Map<String, dynamic>> userDoc() =>
      db.collection('users').doc(uid);

  Future<Map<String, dynamic>> read() async =>
      (await userDoc().get()).data() ?? {};

  group('ServerClock', () {
    test('now() throws rather than guessing when uncalibrated', () {
      ServerClock.reset();
      expect(ServerClock.isCalibrated, isFalse);
      // Returning DateTime.now() here instead of throwing is precisely the
      // exploit: anyone wanting free streak days need only break the
      // calibration read.
      expect(ServerClock.now, throwsStateError);
    });

    test('calibrating against the server makes now() usable', () async {
      final ok = await ServerClock.calibrate(userDoc());
      expect(ok, isTrue);
      expect(ServerClock.isCalibrated, isTrue);
      expect(ServerClock.now(), isA<DateTime>());
    });

    test('calibration writes only lastSeenAt', () async {
      await ServerClock.calibrate(userDoc());

      // firestore.rules rejects a create that carries any entitlement field,
      // so a calibration that creates the document must stay minimal.
      expect((await read()).keys, ['lastSeenAt']);
    });

    test('the measured offset drives now()', () async {
      ServerClock.useOffset(const Duration(days: 3));
      final drift = ServerClock.now().difference(DateTime.now());

      expect(drift.inHours, closeTo(72, 1));
    });
  });

  group('an uncalibrated clock blocks the streak', () {
    test('recordLogin writes no streak when calibration fails', () async {
      ServerClock.failCalibration(true);

      await StreakService.recordLogin();

      // If a fallback to DateTime.now() were ever reintroduced, this document
      // would carry a streak of 1 and this assertion would fail. That is the
      // whole point of the test: the fallback is the exploit.
      expect((await read())['streak'], isNull);
    });

    test('an existing streak is left untouched, not reset', () async {
      await userDoc().set({
        'streak': {'current': 12, 'longest': 12, 'lastLogin': Timestamp.now()},
      });
      ServerClock.failCalibration(true);

      await StreakService.recordLogin();

      // A user who opens the app offline must not be punished for it.
      expect((await read())['streak']['current'], 12);
    });

    test('calibration succeeding again resumes the streak', () async {
      ServerClock.failCalibration(true);
      await StreakService.recordLogin();
      expect((await read())['streak'], isNull);

      ServerClock.failCalibration(false);
      await StreakService.recordLogin();
      expect((await read())['streak']['current'], 1);
    });
  });

  group('legacy course badges', () {
    test('an old complete_<id> key still counts as a finished course', () {
      final ids = StreakService.completedCourseIds({
        'badges': {
          'complete_cloud-fund': Timestamp.now(),
          'streak_7': Timestamp.now(),
        },
      });

      expect(ids, {'cloud-fund'});
    });

    test('the array and the legacy keys are merged, not duplicated', () {
      final ids = StreakService.completedCourseIds({
        'completedCourses': ['cloud-fund', 'net-pro'],
        'badges': {'complete_cloud-fund': Timestamp.now()},
      });

      expect(ids, {'cloud-fund', 'net-pro'});
    });

    test('a document with neither reports no courses', () {
      expect(StreakService.completedCourseIds({}), isEmpty);
    });

    test('an account carrying only legacy keys earns course_first', () async {
      await userDoc().set({
        'badges': {'complete_cloud-fund': Timestamp.now()},
      });
      ServerClock.useOffset(Duration.zero);

      await StreakService.recordLogin();

      final badges = (await read())['badges'] as Map;
      expect(badges.keys, contains('course_first'));
    });

    test('three legacy courses earn course_3', () async {
      await userDoc().set({
        'badges': {
          'complete_a': Timestamp.now(),
          'complete_b': Timestamp.now(),
          'complete_c': Timestamp.now(),
        },
      });
      ServerClock.useOffset(Duration.zero);

      await StreakService.recordLogin();

      final badges = (await read())['badges'] as Map;
      expect(badges.keys, containsAll(['course_first', 'course_3']));
    });
  });

  group('badge counting', () {
    test('orphan complete_ keys do not count towards the displayed total', () {
      // The "1 / 9 with nothing lit" bug: raw badges.length counted keys the
      // grid cannot display.
      final counted = knownEarnedBadges(
        {'streak_7', 'complete_cloud-fund', 'complete_net-pro'},
      );

      expect(counted, {'streak_7'});
      expect(counted.length, 1);
    });

    test('every id the app can award is countable', () {
      // If kAllBadges and kKnownBadgeIds ever drift apart, a real badge would
      // light up in the grid but not increment the counter.
      expect(
        knownEarnedBadges(kAllBadges.map((b) => b.id)).length,
        kAllBadges.length,
      );
    });
  });

  group('course_all against the real catalogue', () {
    test('finishing every shipped course earns it', () {
      final awarded = badgesToAward(
        streak: 1,
        quizzesPassed: 0,
        coursesCompleted: kCourseCatalog.length,
        coursesAvailable: kCourseCatalog.length,
        perfectQuiz: false,
        alreadyEarned: {},
      );

      expect(awarded, contains('course_all'));
    });

    test('an empty catalogue does not hand it to everyone', () {
      final awarded = badgesToAward(
        streak: 1,
        quizzesPassed: 0,
        coursesCompleted: 0,
        coursesAvailable: 0,
        perfectQuiz: false,
        alreadyEarned: {},
      );

      expect(awarded, isNot(contains('course_all')));
    });
  });
}
