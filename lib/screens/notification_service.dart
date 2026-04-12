import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> init() async {
    if (kIsWeb) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

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

  static Future<void> scheduleStreakReminder() async {}
  static Future<void> scheduleDailyGoalReminder() async {}
  static Future<void> cancelAll() async {}
  static Future<void> showCourseCompleteNotification(
    String courseTitle,
  ) async {}

  static Future<void> _saveFcmToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
