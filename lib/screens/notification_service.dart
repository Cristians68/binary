import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  // ── Boot — call once from main() ──────────────────────────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

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
      messaging.onTokenRefresh.listen(_saveFcmToken);
    }

    return granted;
  }

  // ── Stubbed — will be implemented with Cloud Functions ────────────────────
  static Future<void> scheduleStreakReminder() async {}
  static Future<void> scheduleDailyGoalReminder() async {}
  static Future<void> cancelAll() async {}

  // ── Course complete — immediate local notification ────────────────────────
  static Future<void> showCourseCompleteNotification(String courseTitle) async {
    if (kIsWeb || !_initialised) return;
    await _local.show(
      3,
      '🎓 Course complete!',
      'You\'ve completed $courseTitle. Your certificate is ready.',
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
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
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static void _onNotificationTap(NotificationResponse response) {}

  // ── Save FCM token to Firestore ───────────────────────────────────────────
  static Future<void> _saveFcmToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
      'platform': 'ios',
    }, SetOptions(merge: true));
  }
}
