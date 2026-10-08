import 'package:shared_preferences/shared_preferences.dart';

/// A signed-in session expires after a full day away from the app.
const Duration kSessionTimeoutAfter = Duration(hours: 24);
const String kSessionLastActiveAtKey = 'session_last_active_at';
// Older builds only recorded this time for App Lock. Use it once when an
// existing install first gains session expiry.
const String _previousBackgroundedAtKey = 'app_lock_backgrounded_at';

bool sessionHasExpired(DateTime? lastActiveAt, DateTime now) {
  if (lastActiveAt == null) return false;
  final away = now.difference(lastActiveAt);
  return away.isNegative || away >= kSessionTimeoutAfter;
}

class SessionTimeout {
  SessionTimeout._();

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSessionLastActiveAtKey);
    await prefs.remove(_previousBackgroundedAtKey);
  }

  static Future<void> recordActivity(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kSessionLastActiveAtKey, now.millisecondsSinceEpoch);
  }

  /// Check the persisted time before showing a restored account on launch.
  /// An existing install without the marker starts its first timeout now.
  static Future<bool> expireIfNeeded({
    required DateTime now,
    required bool signedIn,
    required Future<void> Function() signOut,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(kSessionLastActiveAtKey) ??
        prefs.getInt(_previousBackgroundedAtKey);
    final lastActive =
        saved == null ? null : DateTime.fromMillisecondsSinceEpoch(saved);
    if (signedIn && sessionHasExpired(lastActive, now)) {
      await signOut();
      await clear();
      return true;
    }
    await prefs.setInt(kSessionLastActiveAtKey, now.millisecondsSinceEpoch);
    return false;
  }
}
