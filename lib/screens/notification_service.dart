import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  // Android notification channel
  static const _androidChannel = AndroidNotificationChannel(
    'binary_main',
    'Binary Notifications',
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

  // ── Schedule daily streak reminder at 8pm local time ─────────────────────
  static Future<void> scheduleStreakReminder() async {
    if (kIsWeb || !_initialised) return;

    await _local.cancel(1);

    await _local.zonedSchedule(
      1,
      '🔥 Keep your streak alive!',
      'Open Binary and complete a lesson to maintain your streak.',
      _nextInstanceOf(20, 0), // 8:00 PM
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Schedule daily goal reminder at 6pm local time ────────────────────────
  static Future<void> scheduleDailyGoalReminder() async {
    if (kIsWeb || !_initialised) return;

    await _local.cancel(2);

    await _local.zonedSchedule(
      2,
      '📚 Daily goal check-in',
      "Don't forget to hit your learning goal for today!",
      _nextInstanceOf(18, 0), // 6:00 PM
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Cancel all scheduled notifications ───────────────────────────────────
  static Future<void> cancelAll() async {
    if (kIsWeb || !_initialised) return;
    await _local.cancelAll();
  }

  // ── Course complete — immediate local notification ────────────────────────
  static Future<void> showCourseCompleteNotification(
      String courseTitle) async {
    if (kIsWeb || !_initialised) return;
    await _local.show(
      3,
      '🎓 Course complete!',
      "You've completed $courseTitle. Your certificate is ready.",
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

  // ── Badge earned notification ─────────────────────────────────────────────
  static Future<void> showBadgeEarnedNotification(
      String badgeTitle, String emoji) async {
    if (kIsWeb || !_initialised) return;
    await _local.show(
      4,
      '$emoji Badge earned!',
      'You earned the "$badgeTitle" badge. Keep it up!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
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

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
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

  // ── Returns the next TZDateTime for a given hour:minute (repeats daily) ───
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
