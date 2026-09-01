/// Pure streak, daily-goal and badge decisions.
///
/// No Firebase, no I/O, no clock of its own — every input is a parameter. This
/// mirrors `quiz_logic.dart` and `review_logic.dart`: the rules that decide
/// what a user earned live here and are tested directly, while the service
/// layer only reads and writes documents.
///
/// Extracted because these rules previously sat inline inside
/// `StreakService`'s Firestore methods, where the only way to exercise them
/// was against a live project.
library;

/// Something a user did that is worth points.
enum Activity { lesson, quizPass }

/// Points awarded for one completed [Activity].
///
/// Replaces the bare `10` and `20` literals that were inline in
/// `recordLessonComplete` and `recordQuizPass`.
int pointsFor(Activity activity) => switch (activity) {
      Activity.lesson => 10,
      Activity.quizPass => 20,
    };

/// Canonical badge ids. The display lists in `badges_screen.dart` and the
/// `kAllBadges` table in `streak_service.dart` must both match this set —
/// `badgesToAward` can only ever return ids from here.
const Set<String> kKnownBadgeIds = {
  'streak_7',
  'streak_30',
  'streak_100',
  'quiz_first',
  'quiz_perfect',
  'quiz_10',
  'course_first',
  'course_3',
  'course_all',
};

/// The result of evaluating a login against the stored streak.
class StreakOutcome {
  final int current;
  final int longest;

  /// False when nothing should be written — the user already logged in today,
  /// or the supplied clock ran backwards.
  final bool changed;

  const StreakOutcome({
    required this.current,
    required this.longest,
    required this.changed,
  });

  @override
  String toString() =>
      'StreakOutcome(current: $current, longest: $longest, changed: $changed)';

  @override
  bool operator ==(Object other) =>
      other is StreakOutcome &&
      other.current == current &&
      other.longest == longest &&
      other.changed == changed;

  @override
  int get hashCode => Object.hash(current, longest, changed);
}

/// Days since the epoch for [d]'s calendar date, ignoring its time of day.
///
/// Deliberately routed through `DateTime.utc` rather than subtracting two
/// local `DateTime`s. A local subtraction across a daylight-saving boundary is
/// 23 or 25 hours, so `.inDays` truncates to 0 or reports 1 for what is really
/// the same day — which would either skip a legitimate streak day or hand out
/// a free one twice a year. UTC has no DST, so the difference is exact.
int dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).difference(_epoch).inDays;

final DateTime _epoch = DateTime.utc(1970, 1, 1);

/// Decide the new streak from the stored one and the current time.
///
/// [now] must come from `ServerClock`, not `DateTime.now()` — see the class
/// docs there for why.
StreakOutcome computeStreak({
  required DateTime now,
  DateTime? lastLogin,
  int currentStreak = 0,
  int longestStreak = 0,
}) {
  // No record of a previous login: this is day one.
  if (lastLogin == null) {
    return StreakOutcome(
      current: 1,
      longest: longestStreak > 1 ? longestStreak : 1,
      changed: true,
    );
  }

  final diff = dayNumber(now) - dayNumber(lastLogin);

  // Already counted today.
  if (diff == 0) {
    return StreakOutcome(
      current: currentStreak,
      longest: longestStreak,
      changed: false,
    );
  }

  // The stored login is in the future, so the clock moved backwards between
  // sessions. Writing anything here would let a user farm days by rolling the
  // device clock forward and back, so this is a deliberate no-op rather than a
  // reset — a reset would punish a genuine timezone change instead.
  if (diff < 0) {
    return StreakOutcome(
      current: currentStreak,
      longest: longestStreak,
      changed: false,
    );
  }

  final next = diff == 1 ? currentStreak + 1 : 1;

  return StreakOutcome(
    current: next,
    longest: next > longestStreak ? next : longestStreak,
    changed: true,
  );
}

/// Whether the daily goal counter belongs to a previous day and must be zeroed.
bool needsDailyGoalReset({
  required DateTime today,
  DateTime? lastReset,
}) {
  if (lastReset == null) return true;
  return dayNumber(today) > dayNumber(lastReset);
}

/// Every badge the user has now qualified for and does not already hold.
///
/// The single place badge eligibility is decided. Callers award exactly what
/// this returns; they do not add conditions of their own.
Set<String> badgesToAward({
  required int streak,
  required int quizzesPassed,
  required int coursesCompleted,
  required int coursesAvailable,
  required bool perfectQuiz,
  required Set<String> alreadyEarned,
}) {
  final earned = <String>{};

  if (streak >= 7) earned.add('streak_7');
  if (streak >= 30) earned.add('streak_30');
  if (streak >= 100) earned.add('streak_100');

  if (quizzesPassed >= 1) earned.add('quiz_first');
  if (quizzesPassed >= 10) earned.add('quiz_10');
  if (perfectQuiz) earned.add('quiz_perfect');

  if (coursesCompleted >= 1) earned.add('course_first');
  if (coursesCompleted >= 3) earned.add('course_3');

  // `coursesAvailable > 0` is load-bearing. Without it an empty or
  // not-yet-loaded catalogue makes this `0 >= 0`, which silently hands every
  // user the rarest badge in the app. The same shape of bug already shipped
  // once here, in the quiz pass check.
  if (coursesAvailable > 0 && coursesCompleted >= coursesAvailable) {
    earned.add('course_all');
  }

  return earned.difference(alreadyEarned);
}

/// Course badge ids reconstructed from legacy `badges.complete_<courseId>` keys.
///
/// `ProgressService` used to award a per-course key that appears in no badge
/// list, so it inflated the "N / 9" counter while lighting nothing up in the
/// grid. This maps that history onto the canonical badges so existing accounts
/// keep credit. See the migration section of the design doc.
Set<String> legacyCompletedCourseIds(Iterable<String> badgeKeys) => badgeKeys
    .where((k) => k.startsWith('complete_') && k.length > 'complete_'.length)
    .map((k) => k.substring('complete_'.length))
    .toSet();
