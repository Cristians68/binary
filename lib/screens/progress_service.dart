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
    final courseRef = _db.collection('courses').doc(courseId);
    final moduleRef = courseRef.collection('modules').doc(moduleId);

    // 1. Mark module as done
    await moduleRef.set({'status': 'done'}, SetOptions(merge: true));

    // 2. Count total modules and done modules to compute progress
    final modulesSnap = await courseRef.collection('modules').get();
    final totalModules = modulesSnap.docs.length;
    final doneModules = modulesSnap.docs
        .where((d) => (d.data()['status'] as String?) == 'done')
        .length;

    final progress = totalModules > 0 ? doneModules / totalModules : 0.0;

    // 3. Update course-level progress
    await courseRef.set({'progress': progress}, SetOptions(merge: true));

    // 4. Unlock the next module
    final orderedModules = modulesSnap.docs
      ..sort(
        (a, b) => ((a.data()['order'] as int?) ?? 0)
            .compareTo((b.data()['order'] as int?) ?? 0),
      );

    final currentIndex = orderedModules.indexWhere((d) => d.id == moduleId);
    if (currentIndex != -1 && currentIndex + 1 < orderedModules.length) {
      final nextModule = orderedModules[currentIndex + 1];
      if ((nextModule.data()['status'] as String?) == 'locked') {
        await courseRef
            .collection('modules')
            .doc(nextModule.id)
            .set({'status': 'active'}, SetOptions(merge: true));
      }
    }

    // 5. Record completed lesson in user doc
    // IMPORTANT: FieldValue.serverTimestamp() cannot be used inside
    // arrayUnion — use Timestamp.fromDate(DateTime.now()) instead.
    final now = Timestamp.fromDate(DateTime.now());

    final lessonRecord = {
      'courseId': courseId,
      'courseTag': courseTag,
      'moduleId': moduleId,
      'moduleTitle': moduleTitle,
      'score': score,
      'total': total,
      'percent': ((score / total) * 100).toInt(),
      'completedAt': now,
    };

    await userRef.set({
      'completedLessons': FieldValue.arrayUnion([lessonRecord]),
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

    // 6. Check if entire course is now complete
    if (doneModules == totalModules) {
      await _markCourseComplete(
        uid: uid,
        courseId: courseId,
        courseTag: courseTag,
        userRef: userRef,
        courseRef: courseRef,
      );
    }

    // 7. Update streak
    await _updateStreak(userRef);
  }

  // ── Check if a course is fully complete ───────────────────────────────────
  static Future<bool> isCourseComplete(String courseId) async {
    try {
      final courseRef = _db.collection('courses').doc(courseId);
      final modulesSnap = await courseRef.collection('modules').get();
      if (modulesSnap.docs.isEmpty) return false;
      return modulesSnap.docs.every(
        (d) => (d.data()['status'] as String?) == 'done',
      );
    } catch (_) {
      return false;
    }
  }

  // ── Get overall course progress 0.0–1.0 ───────────────────────────────────
  static Future<double> getCourseProgress(String courseId) async {
    try {
      final courseRef = _db.collection('courses').doc(courseId);
      final modulesSnap = await courseRef.collection('modules').get();
      if (modulesSnap.docs.isEmpty) return 0.0;
      final done = modulesSnap.docs
          .where((d) => (d.data()['status'] as String?) == 'done')
          .length;
      return done / modulesSnap.docs.length;
    } catch (_) {
      return 0.0;
    }
  }

  // ── Internal: mark course complete, award badge ───────────────────────────
  static Future<void> _markCourseComplete({
    required String uid,
    required String courseId,
    required String courseTag,
    required DocumentReference userRef,
    required DocumentReference courseRef,
  }) async {
    await courseRef.set({
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Badge goes into a map field (not arrayUnion) so serverTimestamp is safe
    final badgeKey = 'badges.complete_$courseId';
    try {
      await userRef.update({
        badgeKey: FieldValue.serverTimestamp(),
        'completedCourses': FieldValue.arrayUnion([courseId]),
      });
    } catch (_) {
      await userRef.set({
        'badges': {
          'complete_$courseId': FieldValue.serverTimestamp(),
        },
        'completedCourses': FieldValue.arrayUnion([courseId]),
      }, SetOptions(merge: true));
    }
  }

  // ── Internal: update daily streak ─────────────────────────────────────────
  static Future<void> _updateStreak(DocumentReference userRef) async {
    try {
      final snap = await userRef.get();
      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastTs = data['lastActiveDate'] as Timestamp?;
      final last = lastTs != null
          ? DateTime(
              lastTs.toDate().year,
              lastTs.toDate().month,
              lastTs.toDate().day,
            )
          : null;

      int streak = (data['streak'] as int?) ?? 0;

      if (last == null) {
        streak = 1;
      } else if (last == today) {
        return;
      } else if (today.difference(last).inDays == 1) {
        streak += 1;
      } else {
        streak = 1;
      }

      await userRef.set({
        'streak': streak,
        'lastActiveDate': Timestamp.fromDate(today),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
