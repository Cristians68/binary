import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Call when a user passes a quiz (score >= 60%) ─────────────────────────
  static Future<void> completeModule({
    required String courseId,
    required String moduleId,
    required String moduleTitle,
    required String courseTag,
    required int score,
    required int total,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final userRef = _db.collection('users').doc(uid);

    // ✅ User-specific progress paths — never touch shared courses/ collection
    final userProgressRef = userRef.collection('progress').doc(courseId);
    final userModuleRef = userProgressRef.collection('modules').doc(moduleId);

    // 1. Mark this module as done for THIS user
    await userModuleRef.set({
      'status': 'done',
      'completedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    // 2. Count total modules from the shared courses collection (read-only)
    final courseRef = _db.collection('courses').doc(courseId);
    final modulesSnap = await courseRef.collection('modules').get();
    final totalModules = modulesSnap.docs.length;

    // 3. Count how many modules THIS user has completed
    final userModulesSnap = await userProgressRef.collection('modules').get();
    final doneModules = userModulesSnap.docs
        .where((d) => (d.data()['status'] as String?) == 'done')
        .length;

    final progress =
        totalModules > 0 ? doneModules / totalModules : 0.0;

    // 4. Write per-user course progress
    await userProgressRef.set({
      'courseId': courseId,
      'progress': progress,
      'doneModules': doneModules,
      'totalModules': totalModules,
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    // 5. Unlock the next module in the shared courses collection
    //    (this is fine — module order/unlock is course-level metadata)
    final orderedModules = modulesSnap.docs
      ..sort(
        (a, b) => ((a.data()['order'] as int?) ?? 0)
            .compareTo((b.data()['order'] as int?) ?? 0),
      );
    final currentIndex =
        orderedModules.indexWhere((d) => d.id == moduleId);
    if (currentIndex != -1 &&
        currentIndex + 1 < orderedModules.length) {
      final nextModule = orderedModules[currentIndex + 1];
      if ((nextModule.data()['status'] as String?) == 'locked') {
        await courseRef
            .collection('modules')
            .doc(nextModule.id)
            .set({'status': 'active'}, SetOptions(merge: true));
      }
    }

    // 6. Record completed lesson and quiz score in user doc
    final now = Timestamp.fromDate(DateTime.now());

    await userRef.set({
      'completedLessons': FieldValue.arrayUnion([
        {
          'courseId': courseId,
          'courseTag': courseTag,
          'moduleId': moduleId,
          'moduleTitle': moduleTitle,
          'score': score,
          'total': total,
          'percent': ((score / total) * 100).toInt(),
          'completedAt': now,
        },
      ]),
      'lessonsCompleted': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await userRef.set({
      'quizScores': FieldValue.arrayUnion([
        {
          'courseId': courseId,
          'moduleId': moduleId,
          'quizTitle': moduleTitle,
          'course': courseTag,
          'score': ((score / total) * 100).toInt(),
          'takenAt': now,
        },
      ]),
    }, SetOptions(merge: true));

    // 7. Check if entire course is now complete for this user
    if (doneModules == totalModules && totalModules > 0) {
      await _markCourseComplete(
        uid: uid,
        courseId: courseId,
        courseTag: courseTag,
        userRef: userRef,
        userProgressRef: userProgressRef,
      );
    }

    // 8. Update streak using StreakService-compatible nested field
    await _updateStreak(userRef);
  }

  // ── Check if a course is fully complete for this user ─────────────────────
  static Future<bool> isCourseComplete(String courseId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      // Check user-specific progress
      final userProgressRef = _db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(courseId);
      final snap = await userProgressRef.get();
      final data = snap.data() ?? {};
      return data['progress'] == 1.0 ||
          (data['doneModules'] != null &&
              data['totalModules'] != null &&
              data['doneModules'] == data['totalModules']);
    } catch (_) {
      return false;
    }
  }

  // ── Get overall course progress 0.0–1.0 for this user ─────────────────────
  static Future<double> getCourseProgress(String courseId) async {
    final uid = _uid;
    if (uid == null) return 0.0;
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(courseId)
          .get();
      return ((snap.data()?['progress'] as num?) ?? 0.0).toDouble();
    } catch (_) {
      return 0.0;
    }
  }

  // ── Get all course progress for this user (used by ProgressScreen) ─────────
  static Future<Map<String, double>> getAllCourseProgress() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .get();
      return Map.fromEntries(
        snap.docs.map((d) => MapEntry(
              d.id,
              ((d.data()['progress'] as num?) ?? 0.0).toDouble(),
            )),
      );
    } catch (_) {
      return {};
    }
  }

  // ── Internal: mark course complete, award badge ───────────────────────────
  static Future<void> _markCourseComplete({
    required String uid,
    required String courseId,
    required String courseTag,
    required DocumentReference userRef,
    required DocumentReference userProgressRef,
  }) async {
    // Mark complete in user's progress sub-collection
    await userProgressRef.set({
      'completed': true,
      'completedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    // Award badge in user doc
    final badgeKey = 'badges.complete_$courseId';
    try {
      await userRef.update({
        badgeKey: Timestamp.fromDate(DateTime.now()),
        'completedCourses': FieldValue.arrayUnion([courseId]),
      });
    } catch (_) {
      await userRef.set({
        'badges': {'complete_$courseId': Timestamp.fromDate(DateTime.now())},
        'completedCourses': FieldValue.arrayUnion([courseId]),
      }, SetOptions(merge: true));
    }
  }

  // ── Internal: update streak using StreakService-compatible fields ──────────
  // Uses nested 'streak.current' map to match StreakService format
  static Future<void> _updateStreak(DocumentReference userRef) async {
    try {
      final snap = await userRef.get();
      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Read from nested streak map (StreakService format)
      final streakMap = data['streak'] as Map<String, dynamic>? ?? {};
      final lastTs = streakMap['lastLogin'] as Timestamp?;
      final lastLogin = lastTs?.toDate();
      final last = lastLogin != null
          ? DateTime(lastLogin.year, lastLogin.month, lastLogin.day)
          : null;

      int current = (streakMap['current'] as num?)?.toInt() ?? 0;
      int longest = (streakMap['longest'] as num?)?.toInt() ?? 0;

      if (last == null) {
        current = 1;
      } else if (last == today) {
        return; // Already recorded today
      } else if (today.difference(last).inDays == 1) {
        current += 1;
      } else {
        current = 1;
      }

      if (current > longest) longest = current;

      // Write back in StreakService-compatible nested format
      try {
        await userRef.update({
          'streak.current': current,
          'streak.longest': longest,
          'streak.lastLogin': Timestamp.fromDate(now),
        });
      } catch (_) {
        await userRef.set({
          'streak': {
            'current': current,
            'longest': longest,
            'lastLogin': Timestamp.fromDate(now),
          },
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}
