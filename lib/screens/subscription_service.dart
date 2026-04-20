import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String kProductSingle = 'binary_course_single';
const String kProductBundle4 = 'binary_bundle_4';
const String kProductBundleAll = 'binary_bundle_all';

const String kEntitlementSingle = 'single_course';
const String kEntitlementBundle4 = 'bundle_4';
const String kEntitlementAll = 'all_courses';

const String kRevenueCatApiKey = 'appl_HRXqLWNhneveCEBKZdSgczigiGk';

enum SubscriptionPlan { none, single, bundle4, all }

class SubscriptionService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Configure RevenueCat on app start ─────────────────────────────────────
  static Future<void> configure() async {
    if (kIsWeb) return;
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final config = PurchasesConfiguration(kRevenueCatApiKey);
      await Purchases.configure(config);
      // Always log in after configure so RC knows who this user is.
      // If uid is null here (anonymous auth still initialising),
      // identifyUser() is called again after auth completes.
      final uid = _uid;
      if (uid != null) {
        await Purchases.logIn(uid);
        debugPrint('RevenueCat: logged in as $uid');
      }
    } catch (e) {
      debugPrint('RevenueCat configure failed: $e');
    }
  }

  // ── Identify user after sign-in ───────────────────────────────────────────
  // Call this after every successful Firebase Auth login/anonymous sign-in.
  static Future<void> identifyUser() async {
    if (kIsWeb) return;
    try {
      final uid = _uid;
      if (uid != null) {
        await Purchases.logIn(uid);
        debugPrint('RevenueCat: identified user $uid');
      }
    } catch (e) {
      debugPrint('RevenueCat identifyUser failed: $e');
    }
  }

  // ── Fetch available packages from RevenueCat ──────────────────────────────
  // Returns empty list on any error — callers should handle empty gracefully.
  static Future<List<Package>> getPackages() async {
    if (kIsWeb) return [];
    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? [];
      debugPrint('RevenueCat: loaded ${packages.length} packages');
      for (final p in packages) {
        debugPrint('  → ${p.storeProduct.identifier} ${p.storeProduct.price}');
      }
      return packages;
    } catch (e) {
      debugPrint('RevenueCat getPackages failed: $e');
      return [];
    }
  }

  // ── Purchase a package ────────────────────────────────────────────────────
  // Returns true on success, false on user cancel.
  // Throws a human-readable String on any other error.
  static Future<bool> purchase(
    Package package, {
    String? courseId,
    List<String>? selectedCourseIds,
  }) async {
    if (kIsWeb) return false;
    try {
      debugPrint('RevenueCat: purchasing ${package.storeProduct.identifier}');
      final result = await Purchases.purchase(PurchaseParams.package(package));
      debugPrint('RevenueCat: purchase success, syncing to Firestore');
      await _syncToFirestore(
        result.customerInfo,
        courseId: courseId,
        selectedCourseIds: selectedCourseIds,
      );
      return true;
    } catch (e) {
      final err = e.toString().toLowerCase();
      // User cancelled — not an error.
      if (err.contains('cancel') || err.contains('usercancel')) {
        debugPrint('RevenueCat: user cancelled purchase');
        return false;
      }
      // PurchasesErrorCode already purchased — treat as success and sync.
      if (err.contains('alreadypurchased') || err.contains('already')) {
        debugPrint('RevenueCat: already purchased, restoring');
        await restore();
        return true;
      }
      debugPrint('RevenueCat purchase error: $e');
      // Re-throw with a clean message the UI can display.
      throw 'Purchase failed. Please try again or restore purchases.';
    }
  }

  // ── Restore purchases ─────────────────────────────────────────────────────
  static Future<bool> restore() async {
    if (kIsWeb) return false;
    try {
      debugPrint('RevenueCat: restoring purchases');
      final info = await Purchases.restorePurchases();
      await _syncToFirestore(info);
      final hasActive = info.entitlements.active.isNotEmpty;
      debugPrint('RevenueCat: restore complete, hasActive=$hasActive');
      return hasActive;
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
      return false;
    }
  }

  // ── Check if user can access a specific course ────────────────────────────
  // SOURCE OF TRUTH: RevenueCat entitlements (not just Firestore).
  // Falls back to Firestore for course-specific single/bundle checks.
  static Future<bool> canAccessCourse(String courseId) async {
    if (kIsWeb) return true;
    try {
      final info = await Purchases.getCustomerInfo();
      final plan = _planFromInfo(info);
      debugPrint('canAccessCourse($courseId): plan=$plan');

      // All-access — no further check needed.
      if (plan == SubscriptionPlan.all) return true;

      final uid = _uid;
      if (uid == null) return false;

      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? {};

      // Bundle of 4 — course must be in their selected list.
      if (plan == SubscriptionPlan.bundle4) {
        final List<dynamic> courses =
            (data['bundleCourseIds'] as List<dynamic>?) ?? [];
        return courses.contains(courseId);
      }

      // Single course purchase.
      if (plan == SubscriptionPlan.single) {
        return data['subscribedCourseId'] == courseId;
      }

      // No active entitlement — check trial.
      final trialCourseId = data['trialCourseId'] as String?;
      final trialExpiry = data['trialExpiry'] as Timestamp?;
      if (trialCourseId == courseId && trialExpiry != null) {
        return trialExpiry.toDate().isAfter(DateTime.now());
      }

      return false;
    } catch (e) {
      debugPrint('canAccessCourse error: $e');
      return false;
    }
  }

  // ── Get current plan ──────────────────────────────────────────────────────
  static Future<SubscriptionPlan> getCurrentPlan() async {
    if (kIsWeb) return SubscriptionPlan.none;
    try {
      final info = await Purchases.getCustomerInfo();
      final plan = _planFromInfo(info);
      debugPrint('getCurrentPlan: $plan');
      return plan;
    } catch (e) {
      debugPrint('getCurrentPlan error: $e');
      return SubscriptionPlan.none;
    }
  }

  // ── Check if user has already used their trial ────────────────────────────
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

  // ── Real-time plan stream (for UI reactivity) ─────────────────────────────
  static Stream<SubscriptionPlan> planStream() {
    if (kIsWeb) return Stream.value(SubscriptionPlan.none);
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? {};
      switch (data['subscriptionPlan'] as String? ?? 'none') {
        case 'all':
          return SubscriptionPlan.all;
        case 'bundle4':
          return SubscriptionPlan.bundle4;
        case 'single':
          return SubscriptionPlan.single;
        default:
          return SubscriptionPlan.none;
      }
    });
  }

  // ─────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────

  static SubscriptionPlan _planFromInfo(CustomerInfo info) {
    final active = info.entitlements.active;
    debugPrint('RC active entitlements: ${active.keys.toList()}');
    if (active.containsKey(kEntitlementAll)) return SubscriptionPlan.all;
    if (active.containsKey(kEntitlementBundle4))
      return SubscriptionPlan.bundle4;
    if (active.containsKey(kEntitlementSingle)) return SubscriptionPlan.single;
    return SubscriptionPlan.none;
  }

  static Future<void> _syncToFirestore(
    CustomerInfo info, {
    String? courseId,
    List<String>? selectedCourseIds,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final plan = _planFromInfo(info);
    final planString = {
      SubscriptionPlan.all: 'all',
      SubscriptionPlan.bundle4: 'bundle4',
      SubscriptionPlan.single: 'single',
      SubscriptionPlan.none: 'none',
    }[plan]!;

    final Map<String, dynamic> update = {
      'subscriptionPlan': planString,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      'hasUsedTrial': true,
    };

    if (plan == SubscriptionPlan.single && courseId != null) {
      update['subscribedCourseId'] = courseId;
    }

    if (plan == SubscriptionPlan.bundle4 && selectedCourseIds != null) {
      update['bundleCourseIds'] = selectedCourseIds;
    }

    await _db.collection('users').doc(uid).set(update, SetOptions(merge: true));
    debugPrint('Synced plan "$planString" to Firestore for $uid');
  }
}
