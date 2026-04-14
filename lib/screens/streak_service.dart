import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  double get progress => todayPoints / target;
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
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ── Real-time stream — used by HomeScreen StreamBuilder ───────────────────
  static Stream<Map<String, dynamic>> statsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data() ?? {});
  }

  // ── One-shot fetch — used by LessonsScreen / ProfileScreen ───────────────
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

  // ── Record daily login + update streak ────────────────────────────────────
  static Future<void> recordLogin() async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      final snapshot = await doc.get();
      final data = snapshot.data() ?? {};

      final streakMap = data['streak'] as Map<String, dynamic>? ?? {};
      final streak = StreakData.fromMap(streakMap);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int newCurrent = streak.current;
      final lastLogin = streak.lastLogin;

      if (lastLogin != null) {
        final lastDay =
            DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
        final diff = today.difference(lastDay).inDays;
        if (diff == 0) {
          await _resetDailyGoalIfNeeded(doc, data, today);
          return;
        } else if (diff == 1) {
          newCurrent = streak.current + 1;
        } else {
          newCurrent = 1;
        }
      } else {
        newCurrent = 1;
      }

      final newLongest =
          newCurrent > streak.longest ? newCurrent : streak.longest;

      // Use dot-notation to avoid nested-map iOS crash
      await doc.set({
        'streak.current': newCurrent,
        'streak.longest': newLongest,
        'streak.lastLogin': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      await _resetDailyGoalIfNeeded(doc, data, today);
      await _checkStreakBadges(newCurrent);
    } catch (e) {
      debugPrint('StreakService.recordLogin error: $e');
    }
  }

  // ── Add points toward daily goal ──────────────────────────────────────────
  static Future<void> addPoints(int points) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      final snapshot = await doc.get();
      final data = snapshot.data() ?? {};
      final goal = DailyGoalData.fromMap(
        data['dailyGoal'] as Map<String, dynamic>? ?? {},
      );

      await doc.update({
        'dailyGoal.todayPoints': goal.todayPoints + points,
      });
    } catch (e) {
      // Document may not exist yet — create it
      try {
        final doc2 = _userDoc;
        if (doc2 != null) {
          await doc2.set({
            'dailyGoal.todayPoints': points,
          }, SetOptions(merge: true));
        }
      } catch (_) {}
      debugPrint('StreakService.addPoints error: $e');
    }
  }

  // ── Call after passing a quiz ─────────────────────────────────────────────
  static Future<void> recordQuizPass({
    required int score,
    required int total,
  }) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      await addPoints(20);

      final snapshot = await doc.get();
      final data = snapshot.data() ?? {};
      final quizzesPassed = ((data['quizzesPassed'] as num?) ?? 0).toInt() + 1;

      await doc.update({'quizzesPassed': quizzesPassed});

      final earnedIds = _earnedBadgeIds(data);
      if (!earnedIds.contains('quiz_first')) await _awardBadge('quiz_first');
      if (score == total && !earnedIds.contains('quiz_perfect')) {
        await _awardBadge('quiz_perfect');
      }
      if (quizzesPassed >= 10 && !earnedIds.contains('quiz_10')) {
        await _awardBadge('quiz_10');
      }
    } catch (e) {
      debugPrint('StreakService.recordQuizPass error: $e');
    }
  }

  // ── Call after completing a course ────────────────────────────────────────
  static Future<void> recordCourseComplete({
    required int totalCoursesCompleted,
    required int totalCoursesAvailable,
  }) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      final snapshot = await doc.get();
      final data = snapshot.data() ?? {};
      final earnedIds = _earnedBadgeIds(data);

      if (!earnedIds.contains('course_first')) {
        await _awardBadge('course_first');
      }
      if (totalCoursesCompleted >= 3 && !earnedIds.contains('course_3')) {
        await _awardBadge('course_3');
      }
      if (totalCoursesCompleted >= totalCoursesAvailable &&
          !earnedIds.contains('course_all')) {
        await _awardBadge('course_all');
      }
    } catch (e) {
      debugPrint('StreakService.recordCourseComplete error: $e');
    }
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
        streak:
            StreakData.fromMap(data['streak'] as Map<String, dynamic>? ?? {}),
        goal: DailyGoalData.fromMap(
            data['dailyGoal'] as Map<String, dynamic>? ?? {}),
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

  // ── Update daily goal target ──────────────────────────────────────────────
  static Future<void> setDailyTarget(int target) async {
    final doc = _userDoc;
    if (doc == null) return;
    try {
      await doc.update({'dailyGoal.target': target});
    } catch (_) {
      await doc.set({'dailyGoal.target': target}, SetOptions(merge: true));
    }
  }

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  static Future<void> _resetDailyGoalIfNeeded(
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
    DateTime today,
  ) async {
    final goal = DailyGoalData.fromMap(
      data['dailyGoal'] as Map<String, dynamic>? ?? {},
    );

    final lastReset = goal.lastReset;
    final needsReset = lastReset == null ||
        today.isAfter(
          DateTime(lastReset.year, lastReset.month, lastReset.day),
        );

    if (needsReset) {
      await doc.set({
        'dailyGoal.todayPoints': 0,
        'dailyGoal.lastReset': Timestamp.fromDate(today),
      }, SetOptions(merge: true));
    }
  }

  static Future<void> _checkStreakBadges(int current) async {
    final doc = _userDoc;
    if (doc == null) return;
    final snapshot = await doc.get();
    final data = snapshot.data() ?? {};
    final earnedIds = _earnedBadgeIds(data);

    if (current >= 7 && !earnedIds.contains('streak_7')) {
      await _awardBadge('streak_7');
    }
    if (current >= 30 && !earnedIds.contains('streak_30')) {
      await _awardBadge('streak_30');
    }
    if (current >= 100 && !earnedIds.contains('streak_100')) {
      await _awardBadge('streak_100');
    }
  }

  // KEY FIX: dot-notation field path instead of nested map
  static Future<void> _awardBadge(String badgeId) async {
    final doc = _userDoc;
    if (doc == null) return;
    debugPrint('Awarding badge: $badgeId');
    try {
      await doc.update({
        'badges.$badgeId': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // Document doesn't exist yet
      await doc.set({
        'badges.$badgeId': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    }
  }

  static Set<String> _earnedBadgeIds(Map<String, dynamic> data) {
    final badgesMap = data['badges'] as Map<String, dynamic>? ?? {};
    return badgesMap.keys.toSet();
  }

  static List<BadgeData> _mergeEarned(
    Map<String, dynamic> data,
    List<BadgeData> all,
  ) {
    final badgesMap = data['badges'] as Map<String, dynamic>? ?? {};
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
