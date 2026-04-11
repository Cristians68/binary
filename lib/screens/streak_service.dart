import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<int> checkAndUpdateStreak() async {
    final uid = _uid;
    if (uid == null) return 0;

    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastActiveTs = data['lastActiveDate'] as Timestamp?;
    final lastActive = lastActiveTs != null
        ? DateTime(
            lastActiveTs.toDate().year,
            lastActiveTs.toDate().month,
            lastActiveTs.toDate().day,
          )
        : null;

    int currentStreak = (data['streak'] as int?) ?? 0;

    if (lastActive == null) {
      currentStreak = 1;
    } else if (lastActive == today) {
      return currentStreak;
    } else if (today.difference(lastActive).inDays == 1) {
      currentStreak += 1;
    } else {
      currentStreak = 1;
    }

    await ref.set({
      'streak': currentStreak,
      'lastActiveDate': Timestamp.fromDate(today),
    }, SetOptions(merge: true));

    return currentStreak;
  }

  /// One-shot fetch of the current user's stats document.
  static Future<Map<String, dynamic>> getStats() async {
    final uid = _uid;
    if (uid == null) return {};
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    return {
      'streak': (data['streak'] as int?) ?? 0,
      'lastActiveDate': data['lastActiveDate'] as Timestamp?,
      'badges': (data['badges'] as List<dynamic>?) ?? [],
      'completedLessons': (data['completedLessons'] as List<dynamic>?) ?? [],
      'quizScores': (data['quizScores'] as List<dynamic>?) ?? [],
    };
  }

  static Stream<Map<String, dynamic>> statsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? {};
      return {
        'streak': (data['streak'] as int?) ?? 0,
        'lastActiveDate': data['lastActiveDate'] as Timestamp?,
        'badges': (data['badges'] as List<dynamic>?) ?? [],
        'completedLessons': (data['completedLessons'] as List<dynamic>?) ?? [],
        'quizScores': (data['quizScores'] as List<dynamic>?) ?? [],
      };
    });
  }
}
