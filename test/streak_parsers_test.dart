/// Tests for the shared parsers that turn a raw `users/{uid}` document into
/// streak, badge and goal values.
///
/// These exist because the Home tab and the Progress tab disagreed on screen.
/// Home listened to `StreakService.statsStream()` and showed a 1-day streak,
/// 30 points and two earned badges; Progress did three one-shot reads in
/// initState and showed "0 lessons completed / 0 badges earned / 0 day streak"
/// for the same account at the same moment. MainNavigation keeps the tabs in an
/// IndexedStack, so Progress's reads ran at app launch — before any of it
/// existed — and never ran again.
///
/// Progress now listens to the same stream. That stream hands out the raw
/// document map, so both screens have to convert it themselves, and two
/// screens converting the same map slightly differently is how the next
/// version of this bug would arrive. [StreakService.badgesFrom],
/// [StreakService.streakFrom] and [StreakService.goalFrom] are the one place
/// that conversion lives; this file pins them.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/streak_service.dart';

void main() {
  group('streakFrom', () {
    test('reads the current and longest counts', () {
      final data = <String, dynamic>{
        'streak': {'current': 5, 'longest': 12},
      };
      expect(StreakService.streakFrom(data).current, 5);
      expect(StreakService.streakFrom(data).longest, 12);
    });

    test('is 0 for a document that has never recorded a streak', () {
      expect(StreakService.streakFrom(<String, dynamic>{}).current, 0);
    });

    test('survives a nested map that is not Map<String, dynamic>', () {
      // Firestore on web hands back Map<Object?, Object?>. A plain cast throws
      // there, which is what `_safeMap` exists to absorb — and a throw inside
      // the listener is precisely how a screen ends up stuck showing zeros.
      final data = <String, dynamic>{
        'streak': <Object?, Object?>{'current': 3, 'longest': 3},
      };
      expect(StreakService.streakFrom(data).current, 3);
    });

    test('is 0 when the streak field is the wrong type entirely', () {
      final data = <String, dynamic>{'streak': 'not a map'};
      expect(StreakService.streakFrom(data).current, 0);
    });
  });

  group('badgesFrom', () {
    test('returns the full badge catalogue even for an empty document', () {
      final badges = StreakService.badgesFrom(<String, dynamic>{});
      expect(badges, isNotEmpty);
      expect(badges.every((b) => !b.isEarned), isTrue,
          reason: 'a document with no badges map has earned none of them');
    });

    test('marks exactly the badges the document records as earned', () {
      final earnedAt = Timestamp.fromDate(DateTime(2026, 9, 1));
      final all = StreakService.badgesFrom(<String, dynamic>{});
      final targetId = all.first.id;

      final badges = StreakService.badgesFrom(<String, dynamic>{
        'badges': {targetId: earnedAt},
      });

      final earned = badges.where((b) => b.isEarned).toList();
      expect(earned.length, 1);
      expect(earned.single.id, targetId);
      expect(earned.single.earnedAt, DateTime(2026, 9, 1));
    });

    test('counts more than one earned badge', () {
      // The reported symptom was "0 badges earned" against an account that had
      // two. Counting is the thing that was broken, so count more than one.
      final ts = Timestamp.fromDate(DateTime(2026, 9, 1));
      final all = StreakService.badgesFrom(<String, dynamic>{});
      final ids = all.take(2).map((b) => b.id).toList();

      final badges = StreakService.badgesFrom(<String, dynamic>{
        'badges': {for (final id in ids) id: ts},
      });

      expect(badges.where((b) => b.isEarned).length, 2);
    });

    test('ignores a badge entry whose value is not a timestamp', () {
      final all = StreakService.badgesFrom(<String, dynamic>{});
      final badges = StreakService.badgesFrom(<String, dynamic>{
        'badges': {all.first.id: 'yesterday'},
      });
      expect(badges.where((b) => b.isEarned), isEmpty);
    });

    test('ignores an id that is not in the catalogue', () {
      final badges = StreakService.badgesFrom(<String, dynamic>{
        'badges': {'no-such-badge': Timestamp.now()},
      });
      expect(badges.where((b) => b.isEarned), isEmpty);
      expect(badges.length, StreakService.badgesFrom(<String, dynamic>{}).length,
          reason: 'an unknown id must not add a phantom badge to the grid');
    });
  });

  group('goalFrom', () {
    test('reads the points earned today and the target', () {
      final data = <String, dynamic>{
        'dailyGoal': {'todayPoints': 30, 'target': 50},
      };
      expect(StreakService.goalFrom(data).todayPoints, 30);
      expect(StreakService.goalFrom(data).target, 50);
    });

    test('defaults to a 50-point target rather than 0', () {
      // A target of 0 would make the home ring divide by zero or read as
      // already complete.
      expect(StreakService.goalFrom(<String, dynamic>{}).target, 50);
      expect(StreakService.goalFrom(<String, dynamic>{}).todayPoints, 0);
    });
  });

  group('the two tabs read one document the same way', () {
    test('a realistic document parses to the numbers Home showed', () {
      // The exact account state from the bug report: a 1-day streak, 30 points
      // and two earned badges. Progress reported 0 / 0 / 0 for this document.
      final ts = Timestamp.fromDate(DateTime(2026, 9, 8));
      final all = StreakService.badgesFrom(<String, dynamic>{});
      final twoIds = all.take(2).map((b) => b.id).toList();

      final document = <String, dynamic>{
        'streak': {'current': 1, 'longest': 1},
        'dailyGoal': {'todayPoints': 30, 'target': 50},
        'badges': {for (final id in twoIds) id: ts},
        'completedLessons': [
          {'courseId': 'binary-ai-fundamentals', 'moduleId': 'module-1'},
        ],
      };

      expect(StreakService.streakFrom(document).current, 1);
      expect(StreakService.goalFrom(document).todayPoints, 30);
      expect(StreakService.badgesFrom(document).where((b) => b.isEarned).length, 2);
      expect((document['completedLessons'] as List).length, 1,
          reason: 'both tabs now count lessons from this same field');
    });
  });
}
