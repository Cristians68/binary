import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String kSingleCourseProductId = 'binary_single_monthly';
const String kAllCoursesProductId = 'binary_all_monthly';
const String kRevenueCatApiKey = 'appl_HRXqLWNhneveCEBKZdSgczigiGk';

enum SubscriptionPlan { none, single, all }

class SubscriptionService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> configure() async {
    if (kIsWeb) return;
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final config = PurchasesConfiguration(kRevenueCatApiKey);
      await Purchases.configure(config);
      final uid = _uid;
      if (uid != null) {
        await Purchases.logIn(uid);
      }
    } catch (e) {
      debugPrint('RevenueCat configure failed: $e');
    }
  }

  static Future<void> identifyUser() async {
    if (kIsWeb) return;
    try {
      final uid = _uid;
      if (uid != null) {
        await Purchases.logIn(uid);
      }
    } catch (e) {
      debugPrint('RevenueCat identifyUser failed: $e');
    }
  }

  static Future<List<Package>> getPackages() async {
    if (kIsWeb) return [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> purchase(Package package, {String? courseId}) async {
    if (kIsWeb) return false;
    try {
      final purchaseParams = PurchaseParams.package(package);
      final result = await Purchases.purchase(purchaseParams);
      await _syncToFirestore(result.customerInfo, courseId: courseId);
      return true;
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('cancel') || err.contains('usercancel')) return false;
      rethrow;
    }
  }

  static Future<bool> restore() async {
    if (kIsWeb) return false;
    try {
      final info = await Purchases.restorePurchases();
      await _syncToFirestore(info);
      return info.entitlements.active.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<CustomerInfo?> getCustomerInfo() async {
    if (kIsWeb) return null;
    try {
      return await Purchases.getCustomerInfo();
    } catch (_) {
      return null;
    }
  }

  static Future<SubscriptionPlan> getCurrentPlan() async {
    if (kIsWeb) return SubscriptionPlan.none;
    try {
      final info = await Purchases.getCustomerInfo();
      return _planFromInfo(info);
    } catch (_) {
      return SubscriptionPlan.none;
    }
  }

  static Future<bool> canAccessCourse(String courseId) async {
    if (kIsWeb) return true;
    try {
      final info = await Purchases.getCustomerInfo();
      final plan = _planFromInfo(info);
      if (plan == SubscriptionPlan.all) return true;
      if (plan == SubscriptionPlan.single) {
        final uid = _uid;
        if (uid == null) return false;
        final snap = await _db.collection('users').doc(uid).get();
        final subscribedCourse = snap.data()?['subscribedCourseId'] as String?;
        return subscribedCourse == courseId;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasUsedTrial() async {
    if (kIsWeb) return false;
    try {
      final uid = _uid;
      if (uid == null) return false;
      final snap = await _db.collection('users').doc(uid).get();
      return snap.data()?['hasUsedTrial'] == true;
    } catch (_) {
      return false;
    }
  }

  static Stream<SubscriptionPlan> planStream() {
    if (kIsWeb) return Stream.value(SubscriptionPlan.none);
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? {};
      final plan = data['subscriptionPlan'] as String? ?? 'none';
      switch (plan) {
        case 'all':
          return SubscriptionPlan.all;
        case 'single':
          return SubscriptionPlan.single;
        default:
          return SubscriptionPlan.none;
      }
    });
  }

  static SubscriptionPlan _planFromInfo(CustomerInfo info) {
    final entitlements = info.entitlements.active;
    if (entitlements.containsKey('all_courses')) return SubscriptionPlan.all;
    if (entitlements.containsKey('single_course'))
      return SubscriptionPlan.single;
    return SubscriptionPlan.none;
  }

  static Future<void> _syncToFirestore(
    CustomerInfo info, {
    String? courseId,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final plan = _planFromInfo(info);
    final planString = plan == SubscriptionPlan.all
        ? 'all'
        : plan == SubscriptionPlan.single
        ? 'single'
        : 'none';
    final Map<String, dynamic> update = {
      'subscriptionPlan': planString,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      'hasUsedTrial': true,
    };
    if (plan == SubscriptionPlan.single && courseId != null) {
      update['subscribedCourseId'] = courseId;
    }
    await _db.collection('users').doc(uid).set(update, SetOptions(merge: true));
  }
}
