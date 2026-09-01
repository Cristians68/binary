import 'package:flutter_test/flutter_test.dart';
import 'package:binary/screens/streak_logic.dart';

/// A local wall-clock time. Streak days are calendar days in the user's own
/// zone, so the tests are written in local time deliberately.
DateTime at(int y, int m, int d, [int h = 12, int min = 0]) =>
    DateTime(y, m, d, h, min);

void main() {
  group('pointsFor', () {
    test('awards more for a quiz than a lesson', () {
      expect(pointsFor(Activity.lesson), 10);
      expect(pointsFor(Activity.quizPass), 20);
      expect(
        pointsFor(Activity.quizPass),
        greaterThan(pointsFor(Activity.lesson)),
      );
    });
  });

  group('dayNumber', () {
    test('is equal for two times on the same calendar day', () {
      expect(dayNumber(at(2026, 9, 1, 0, 1)), dayNumber(at(2026, 9, 1, 23, 59)));
    });

    test('increments by exactly one across midnight', () {
      expect(
        dayNumber(at(2026, 9, 2)) - dayNumber(at(2026, 9, 1)),
        1,
      );
    });

    test('is exact across a spring-forward daylight-saving boundary', () {
      // US DST 2026 begins Sunday 8 March. Local subtraction across this gap
      // is 23 hours, which truncates to 0 days and would drop a streak day.
      expect(dayNumber(at(2026, 3, 9)) - dayNumber(at(2026, 3, 8)), 1);
    });

    test('is exact across an autumn fall-back daylight-saving boundary', () {
      // US DST 2026 ends Sunday 1 November. That local day is 25 hours, which
      // would otherwise report 1 day for two times inside the same day.
      expect(dayNumber(at(2026, 11, 1, 0, 30)),
          dayNumber(at(2026, 11, 1, 23, 30)));
      expect(dayNumber(at(2026, 11, 2)) - dayNumber(at(2026, 11, 1)), 1);
    });

    test('crosses month and year boundaries by one day', () {
      expect(dayNumber(at(2026, 3, 1)) - dayNumber(at(2026, 2, 28)), 1);
      expect(dayNumber(at(2027, 1, 1)) - dayNumber(at(2026, 12, 31)), 1);
    });

    test('handles a leap day', () {
      expect(dayNumber(at(2028, 2, 29)) - dayNumber(at(2028, 2, 28)), 1);
      expect(dayNumber(at(2028, 3, 1)) - dayNumber(at(2028, 2, 29)), 1);
    });
  });

  group('computeStreak', () {
    test('a first ever login starts the streak at one', () {
      final out = computeStreak(now: at(2026, 9, 1));
      expect(out, const StreakOutcome(current: 1, longest: 1, changed: true));
    });

    test('a first login preserves a longest that is somehow already higher',
        () {
      final out = computeStreak(now: at(2026, 9, 1), longestStreak: 12);
      expect(out.longest, 12);
      expect(out.current, 1);
    });

    test('a consecutive day increments the streak', () {
      final out = computeStreak(
        now: at(2026, 9, 2),
        lastLogin: at(2026, 9, 1),
        currentStreak: 4,
        longestStreak: 9,
      );
      expect(out.current, 5);
      expect(out.longest, 9);
      expect(out.changed, isTrue);
    });

    test('a consecutive day raises longest once it passes the record', () {
      final out = computeStreak(
        now: at(2026, 9, 2),
        lastLogin: at(2026, 9, 1),
        currentStreak: 9,
        longestStreak: 9,
      );
      expect(out.current, 10);
      expect(out.longest, 10);
    });

    test('a second login on the same day changes nothing', () {
      final out = computeStreak(
        now: at(2026, 9, 1, 22),
        lastLogin: at(2026, 9, 1, 8),
        currentStreak: 6,
        longestStreak: 11,
      );
      expect(out.changed, isFalse);
      expect(out.current, 6);
      expect(out.longest, 11);
    });

    test('increments across midnight even a minute apart', () {
      final out = computeStreak(
        now: at(2026, 9, 2, 0, 1),
        lastLogin: at(2026, 9, 1, 23, 59),
        currentStreak: 3,
      );
      expect(out.current, 4);
      expect(out.changed, isTrue);
    });

    test('a missed day resets the streak to one', () {
      final out = computeStreak(
        now: at(2026, 9, 3),
        lastLogin: at(2026, 9, 1),
        currentStreak: 30,
        longestStreak: 30,
      );
      expect(out.current, 1);
      expect(out.changed, isTrue);
    });

    test('a reset never lowers the longest streak', () {
      final out = computeStreak(
        now: at(2026, 9, 20),
        lastLogin: at(2026, 9, 1),
        currentStreak: 30,
        longestStreak: 30,
      );
      expect(out.current, 1);
      expect(out.longest, 30, reason: 'the record must survive a broken streak');
    });

    test('a backwards clock is a no-op, not a reset and not a gift', () {
      // The stored login is in the future: the device clock moved back.
      final out = computeStreak(
        now: at(2026, 9, 1),
        lastLogin: at(2026, 9, 5),
        currentStreak: 8,
        longestStreak: 8,
      );
      expect(out.changed, isFalse,
          reason: 'writing here lets a rolled-back clock farm streak days');
      expect(out.current, 8);
      expect(out.longest, 8);
    });

    test('rolling the clock forward and back cannot inflate the streak', () {
      var current = 1;
      var longest = 1;
      var last = at(2026, 9, 1);

      // Forward a day: legitimate increment.
      var out = computeStreak(
          now: at(2026, 9, 2),
          lastLogin: last,
          currentStreak: current,
          longestStreak: longest);
      expect(out.current, 2);
      current = out.current;
      longest = out.longest;
      last = at(2026, 9, 2);

      // Back to the original day, repeatedly. None of these may count.
      for (var i = 0; i < 5; i++) {
        out = computeStreak(
            now: at(2026, 9, 1),
            lastLogin: last,
            currentStreak: current,
            longestStreak: longest);
        expect(out.changed, isFalse);
        expect(out.current, 2);
      }
    });

    test('a year-long gap resets to one', () {
      final out = computeStreak(
        now: at(2027, 9, 1),
        lastLogin: at(2026, 9, 1),
        currentStreak: 100,
        longestStreak: 100,
      );
      expect(out.current, 1);
      expect(out.longest, 100);
    });
  });

  group('needsDailyGoalReset', () {
    test('resets when there is no record of a previous reset', () {
      expect(needsDailyGoalReset(today: at(2026, 9, 1)), isTrue);
    });

    test('does not reset twice in one day', () {
      expect(
        needsDailyGoalReset(
            today: at(2026, 9, 1, 23), lastReset: at(2026, 9, 1, 0)),
        isFalse,
      );
    });

    test('resets on the next day', () {
      expect(
        needsDailyGoalReset(today: at(2026, 9, 2), lastReset: at(2026, 9, 1)),
        isTrue,
      );
    });

    test('does not reset when the clock has gone backwards', () {
      expect(
        needsDailyGoalReset(today: at(2026, 9, 1), lastReset: at(2026, 9, 5)),
        isFalse,
        reason: 'a backwards clock must not zero points already earned',
      );
    });
  });

  group('badgesToAward', () {
    Set<String> award({
      int streak = 0,
      int quizzesPassed = 0,
      int coursesCompleted = 0,
      int coursesAvailable = 8,
      bool perfectQuiz = false,
      Set<String> alreadyEarned = const {},
    }) =>
        badgesToAward(
          streak: streak,
          quizzesPassed: quizzesPassed,
          coursesCompleted: coursesCompleted,
          coursesAvailable: coursesAvailable,
          perfectQuiz: perfectQuiz,
          alreadyEarned: alreadyEarned,
        );

    test('awards nothing to a brand new account', () {
      expect(award(), isEmpty);
    });

    test('only ever returns known badge ids', () {
      final all = award(
        streak: 1000,
        quizzesPassed: 1000,
        coursesCompleted: 1000,
        coursesAvailable: 8,
        perfectQuiz: true,
      );
      expect(all.difference(kKnownBadgeIds), isEmpty);
    });

    group('streak thresholds', () {
      test('nothing at six days', () => expect(award(streak: 6), isEmpty));
      test('streak_7 at exactly seven',
          () => expect(award(streak: 7), {'streak_7'}));
      test('nothing new at twenty-nine',
          () => expect(award(streak: 29, alreadyEarned: {'streak_7'}), isEmpty));
      test('streak_30 at exactly thirty',
          () => expect(award(streak: 30), {'streak_7', 'streak_30'}));
      test('streak_100 at exactly one hundred', () {
        expect(award(streak: 100),
            {'streak_7', 'streak_30', 'streak_100'});
      });
    });

    group('quiz thresholds', () {
      test('quiz_first on the first pass',
          () => expect(award(quizzesPassed: 1), {'quiz_first'}));
      test('quiz_perfect only on a perfect score', () {
        expect(award(quizzesPassed: 1, perfectQuiz: false), {'quiz_first'});
        expect(award(quizzesPassed: 1, perfectQuiz: true),
            {'quiz_first', 'quiz_perfect'});
      });
      test('nothing extra at nine passes', () {
        expect(award(quizzesPassed: 9, alreadyEarned: {'quiz_first'}), isEmpty);
      });
      test('quiz_10 at exactly ten passes', () {
        expect(award(quizzesPassed: 10, alreadyEarned: {'quiz_first'}),
            {'quiz_10'});
      });
    });

    group('course thresholds', () {
      test('course_first on the first course',
          () => expect(award(coursesCompleted: 1), {'course_first'}));
      test('nothing extra at two courses', () {
        expect(award(coursesCompleted: 2, alreadyEarned: {'course_first'}),
            isEmpty);
      });
      test('course_3 at exactly three', () {
        expect(award(coursesCompleted: 3, alreadyEarned: {'course_first'}),
            {'course_3'});
      });
      test('course_all when every course is done', () {
        expect(
          award(coursesCompleted: 8, coursesAvailable: 8),
          {'course_first', 'course_3', 'course_all'},
        );
      });
      test('no course_all while one course remains', () {
        expect(
          award(coursesCompleted: 7, coursesAvailable: 8),
          isNot(contains('course_all')),
        );
      });

      test('an empty catalogue never awards course_all', () {
        // Guards the `0 >= 0` shape that already shipped once in this repo:
        // a catalogue that has not loaded yet must not hand out the rarest
        // badge in the app to everyone.
        expect(
          award(coursesCompleted: 0, coursesAvailable: 0),
          isNot(contains('course_all')),
        );
      });
    });

    test('never re-awards a badge the user already holds', () {
      final held = {'streak_7', 'quiz_first', 'course_first'};
      final out = award(
        streak: 7,
        quizzesPassed: 1,
        coursesCompleted: 1,
        alreadyEarned: held,
      );
      expect(out, isEmpty);
    });

    test('awards only the newly crossed threshold', () {
      final out = award(
        streak: 30,
        alreadyEarned: {'streak_7'},
      );
      expect(out, {'streak_30'});
    });
  });

  group('legacyCompletedCourseIds', () {
    test('extracts course ids from legacy complete_ keys', () {
      expect(
        legacyCompletedCourseIds(
            ['complete_cloud-fundamentals', 'complete_itil-v4', 'streak_7']),
        {'cloud-fundamentals', 'itil-v4'},
      );
    });

    test('ignores canonical badge ids', () {
      expect(
        legacyCompletedCourseIds(kKnownBadgeIds),
        isEmpty,
        reason: 'no canonical badge id may be mistaken for a course',
      );
    });

    test('ignores a bare complete_ prefix with no course id', () {
      expect(legacyCompletedCourseIds(['complete_']), isEmpty);
    });

    test('is empty for an account with no badges', () {
      expect(legacyCompletedCourseIds(const []), isEmpty);
    });
  });
}
