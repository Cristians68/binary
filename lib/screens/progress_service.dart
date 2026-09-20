import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';
import 'quiz_logic.dart';
import 'service_backend.dart';
import 'streak_service.dart';

class ProgressService {
  static FirebaseFirestore get _db => ServiceBackend.db;
  static String? get _uid => ServiceBackend.uid;

  /// Commit a quiz pass atomically. A save retry with the same attempt ID is a
  /// no-op; repeating a module never counts it as a second completed lesson.
  static Future<void> completeModule({
    required String courseId,
    required String moduleId,
    required String moduleTitle,
    required String courseTag,
    required int score,
    required int total,
    String? attemptId,
    String? expectedUserId,
  }) async {
    final uid = _uid;
    if (uid == null || (expectedUserId != null && expectedUserId != uid)) {
      throw StateError('Sign back in to the account that started this quiz');
    }
    if (!quizPassed(score, total) || score > total) {
      throw ArgumentError('Only a valid passing quiz can complete a module');
    }
    final db = _db;
    final modules = (await db
            .collection('courses')
            .doc(courseId)
            .collection('modules')
            .get())
        .docs
        .toList()
      ..sort((a, b) => ((a.data()['order'] as num?) ?? 0)
          .compareTo((b.data()['order'] as num?) ?? 0));
    if (!modules.any((module) => module.id == moduleId)) {
      throw StateError('This module is no longer part of the course');
    }
    final userRef = db.collection('users').doc(uid);
    final progressRef = userRef.collection('progress').doc(courseId);
    final moduleRef = progressRef.collection('modules').doc(moduleId);
    final attemptRef = attemptId == null
        ? null
        : moduleRef.collection('attempts').doc(attemptId);
    final result = await db
        .runTransaction<({bool saved, bool courseCompleted})>((tx) async {
      if (_uid != uid) throw StateError('Account changed while saving');
      // Keep a receipt for each attempt. Remembering only the latest attempt
      // lets a delayed retry count again after a newer retake has been saved.
      if (attemptRef != null && (await tx.get(attemptRef)).exists) {
        return (saved: false, courseCompleted: false);
      }
      final user = (await tx.get(userRef)).data() ?? {};
      final previousProgress = (await tx.get(progressRef)).data() ?? {};
      final states = <String, Map<String, dynamic>>{};
      for (final module in modules) {
        states[module.id] =
            (await tx.get(progressRef.collection('modules').doc(module.id)))
                    .data() ??
                {};
      }
      if (_uid != uid) throw StateError('Account changed while saving');
      final previous = states[moduleId]!;
      if (attemptId != null && previous['lastAttemptId'] == attemptId) {
        return (saved: false, courseCompleted: false);
      }
      final done = states.entries
          .where((entry) => entry.value['status'] == 'done')
          .map((entry) => entry.key)
          .toSet()
        ..add(moduleId);
      final complete = done.length == modules.length;
      final newlyComplete = complete && previousProgress['completed'] != true;
      final percent = quizScorePercent(score, total);
      final now = Timestamp.now();
      final lessons = <String, Map<String, dynamic>>{};
      for (final entry
          in (user['completedLessons'] as List? ?? []).whereType<Map>()) {
        final lesson = Map<String, dynamic>.from(entry);
        lessons['${lesson['courseId']}|${lesson['moduleId']}'] = lesson;
      }
      lessons['$courseId|$moduleId'] = {
        'courseId': courseId,
        'courseTag': courseTag,
        'moduleId': moduleId,
        'moduleTitle': moduleTitle,
        'score': score,
        'total': total,
        'percent': percent,
        'completedAt': now,
      };
      final scores = List<dynamic>.from(user['quizScores'] as List? ?? []);
      scores.add({
        'courseId': courseId,
        'moduleId': moduleId,
        'quizTitle': moduleTitle,
        'course': courseTag,
        'score': percent,
        'takenAt': now,
        if (attemptId != null) 'attemptId': attemptId,
      });
      tx.set(
          moduleRef,
          {
            'status': 'done',
            'completedAt': previous['completedAt'] ?? now,
            'bestScorePercent':
                percent > ((previous['bestScorePercent'] as num?) ?? 0)
                    ? percent
                    : previous['bestScorePercent'],
            if (attemptId != null) 'lastAttemptId': attemptId,
          },
          SetOptions(merge: true));
      final index = modules.indexWhere((m) => m.id == moduleId);
      if (index + 1 < modules.length) {
        final nextId = modules[index + 1].id;
        if (!done.contains(nextId)) {
          tx.set(progressRef.collection('modules').doc(nextId),
              {'status': 'active'}, SetOptions(merge: true));
        }
      }
      tx.set(
          progressRef,
          {
            ...previousProgress,
            'courseId': courseId,
            'progress': done.length / modules.length,
            'doneModules': done.length,
            'totalModules': modules.length,
            'lastUpdated': FieldValue.serverTimestamp(),
            if (complete) 'completed': true,
            if (newlyComplete) 'completedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      tx.set(
          userRef,
          {
            'completedLessons': lessons.values.toList(),
            'lessonsCompleted': lessons.length,
            'quizScores': scores.length > 100
                ? scores.sublist(scores.length - 100)
                : scores,
            if (complete) 'completedCourses': FieldValue.arrayUnion([courseId]),
          },
          SetOptions(merge: true));
      if (attemptRef != null) {
        tx.set(attemptRef, {'savedAt': FieldValue.serverTimestamp()});
      }
      return (saved: true, courseCompleted: newlyComplete);
    });
    // Optional rewards must never turn a successful save into a failed quiz.
    if (!result.saved || _uid != uid) return;
    await StreakService.recordLogin();
    if (_uid != uid) return;
    await StreakService.recordQuizPass(score: score, total: total);
    if (result.courseCompleted && _uid == uid) {
      await StreakService.recordCourseComplete();
      await NotificationService.showCourseCompleteNotification(courseTag);
    }
  }

  // ── Check if a course is fully complete for this user ─────────────────────
  static Future<bool> isCourseComplete(String courseId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      // Check user-specific progress
      final userProgressRef =
          _db.collection('users').doc(uid).collection('progress').doc(courseId);
      final snap = await userProgressRef.get();
      final data = snap.data() ?? {};
      return data['progress'] == 1.0 ||
          (data['doneModules'] != null &&
              data['totalModules'] is num &&
              (data['totalModules'] as num) > 0 &&
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
      final snap =
          await _db.collection('users').doc(uid).collection('progress').get();
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
}
