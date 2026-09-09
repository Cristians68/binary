import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

import 'notification_backend.dart';
import 'notification_prefs.dart';
import 'notification_schedule.dart';
import 'service_backend.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// The route a tapped notification asked for, waiting to be consumed.
///
/// Taps used to reach a `debugPrint` and go no further, so every reminder was
/// a dead end: it opened the app to wherever it had been left.
///
/// This is a notifier rather than a direct `Navigator.pushNamed` because the
/// app has no named routes — `MainNavigation` is a tab shell, so "open
/// courses" means selecting a tab, not pushing a page. It also handles the
/// cold-start case: a tap can be delivered before any navigator exists, and
/// holding the value lets `MainNavigation` consume it when it finally mounts.
final ValueNotifier<String?> pendingNotificationRoute =
    ValueNotifier<String?>(null);

class NotificationService {
  // Through the ServiceBackend seam, not FirebaseFirestore.instance directly.
  // Reaching for the singleton is what made every other static service
  // untestable, and applyPrefs writes a user field, so it needs the same seam.
  static FirebaseFirestore get _db => ServiceBackend.db;
  static String? get _uid => ServiceBackend.uid;

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  /// Test seam. Falls back to the real plugin when nothing is installed.
  static NotificationBackend get _backend =>
      NotificationBackendHolder.current ?? const _PluginBackend();

  /// Whether the real plugin is usable. A fake backend bypasses this, so tests
  /// do not have to pretend the platform channel exists.
  static bool get _ready =>
      NotificationBackendHolder.current != null || (!kIsWeb && _initialised);

  // Android notification channel
  static const _androidChannel = AndroidNotificationChannel(
    'binary_main',
    'B1nary Notifications',
    description: 'Streak reminders and course updates',
    importance: Importance.high,
  );

  // ── Boot — call once from main() ──────────────────────────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;

    // Initialise timezone database
    tz.initializeTimeZones();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── Android channel setup ──
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // ── Plugin init (both platforms) ──
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // ── FCM foreground listener ──
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // ── Token refresh listener ──
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveFcmToken);

    _initialised = true;
  }

  // ── Request permissions + save FCM token ──────────────────────────────────
  ///
  /// Only ever called from the priming screen, after the user has said yes to
  /// our own explanation. It used to fire unconditionally on every sign-in,
  /// which spent the one-shot iOS prompt before the user had seen a single
  /// lesson — and a denied prompt cannot be re-asked in-app.
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (granted) {
      final token = await messaging.getToken();
      if (token != null) await _saveFcmToken(token);
    }

    return granted;
  }

  // ── The single entry point for scheduled reminders ────────────────────────
  /// Make the device match [prefs].
  ///
  /// Cancels every id in [kManagedReminderIds] and then schedules exactly
  /// `remindersFor(prefs)`. Idempotent, so it is safe to call on every app
  /// start and on every settings change — which is what makes the toggles
  /// honest: switching one off removes it from the list, and the next apply
  /// deletes it from the device.
  ///
  /// Cancels the managed ids specifically rather than calling `cancelAll()`,
  /// so a badge notification the user has not yet dismissed survives an
  /// unrelated settings change.
  static Future<void> applyPrefs(NotificationPrefs prefs) async {
    if (!_ready) return;

    final backend = _backend;
    for (final id in kManagedReminderIds) {
      await backend.cancel(id);
    }
    for (final reminder in remindersFor(prefs)) {
      await backend.schedule(reminder);
    }

    await _recordLocalReminderUse(prefs.anySchedulable);
  }

  /// Tell the server whether this user is covered by on-device reminders.
  ///
  /// `reminderCandidates()` in `functions/` skips anyone carrying
  /// `usesLocalReminders`, so nobody receives both a local and a push copy of
  /// the same nudge. A user who never grants permission never carries the
  /// flag, so the server stays their fallback.
  static Future<void> _recordLocalReminderUse(bool uses) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set(
        {'usesLocalReminders': uses},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('NotificationService.usesLocalReminders write failed: $e');
    }
  }

  // ── Cancel all scheduled notifications ───────────────────────────────────
  static Future<void> cancelAll() async {
    if (!_ready) return;
    for (final id in kManagedReminderIds) {
      await _backend.cancel(id);
    }
  }

  // ── Course complete — immediate local notification ────────────────────────
  static Future<void> showCourseCompleteNotification(
      String courseTitle) async {
    if (!_ready) return;
    await _backend.show(
      kIdCourseComplete,
      '🎓 Course complete!',
      "You've completed $courseTitle. Your certificate is ready.",
      payload: routeProgress,
    );
  }

  // ── Badge earned notification ─────────────────────────────────────────────
  static Future<void> showBadgeEarnedNotification(
      String badgeTitle, String emoji) async {
    if (!_ready) return;
    await _backend.show(
      kIdBadgeEarned,
      '$emoji Badge earned!',
      'You earned the "$badgeTitle" badge. Keep it up!',
      payload: routeBadges,
    );
  }

  // ── Handle FCM messages received while app is in foreground ──────────────
  static void _handleForegroundMessage(RemoteMessage message) {
    if (!_initialised) return;
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Open the route a notification carries.
  ///
  /// Routes are whitelisted. The payload is our own, but it is persisted by
  /// the OS and survives an app update, so an id from an older build must not
  /// be able to push something unexpected.
  @visibleForTesting
  static void handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (!kNotificationRoutes.contains(payload)) {
      debugPrint('Ignoring unknown notification payload: $payload');
      return;
    }
    pendingNotificationRoute.value = payload;
  }

  static void _onNotificationTap(NotificationResponse response) {
    handlePayload(response.payload);
  }

  // ── Save FCM token to Firestore ───────────────────────────────────────────
  static Future<void> _saveFcmToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
      'platform': Platform.isIOS ? 'ios' : 'android',
    }, SetOptions(merge: true));
  }
}

/// Drives the real `flutter_local_notifications` plugin.
class _PluginBackend implements NotificationBackend {
  const _PluginBackend();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'binary_main';
  static const _channelName = 'B1nary Notifications';

  NotificationDetails _details({required bool high}) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Streak reminders and course updates',
          importance: high ? Importance.high : Importance.defaultImportance,
          priority: high ? Priority.high : Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: high,
          presentSound: high,
        ),
      );

  @override
  Future<void> schedule(ScheduledReminder reminder) async {
    await _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      reminder.body,
      _nextInstanceOf(
        reminder.hour,
        reminder.minute,
        weekday: reminder.weekday,
      ),
      _details(high: reminder.id == kIdStreakReminder),
      payload: reminder.payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: reminder.repeat == Repeat.weekly
          ? DateTimeComponents.dayOfWeekAndTime
          : DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> show(int id, String title, String body, {String? payload}) =>
      _plugin.show(id, title, body, _details(high: true), payload: payload);

  /// The next time [hour]:[minute] comes around, optionally on [weekday].
  static tz.TZDateTime _nextInstanceOf(int hour, int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (weekday != null) {
      // Walk forward to the requested weekday. Bounded at 7 steps; a weekday
      // outside 1..7 would otherwise loop forever.
      var guard = 0;
      while (scheduled.weekday != weekday && guard < 7) {
        scheduled = scheduled.add(const Duration(days: 1));
        guard++;
      }
    }
    return scheduled;
  }
}
