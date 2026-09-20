import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_logic.dart';
import 'service_backend.dart';

/// Persistence for the spaced-repetition review queue.
///
/// WHY SHAREDPREFERENCES AND NOT FIRESTORE
/// ---------------------------------------
/// Review history is per-device study state, not entitlement or billing data,
/// so nothing here needs to be server-authoritative. Keeping it local means
/// this feature ships without touching `firestore.rules` or Cloud Functions —
/// which matters, because the rules and functions changes in `docs/SECURITY.md`
/// are still undeployed, and adding a new collection would put another item
/// behind that same blocked deploy.
///
/// The trade-off is real and worth stating: the queue does not follow a user to
/// a second device, and clearing app data clears it. If review history should
/// sync, it belongs in `users/{uid}/review/` with a matching rule — but that is
/// a deploy, not a code change.
///
/// All scheduling decisions live in [review_logic.dart]; this class only reads,
/// writes, and hands work to those pure functions.
class ReviewService {
  ReviewService._();

  /// Versioned so the shape can change later without misreading old data.
  // The old device-wide queue cannot be safely assigned to any account.
  static String _key(String uid) =>
      'review_queue_v2_${Uri.encodeComponent(uid)}';
  static Future<void> _pending = Future<void>.value();

  /// One session is capped so a long backlog does not present an unfinishable
  /// wall of questions. The rest stay due and come back next time.
  static const int maxSessionLength = 20;

  static Future<List<Map<String, dynamic>>> _load(String? uid) async {
    if (uid == null) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(uid));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      // Corrupt or unreadable storage must not take down the screen that asked.
      debugPrint('ReviewService: could not read the review queue: $e');
      return [];
    }
  }

  static Future<void> _save(
      String uid, List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(uid), jsonEncode(items));
    } catch (e) {
      debugPrint('ReviewService: could not write the review queue: $e');
    }
  }

  /// The whole queue, including items not yet due.
  static Future<List<Map<String, dynamic>>> all() async {
    final uid = ServiceBackend.uid;
    await _pending;
    final items = await _load(uid);
    return ServiceBackend.uid == uid ? items : [];
  }

  /// Questions ready to review right now, capped at [maxSessionLength].
  static Future<List<Map<String, dynamic>>> dueNow() async {
    final due = dueReviewItems(await all(), DateTime.now());
    return due.length <= maxSessionLength
        ? due
        : due.sublist(0, maxSessionLength);
  }

  /// How many questions are ready, for the badge on the home screen.
  static Future<int> dueCount() async =>
      dueReviewItems(await all(), DateTime.now()).length;

  /// Total questions being tracked, due or not.
  static Future<int> trackedCount() async => (await all()).length;

  /// When the queue next has something, e.g. "Ready in 3 h". Null if empty.
  static Future<String?> nextDueLabel() async =>
      nextReviewDueLabel(await all(), DateTime.now());

  static Future<void> _mutate(
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) update,
  ) {
    final uid = ServiceBackend.uid;
    if (uid == null) return Future<void>.value();
    // Capture the owner before the async gap. Serializing read-modify-write
    // prevents two rapid misses from overwriting one another.
    _pending = _pending.then((_) async {
      if (ServiceBackend.uid != uid) return;
      final items = await _load(uid);
      if (ServiceBackend.uid != uid) return;
      await _save(uid, update(items));
    }).catchError((Object error) {
      debugPrint('ReviewService: could not update queue: $error');
    });
    return _pending;
  }

  /// Files a question the user just got wrong.
  ///
  /// Safe to call for every miss — [recordMissedQuestion] deduplicates by
  /// question text rather than appending.
  static Future<void> recordMiss({
    required String courseId,
    required String moduleId,
    required String courseTag,
    required Map<String, dynamic> question,
  }) =>
      _mutate((items) => recordMissedQuestion(
            items,
            courseId: courseId,
            moduleId: moduleId,
            courseTag: courseTag,
            question: question,
            now: DateTime.now(),
          ));

  /// Records the outcome of one review attempt.
  static Future<void> submitResult({
    required String id,
    required bool correct,
  }) =>
      _mutate((items) => applyReviewResult(
            items,
            id: id,
            correct: correct,
            now: DateTime.now(),
          ));

  /// Drops everything. Used by the profile screen and on account deletion, so
  /// a device handed to someone else does not carry the previous user's
  /// study history.
  static Future<void> clear({String? userId}) {
    final uid = userId ?? ServiceBackend.uid;
    if (uid == null) return Future<void>.value();
    _pending = _pending.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(uid));
      await prefs.remove('review_queue_v1');
    }).catchError((Object error) {
      debugPrint('ReviewService: could not clear the review queue: $error');
    });
    return _pending;
  }
}
