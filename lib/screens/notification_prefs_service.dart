import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_prefs.dart';
import 'notification_service.dart';
import 'service_backend.dart';

/// Loads and saves [NotificationPrefs], and keeps the device in step with them.
///
/// Preferences live in two places on purpose. Firestore is the record the
/// Cloud Functions read; SharedPreferences is a local mirror so app start can
/// schedule reminders immediately rather than waiting on a network round trip
/// — a user who opens the app offline still keeps their reminders.
class NotificationPrefsService {
  NotificationPrefsService._();

  static const String _localKey = 'notificationPrefs';

  /// SharedPreferences key marking the priming screen as already shown.
  static const String primedKey = 'notificationPrimingShown';

  static DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = ServiceBackend.uid;
    if (uid == null) return null;
    return ServiceBackend.db.collection('users').doc(uid);
  }

  /// The local mirror. Never touches the network, so it is safe at app start.
  static Future<NotificationPrefs> loadLocal() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return NotificationPrefs.fromJson(sp.getString(_localKey));
    } catch (e) {
      debugPrint('NotificationPrefsService.loadLocal failed: $e');
      return NotificationPrefs.defaults;
    }
  }

  /// The authoritative copy, falling back to the local mirror when offline.
  static Future<NotificationPrefs> load() async {
    final doc = _userDoc;
    if (doc == null) return loadLocal();
    try {
      final snap = await doc.get();
      final data = snap.data() ?? {};
      final raw = data['notificationPrefs'];
      final prefs = NotificationPrefs.fromMap(
        raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v)) : null,
        legacyEnabled: data['notificationsEnabled'] as bool?,
      );
      await _writeLocal(prefs);
      return prefs;
    } catch (e) {
      debugPrint('NotificationPrefsService.load failed: $e');
      return loadLocal();
    }
  }

  /// Persist [prefs] everywhere and reschedule the device to match.
  ///
  /// The device is updated even if the Firestore write fails, because a toggle
  /// that visibly flips but changes nothing on the device is the exact
  /// dishonesty this feature exists to remove.
  static Future<void> save(NotificationPrefs prefs) async {
    await _writeLocal(prefs);
    await NotificationService.applyPrefs(prefs);

    final doc = _userDoc;
    if (doc == null) return;
    try {
      await doc.set(
        {
          'notificationPrefs': prefs.toMap(),
          // Kept in sync because the deployed-later Cloud Functions still read
          // this older field.
          'notificationsEnabled': prefs.master,
          // The server schedulers run hourly and pick out the users for whom
          // it is now their chosen local hour. Without this they can only fall
          // back to UTC, which is what made a single '0 18 * * *' cron fire at
          // 10:00 in California and 04:00 in Sydney.
          'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('NotificationPrefsService.save failed: $e');
    }
  }

  /// Apply the locally mirrored preferences. Called once at app start.
  static Future<void> applyAtStartup() async {
    final prefs = await loadLocal();
    await NotificationService.applyPrefs(prefs);
  }

  static Future<void> _writeLocal(NotificationPrefs prefs) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_localKey, prefs.toJson());
    } catch (e) {
      debugPrint('NotificationPrefsService._writeLocal failed: $e');
    }
  }

  /// Whether the priming screen has already been shown to this install.
  static Future<bool> hasBeenPrimed() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getBool(primedKey) ?? false;
    } catch (_) {
      // Treat an unreadable store as "already primed" so a broken
      // SharedPreferences cannot make the app ask on every single lesson.
      return true;
    }
  }

  static Future<void> markPrimed() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(primedKey, true);
    } catch (e) {
      debugPrint('NotificationPrefsService.markPrimed failed: $e');
    }
  }
}
