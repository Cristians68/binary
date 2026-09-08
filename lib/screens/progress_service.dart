import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';
import 'service_backend.dart';
import 'streak_service.dart';

class ProgressService {
  static FirebaseFirestore get _db => ServiceBackend.db;
  static String? get _uid => ServiceBackend.uid;

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
      'completedAt': FieldValue.serverTimestamp(),
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
      'lastUpdated': FieldValue.serverTimestamp(),
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

    // 6. Record completed lesson and quiz score in user doc.
    // serverTimestamp() inside arrayUnion is not supported by Firestore —
    // use Timestamp.now() for array entries (client time is acceptable here
    // since these are display timestamps, not security-critical audit fields).
    final now = Timestamp.now();

    await userRef.set({
      'completedLessons': FieldValue.arrayUnion([
        {
          'courseId': courseId,
          'courseTag': courseTag,
          'moduleId': moduleId,
          'moduleTitle': moduleTitle,
          'score': score,
          'total': total,
          'percent': total > 0 ? ((score / total) * 100).toInt() : 0,
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
          'score': total > 0 ? ((score / total) * 100).toInt() : 0,
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

    // 8. Streak, points and badges all belong to StreakService.
    //
    // This used to call a private _updateStreak() that reimplemented the
    // same day-diff against the same fields. Two writers agreeing by
    // coincidence is not agreement, and only one of them had the
    // server-clock and DST fixes.
    await StreakService.recordLogin();
    await StreakService.recordQuizPass(score: score, total: total);
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
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Record the completion itself. This array is the real data; the course
    // badges are derived from its length.
    //
    // It used to also write `badges.complete_<courseId>` -- an id in neither
    // badge list, so it incremented the "N / 9" counter on the badges and
    // profile screens while lighting nothing up in the grid. Existing accounts
    // keep credit because StreakService.completedCourseIds still reads the old
    // keys; nothing writes new ones.
    await safeUpdate(
      userRef as DocumentReference<Map<String, dynamic>>,
      {'completedCourses': FieldValue.arrayUnion([courseId])},
    );

    await StreakService.recordCourseComplete();
    await NotificationService.showCourseCompleteNotification(courseTag);
  }

}
