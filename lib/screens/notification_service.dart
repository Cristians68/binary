import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const int _streakNotifId = 1001;
  static const int _dailyNotifId = 1002;

  static IOSFlutterLocalNotificationsPlugin? get _ios => _local
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  // ── Initialise — call once in main() ──────────────────────────────────────
  static Future<void> init() async {
    tz.initializeTimeZones();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _ios?.initialize(
      settings: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  // ── Request permissions (iOS) ─────────────────────────────────────────────
  static Future<bool> requestPermissions() async {
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
      messaging.onTokenRefresh.listen(_saveFcmToken);
      await scheduleStreakReminder();
      await scheduleDailyGoalReminder();
    }

    return granted;
  }

  // ── Schedule daily streak reminder at 8pm ─────────────────────────────────
  static Future<void> scheduleStreakReminder() async {
    await _ios?.zonedSchedule(
      id: _streakNotifId,
      title: '🔥 Keep your streak alive!',
      body:
          'You haven\'t studied today. Open the app to keep your streak going.',
      scheduledDate: _nextInstanceOfTime(20, 0),
      notificationDetails: const DarwinNotificationDetails(),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Schedule daily goal reminder at 12pm ──────────────────────────────────
  static Future<void> scheduleDailyGoalReminder() async {
    await _ios?.zonedSchedule(
      id: _dailyNotifId,
      title: '📚 Time to study!',
      body: 'Complete 3 lessons today to hit your daily goal.',
      scheduledDate: _nextInstanceOfTime(12, 0),
      notificationDetails: const DarwinNotificationDetails(),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Cancel notifications ──────────────────────────────────────────────────
  static Future<void> cancelAll() async {
    await _local.cancelAll();
  }

  // ── Show immediate notification (e.g. course complete) ────────────────────
  static Future<void> showCourseCompleteNotification(String courseTitle) async {
    await _local.show(
      id: 9001,
      title: '🎉 Course Complete!',
      body: 'You\'ve completed $courseTitle. Your certificate is ready!',
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Internal helpers ──────────────────────────────────────────────────────
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> _saveFcmToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static void _onNotificationTap(NotificationResponse response) {}
}
