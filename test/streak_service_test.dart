/// Behavioural tests for [StreakService] against a fake Firestore.
///
/// SCOPE NOTE: these cover the streak/badge/goal *logic* — increments, resets,
/// thresholds, idempotence within a day. They deliberately do NOT assert that
/// a write stored a nested map rather than a literal 'streak.current' field:
/// fake_cloud_firestore expands dot-notation in set() as well as update(),
/// which real Firestore does not, so such an assertion passes whether the code
/// is right or wrong. That correctness lives in test/service_backend_test.dart
/// against expandDotNotation directly, where it can actually fail.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

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
    // recordLogin refuses to write unless the clock is calibrated, which is
    // the point: a device clock is not trusted. Zero offset means "the server
    // agrees with this test's DateTime.now()".
    ServerClock.useOffset(Duration.zero);
  });

  tearDown(() {
    ServiceBackend.reset();
    ServerClock.reset();
  });

  DocumentReference<Map<String, dynamic>> userDoc() =>
      db.collection('users').doc(uid);

  Future<Map<String, dynamic>> read() async =>
      (await userDoc().get()).data() ?? {};

  /// Seed the user document the way the app's own writes shape it.
  Future<void> seed(Map<String, dynamic> data) =>
      userDoc().set(data, SetOptions(merge: true));

  Timestamp daysAgo(int n) => Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: n)),
      );

  Future<Set<String>> badges() async =>
      ((await read())['badges'] as Map?)?.keys.map((k) => k.toString()).toSet() ??
      <String>{};

  group('recordLogin on a document that does not exist yet', () {
    // Reachable in production: only email/password signup creates
    // `users/{uid}`. A Google or Apple sign-in does not, and the FCM token
    // write that would otherwise create it is skipped on web and whenever the
    // user declines the notification prompt. HomeScreen then calls
    // checkAndUpdateStreak() against a missing document.

    test('starts the streak at 1 and stores it readably', () async {
      await StreakService.recordLogin();
      final data = await read();

      expect(data['streak'], isA<Map>());
      expect((data['streak'] as Map)['current'], 1);
      expect((data['streak'] as Map)['longest'], 1);
    });

    test('the streak it wrote is readable back by getStats', () async {
      await StreakService.recordLogin();
      final stats = await StreakService.getStats();
      final streak = StreakData.fromMap(
        Map<String, dynamic>.from(stats['streak'] as Map? ?? {}),
      );
      expect(streak.current, 1);
      expect(streak.lastLogin, isNotNull);
    });

    test('a second day actually advances the streak', () async {
      // The real symptom: if day one stored an unreadable lastLogin, day two
      // reads null and resets to 1 forever. The streak never reaches 2.
      await StreakService.recordLogin();

      final stored = await read();
      final streak = Map<String, dynamic>.from(stored['streak'] as Map);
      await userDoc().set({
        'streak': {...streak, 'lastLogin': daysAgo(1)},
      }, SetOptions(merge: true));

      await StreakService.recordLogin();
      expect((await read())['streak']['current'], 2);
    });
  });

  group('recordLogin on an existing document', () {
    test('a first-ever login starts the streak at 1', () async {
      await seed({'name': 'Ada'});
      await StreakService.recordLogin();
      expect((await read())['streak']['current'], 1);
    });

    test('a consecutive day increments', () async {
      await seed({
        'streak': {'current': 4, 'longest': 4, 'lastLogin': daysAgo(1)},
      });
      await StreakService.recordLogin();
      expect((await read())['streak']['current'], 5);
    });

    test('a second login the same day does not double-count', () async {
      await seed({
        'streak': {'current': 4, 'longest': 4, 'lastLogin': Timestamp.now()},
      });
      await StreakService.recordLogin();
      expect((await read())['streak']['current'], 4);
    });

    test('a missed day resets to 1', () async {
      await seed({
        'streak': {'current': 9, 'longest': 9, 'lastLogin': daysAgo(3)},
      });
      await StreakService.recordLogin();
      expect((await read())['streak']['current'], 1);
    });

    test('a reset keeps the longest streak on record', () async {
      await seed({
        'streak': {'current': 9, 'longest': 12, 'lastLogin': daysAgo(3)},
      });
      await StreakService.recordLogin();
      expect((await read())['streak']['longest'], 12);
    });

    test('a new record raises the longest streak', () async {
      await seed({
        'streak': {'current': 12, 'longest': 12, 'lastLogin': daysAgo(1)},
      });
      await StreakService.recordLogin();
      expect((await read())['streak']['longest'], 13);
    });
  });

  group('streak badges', () {
    test('a 7-day streak awards streak_7', () async {
      await seed({
        'streak': {'current': 6, 'longest': 6, 'lastLogin': daysAgo(1)},
      });
      await StreakService.recordLogin();

      expect(await badges(), contains('streak_7'));
    });

    test('a 6-day streak awards nothing yet', () async {
      await seed({
        'streak': {'current': 5, 'longest': 5, 'lastLogin': daysAgo(1)},
      });
      await StreakService.recordLogin();
      expect(await badges(), isNot(contains('streak_7')));
    });

    test('the 30 day badge lands at its threshold', () async {
      await seed({
        'streak': {'current': 29, 'longest': 29, 'lastLogin': daysAgo(1)},
      });
      await StreakService.recordLogin();
      expect(await badges(), containsAll(<String>['streak_7', 'streak_30']));
      expect(await badges(), isNot(contains('streak_100')));
    });

    test('fetchAll surfaces an earned badge as earned', () async {
      await seed({
        'streak': {'current': 6, 'longest': 6, 'lastLogin': daysAgo(1)},
      });
      await StreakService.recordLogin();

      final result = await StreakService.fetchAll();
      final seven = result.badges.firstWhere((b) => b.id == 'streak_7');
      expect(seven.isEarned, isTrue);
      expect(result.streak.current, 7);
    });
  });

  group('daily goal', () {
    test('addPoints accumulates on a fresh document', () async {
      await StreakService.addPoints(Activity.lesson);
      await StreakService.addPoints(Activity.quizPass);
      expect((await read())['dailyGoal']['todayPoints'],
          pointsFor(Activity.lesson) + pointsFor(Activity.quizPass));
    });

    test('logging in on a new day resets the points', () async {
      await seed({
        'streak': {'current': 2, 'longest': 2, 'lastLogin': daysAgo(1)},
        'dailyGoal': {'target': 50, 'todayPoints': 40, 'lastReset': daysAgo(1)},
      });
      await StreakService.recordLogin();
      expect((await read())['dailyGoal']['todayPoints'], 0);
    });

    test('logging in twice in one day does not wipe progress', () async {
      await seed({
        'streak': {'current': 2, 'longest': 2, 'lastLogin': Timestamp.now()},
        'dailyGoal': {
          'target': 50,
          'todayPoints': 40,
          'lastReset': Timestamp.now(),
        },
      });
      await StreakService.recordLogin();
      expect((await read())['dailyGoal']['todayPoints'], 40);
    });

    test('setDailyTarget stores the new target', () async {
      await StreakService.setDailyTarget(80);
      expect((await read())['dailyGoal']['target'], 80);
    });
  });

  group('quiz and lesson records', () {
    test('a passed quiz counts, scores points and awards quiz_first', () async {
      await StreakService.recordQuizPass(score: 7, total: 10);
      final data = await read();
      expect(data['quizzesPassed'], 1);
      expect(data['dailyGoal']['todayPoints'], 20);
      expect(await badges(), contains('quiz_first'));
      expect(await badges(), isNot(contains('quiz_perfect')));
    });

    test('a perfect score also awards quiz_perfect', () async {
      await StreakService.recordQuizPass(score: 10, total: 10);
      expect(await badges(), contains('quiz_perfect'));
    });

    test('the tenth pass awards quiz_10', () async {
      await seed({'quizzesPassed': 9});
      await StreakService.recordQuizPass(score: 6, total: 10);
      expect((await read())['quizzesPassed'], 10);
      expect(await badges(), contains('quiz_10'));
    });

    test('recordLessonComplete counts the lesson and scores points', () async {
      await StreakService.recordLessonComplete(
        courseId: 'c1',
        moduleId: 'module-2',
        moduleTitle: 'Subnetting',
      );
      final data = await read();
      expect(data['lessonsCompleted'], 1);
      expect(data['dailyGoal']['todayPoints'], 10);
      expect((data['completedLessons'] as List).single['moduleId'], 'module-2');
    });
  });

  group('signed out', () {
    test('recordLogin writes nothing when there is no uid', () async {
      ServiceBackend.useFake(db, uid: null);
      await StreakService.recordLogin();
      expect((await userDoc().get()).exists, isFalse);
    });

    test('getStats is empty when there is no uid', () async {
      ServiceBackend.useFake(db, uid: null);
      expect(await StreakService.getStats(), isEmpty);
    });
  });
}
