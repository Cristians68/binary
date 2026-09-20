import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../course_catalog.dart';
import 'notification_service.dart';
import 'server_clock.dart';
import 'service_backend.dart';
import 'streak_logic.dart';

// ─────────────────────────────────────────────
// Safe map cast — works on iOS, Android & Web
// ─────────────────────────────────────────────

Map<String, dynamic> _safeMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return {};
}

/// update() with a set(merge:true) fallback — safe on all platforms.
///
/// This used to hand the fallback the same dot-notation map it gave update(),
/// which the comment right here warned against: set(merge:true) treats
/// 'streak.current' as a field whose NAME contains a dot, not as a path into
/// the streak map. Nothing ever reads that field back, so the first write to a
/// not-yet-created user document produced a permanently stuck streak.
///
/// It is reachable: only email/password signup creates users/{uid}. Google and
/// Apple sign-in do not, and the FCM token write that would otherwise create
/// it is skipped on web and whenever the user declines the notification
/// prompt. HomeScreen then calls checkAndUpdateStreak() on a missing document.
///
/// [safeUpdate] in service_backend.dart expands the keys before falling back.
Future<void> _safeUpdate(
  DocumentReference<Map<String, dynamic>> doc,
  Map<String, Object?> data,
) =>
    safeUpdate(doc, data);

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class StreakData {
  final int current;
  final int longest;
  final DateTime? lastLogin;

  const StreakData({
    required this.current,
    required this.longest,
    this.lastLogin,
  });

  factory StreakData.fromMap(Map<String, dynamic> map) {
    return StreakData(
      current: (map['current'] as num?)?.toInt() ?? 0,
      longest: (map['longest'] as num?)?.toInt() ?? 0,
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
    );
  }
}

class BadgeData {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final BadgeCategory category;
  final DateTime? earnedAt;

  const BadgeData({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.category,
    this.earnedAt,
  });

  bool get isEarned => earnedAt != null;
}

enum BadgeCategory { streak, course, quiz }

class DailyGoalData {
  final int target;
  final int todayPoints;
  final DateTime? lastReset;

  const DailyGoalData({
    required this.target,
    required this.todayPoints,
    this.lastReset,
  });

  double get progress => target > 0 ? todayPoints / target : 0;
  bool get isComplete => todayPoints >= target;

  factory DailyGoalData.fromMap(Map<String, dynamic> map) {
    return DailyGoalData(
      target: (map['target'] as num?)?.toInt() ?? 50,
      todayPoints: (map['todayPoints'] as num?)?.toInt() ?? 0,
      lastReset: (map['lastReset'] as Timestamp?)?.toDate(),
    );
  }
}

// ─────────────────────────────────────────────
// Badge definitions
// ─────────────────────────────────────────────

const List<BadgeData> kAllBadges = [
  BadgeData(
    id: 'streak_7',
    title: '7-Day Streak',
    description: 'Logged in 7 days in a row',
    emoji: '🔥',
    category: BadgeCategory.streak,
  ),
  BadgeData(
    id: 'streak_30',
    title: '30-Day Streak',
    description: 'Logged in 30 days in a row',
    emoji: '⚡',
    category: BadgeCategory.streak,
  ),
  BadgeData(
    id: 'streak_100',
    title: '100-Day Streak',
    description: 'Logged in 100 days in a row',
    emoji: '💎',
    category: BadgeCategory.streak,
  ),
  BadgeData(
    id: 'course_first',
    title: 'Graduate',
    description: 'Completed your first course',
    emoji: '🎓',
    category: BadgeCategory.course,
  ),
  BadgeData(
    id: 'course_3',
    title: 'Triple Threat',
    description: 'Completed 3 courses',
    emoji: '🏆',
    category: BadgeCategory.course,
  ),
  BadgeData(
    id: 'course_all',
    title: 'Master',
    description: 'Completed all available courses',
    emoji: '👑',
    category: BadgeCategory.course,
  ),
  BadgeData(
    id: 'quiz_first',
    title: 'Quiz Starter',
    description: 'Passed your first quiz',
    emoji: '✅',
    category: BadgeCategory.quiz,
  ),
  BadgeData(
    id: 'quiz_perfect',
    title: 'Perfectionist',
    description: 'Scored 100% on a quiz',
    emoji: '⭐',
    category: BadgeCategory.quiz,
  ),
  BadgeData(
    id: 'quiz_10',
    title: 'Quiz Master',
    description: 'Passed 10 quizzes',
    emoji: '🧠',
    category: BadgeCategory.quiz,
  ),
];

// ─────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────

class StreakService {
  static FirebaseFirestore get _db => ServiceBackend.db;

  static String? get _uid => ServiceBackend.uid;

  static DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ── Real-time stream — used by HomeScreen StreamBuilder ───────────────────
  static Stream<Map<String, dynamic>> statsStream() {
    return ServiceBackend.watchUser().map((snap) => snap.data() ?? {});
  }

  // ── One-shot fetch ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() async {
    final doc = _userDoc;
    if (doc == null) return {};
    try {
      final snap = await doc.get();
      return snap.data() ?? {};
    } catch (e) {
      debugPrint('StreakService.getStats error: $e');
      return {};
    }
  }

  // ── Alias for backward compat ─────────────────────────────────────────────
  static Future<void> checkAndUpdateStreak() => recordLogin();

  // -- Record daily login + update streak -----------------------------------
  /// Count today towards the streak.
  ///
  /// The day is decided by [ServerClock], not the device. If the clock cannot
  /// be calibrated this returns without writing: the day is not lost, it is
  /// simply not counted until the app can reach the server. Falling back to
  /// `DateTime.now()` would hand the streak straight back to anyone willing to
  /// change their device clock, which is exactly what this used to do.
  static Future<void> recordLogin() async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      // Doubles as the "user is active" write, so it costs no extra round trip.
      final calibrated = await ServerClock.calibrate(doc);
      if (!calibrated) {
        debugPrint('StreakService.recordLogin: clock uncalibrated, skipping');
        return;
      }
      final now = ServerClock.now();

      final snapshot = await doc.get();
      final data = snapshot.data() ?? {};
      final streak = StreakData.fromMap(_safeMap(data['streak']));

      final outcome = computeStreak(
        now: now,
        lastLogin: streak.lastLogin,
        currentStreak: streak.current,
        longestStreak: streak.longest,
      );

      if (outcome.changed) {
        // Dot-notation MUST go through update(), not set() -- see _safeUpdate.
        await _safeUpdate(doc, {
          'streak.current': outcome.current,
          'streak.longest': outcome.longest,
          'streak.lastLogin': Timestamp.fromDate(now),
        });
      }

      await _resetDailyGoalIfNeeded(doc, data, now);
      await _awardEligibleBadges(streakOverride: outcome.current);
    } catch (e) {
      debugPrint('StreakService.recordLogin error: $e');
    }
  }

  // -- Add points toward daily goal ------------------------------------------
  ///
  /// Uses `FieldValue.increment` rather than read-then-write. Two lessons
  /// finished in quick succession used to race: both read the same total and
  /// the second overwrote the first, silently losing points.
  static Future<void> addPoints(Activity activity) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      await _safeUpdate(doc, {
        'dailyGoal.todayPoints': FieldValue.increment(pointsFor(activity)),
      });
    } catch (e) {
      debugPrint('StreakService.addPoints error: $e');
    }
  }

  // -- Reading a lesson through to the end ------------------------------------
  /// Award the lesson's points once the user reaches the last flashcard.
  ///
  /// Points ONLY. It deliberately does not touch `lessonsCompleted` or
  /// `completedLessons`, even though the name might suggest it should:
  /// `ProgressService.completeModule` already writes both when the quiz is
  /// passed, and it writes the richer entry, with the score and percentage.
  ///
  /// Having both write them counted one module as two lessons and put two
  /// differently-shaped entries in the history list. That only became possible
  /// today, because this method previously had no caller at all.
  ///
  /// The split is deliberate rather than incidental: finishing the flashcards
  /// is worth points, but a lesson is not *completed* until its quiz is
  /// passed, which is the definition `lessonsCompleted` has always used.
  static Future<void> recordFlashcardsFinished() =>
      addPoints(Activity.lesson);

  // -- Call after passing a quiz ---------------------------------------------
  static Future<void> recordQuizPass({
    required int score,
    required int total,
  }) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      await addPoints(Activity.quizPass);
      await _safeUpdate(doc, {'quizzesPassed': FieldValue.increment(1)});
      await _awardEligibleBadges(perfectQuiz: total > 0 && score == total);
    } catch (e) {
      debugPrint('StreakService.recordQuizPass error: $e');
    }
  }

  // -- Call after completing a course ----------------------------------------
  ///
  /// Course counts come from the user document's `completedCourses` array and
  /// the shipped catalogue, so the caller no longer has to supply totals that
  /// it could get wrong -- passing `coursesAvailable: 0` used to award the
  /// rarest badge in the app to everyone.
  static Future<void> recordCourseComplete() => _awardEligibleBadges();

  // -- Badge awarding --------------------------------------------------------
  /// Award every badge the user now qualifies for.
  ///
  /// One place decides eligibility: `badgesToAward` in `streak_logic.dart`.
  /// Every recording method funnels through here rather than each carrying its
  /// own conditions, which is how six of the nine badges came to be
  /// unreachable -- they were only ever awarded inside methods nothing called.
  ///
  /// [streakOverride] lets `recordLogin` pass the streak it has just written,
  /// which the re-read below may not yet reflect.
  static Future<void> _awardEligibleBadges({
    bool perfectQuiz = false,
    int? streakOverride,
  }) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      final snapshot = await doc.get();
      final data = snapshot.data() ?? {};

      final earned = _earnedBadgeIds(data);
      final streak = streakOverride ??
          StreakData.fromMap(_safeMap(data['streak'])).current;

      final toAward = badgesToAward(
        streak: streak,
        quizzesPassed: ((data['quizzesPassed'] as num?) ?? 0).toInt(),
        coursesCompleted: completedCourseIds(data).length,
        coursesAvailable: kCourseCatalog.length,
        perfectQuiz: perfectQuiz,
        alreadyEarned: earned,
      );

      if (toAward.isEmpty) return;

      await _safeUpdate(doc, {
        for (final id in toAward) 'badges.$id': Timestamp.now(),
      });

      for (final id in toAward) {
        BadgeData? badge;
        for (final b in kAllBadges) {
          if (b.id == id) badge = b;
        }
        if (badge == null) continue;
        await NotificationService.showBadgeEarnedNotification(
          badge.title,
          badge.emoji,
        );
      }
    } catch (e) {
      debugPrint('StreakService._awardEligibleBadges error: $e');
    }
  }

  /// Courses this user has finished, including ones only ever recorded under
  /// the old `badges.complete_<courseId>` scheme.
  ///
  /// `ProgressService` used to write that key, which appears in no badge list,
  /// so it inflated the "N / 9" counter while lighting nothing up in the grid.
  /// Reading it here means an account that finished a course before this
  /// shipped still earns the canonical course badges.
  ///
  /// No longer @visibleForTesting: CertificatesScreen is a real caller. It is
  /// the one place that knows about both storage generations, so a second
  /// reader open-coding "read completedCourses" would silently miss every
  /// account that predates the array.
  static Set<String> completedCourseIds(Map<String, dynamic> data) {
    final fromArray = (data['completedCourses'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    return fromArray
        .union(legacyCompletedCourseIds(_safeMap(data['badges']).keys));
  }

  // ── Fetch all structured data ─────────────────────────────────────────────
  static Future<
      ({
        StreakData streak,
        DailyGoalData goal,
        List<BadgeData> badges,
      })> fetchAll() async {
    final doc = _userDoc;
    if (doc == null) {
      return (
        streak: const StreakData(current: 0, longest: 0),
        goal: const DailyGoalData(target: 50, todayPoints: 0),
        badges: _mergeEarned({}, kAllBadges),
      );
    }
    try {
      final snapshot = await doc.get();
      final data = snapshot.data() ?? {};
      return (
        streak: StreakData.fromMap(_safeMap(data['streak'])),
        goal: DailyGoalData.fromMap(_safeMap(data['dailyGoal'])),
        badges: _mergeEarned(data, kAllBadges),
      );
    } catch (e) {
      debugPrint('StreakService.fetchAll error: $e');
      return (
        streak: const StreakData(current: 0, longest: 0),
        goal: const DailyGoalData(target: 50, todayPoints: 0),
        badges: _mergeEarned({}, kAllBadges),
      );
    }
  }

  // ── Parsing a raw user document ───────────────────────────────────────────
  //
  // statsStream() hands out the raw `users/{uid}` map, so any screen listening
  // to it has to turn that map into the same shapes fetchAll() returns. These
  // are the one place that conversion lives, so a second listener cannot drift
  // into parsing `streak` or `badges` slightly differently.

  /// Badges merged with their earned timestamps from a raw user document.
  static List<BadgeData> badgesFrom(Map<String, dynamic> data) =>
      _mergeEarned(data, kAllBadges);

  /// Streak counts from a raw user document.
  static StreakData streakFrom(Map<String, dynamic> data) =>
      StreakData.fromMap(_safeMap(data['streak']));

  /// Daily goal state from a raw user document.
  static DailyGoalData goalFrom(Map<String, dynamic> data) =>
      DailyGoalData.fromMap(_safeMap(data['dailyGoal']));

  /// Ids of the courses a raw user document records as enrolled.
  ///
  /// The value is only ever `true` or `false` — unenrolling writes `false`
  /// rather than deleting the key — so only a real `true` counts. On web the
  /// nested map arrives as a `JsLinkedHashMap`, so it goes through _safeMap
  /// rather than a cast: a throw inside a stream listener is how a screen
  /// ends up frozen.
  static Set<String> enrolledCourseIdsFrom(Map<String, dynamic> data) {
    final enrolments = _safeMap(data['enrolments']);
    return enrolments.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toSet();
  }

  /// The catalogue entries [enrolledIds] refers to, in catalogue order.
  ///
  /// Home and the Courses tab both need this join and each used to do it its
  /// own way off its own one-shot read. Order comes from the catalogue, never
  /// from the Set, so the cards do not reshuffle between launches. An id with
  /// no matching course is dropped rather than drawn as a blank card.
  static List<Map<String, dynamic>> enrolledCoursesFrom(
    List<Map<String, dynamic>> catalogue,
    Set<String> enrolledIds,
  ) {
    return catalogue.where((c) => enrolledIds.contains(c['id'])).toList();
  }

  // ── Update daily goal target ──────────────────────────────────────────────
  static Future<void> setDailyTarget(int target) async {
    final doc = _userDoc;
    if (doc == null) return;
    await _safeUpdate(doc, {'dailyGoal.target': target});
  }

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  static Future<void> _resetDailyGoalIfNeeded(
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
    DateTime today,
  ) async {
    final goal = DailyGoalData.fromMap(_safeMap(data['dailyGoal']));
    if (!needsDailyGoalReset(today: today, lastReset: goal.lastReset)) return;

    await _safeUpdate(doc, {
      'dailyGoal.todayPoints': 0,
      'dailyGoal.lastReset': Timestamp.fromDate(today),
    });
  }

  static Set<String> _earnedBadgeIds(Map<String, dynamic> data) {
    return _safeMap(data['badges']).keys.toSet();
  }

  static List<BadgeData> _mergeEarned(
    Map<String, dynamic> data,
    List<BadgeData> all,
  ) {
    final badgesMap = _safeMap(data['badges']);
    return all.map((b) {
      final ts = badgesMap[b.id];
      if (ts is Timestamp) {
        return BadgeData(
          id: b.id,
          title: b.title,
          description: b.description,
          emoji: b.emoji,
          category: b.category,
          earnedAt: ts.toDate(),
        );
      }
      return b;
    }).toList();
  }
}
