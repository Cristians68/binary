import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Product identifiers ──────────────────────────────────────────────────────
const String kProductSingle    = 'binary_course_single';
const String kProductBundle4   = 'binary_bundle_4';
const String kProductBundleAll = 'binary_bundle_all';

// ── Entitlement ───────────────────────────────────────────────────────────────
const String kEntitlementPro = 'B1nary Academy Pro';

// ── RevenueCat API key ────────────────────────────────────────────────────────
const String kRevenueCatApiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: 'appl_HRXqLWNhneveCEBKZdSgczigiGk',
);

enum SubscriptionPlan { none, single, bundle4, all, trial }

class SubscriptionService {
  static FirebaseFirestore get _db  => FirebaseFirestore.instance;
  static String?           get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> configure() async {
    if (kIsWeb) return;
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final config = PurchasesConfiguration(kRevenueCatApiKey);
      await Purchases.configure(config);
      final uid = _uid;
      if (uid != null) {
        await Purchases.logIn(uid);
        debugPrint('RevenueCat: logged in as $uid');
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
        debugPrint('RevenueCat: identified user $uid');
      }
    } catch (e) {
      debugPrint('RevenueCat identifyUser failed: $e');
    }
  }

  /// Called on app launch / sign-in to sync RevenueCat → Firestore.
  /// This is the only place we hit the RevenueCat network on launch.
  static Future<bool> syncEntitlementsOnLaunch() async {
    if (kIsWeb)    return false;
    if (_uid == null) return false;
    try {
      final info     = await Purchases.getCustomerInfo();
      final hasActive = info.entitlements.active.isNotEmpty;
      if (hasActive) {
        await _syncToFirestore(info, markTrialUsed: false);
      }
      return hasActive;
    } catch (e) {
      debugPrint('syncEntitlementsOnLaunch failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Packages & Purchase
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Package>> getPackages() async {
    if (kIsWeb) return [];
    try {
      final offerings = await Purchases.getOfferings();
      final packages  = offerings.current?.availablePackages ?? [];
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

  /// Purchase a package.
  ///
  /// [courseId]         — required for single-course purchases.
  /// [selectedCourseIds] — required for bundle-4 purchases (the 4 chosen courses).
  ///
  /// Returns true on success, false if the user cancelled.
  /// Throws a user-facing string on any other error.
  static Future<bool> purchase(
    Package package, {
    String?       courseId,
    List<String>? selectedCourseIds,
  }) async {
    if (kIsWeb) return false;
    try {
      debugPrint('RevenueCat: purchasing ${package.storeProduct.identifier}');
      final result = await Purchases.purchase(PurchaseParams.package(package));
      debugPrint('RevenueCat: purchase success — syncing to Firestore');

      await _syncToFirestore(
        result.customerInfo,
        productId:          package.storeProduct.identifier,
        courseId:           courseId,
        selectedCourseIds:  selectedCourseIds,
        markTrialUsed:      false,
      );
      return true;
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('cancel') || err.contains('usercancel')) {
        debugPrint('RevenueCat: user cancelled');
        return false;
      }
      if (err.contains('alreadypurchased') || err.contains('already')) {
        debugPrint('RevenueCat: already purchased — restoring');
        await restore();
        return true;
      }
      debugPrint('RevenueCat purchase error: $e');
      throw 'Purchase failed. Please try again or restore purchases.';
    }
  }

  /// Restore previously purchased non-consumables.
  static Future<bool> restore() async {
    if (kIsWeb) return false;
    try {
      debugPrint('RevenueCat: restoring purchases');
      final info = await Purchases.restorePurchases();
      await _syncToFirestore(info, markTrialUsed: false);
      final hasActive = info.entitlements.active.isNotEmpty;
      debugPrint('RevenueCat: restore complete — hasActive=$hasActive');
      return hasActive;
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Access Checks  ←  Firestore-first, no live RevenueCat call
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether the user can access a specific course.
  ///
  /// Reads from Firestore (written by [_syncToFirestore] immediately after
  /// purchase/restore). Falls back to a live RevenueCat call only if the
  /// Firestore document has no recognised plan — e.g. fresh install with a
  /// previous purchase that hasn't been synced yet.
  static Future<bool> canAccessCourse(String courseId) async {
    if (kIsWeb) return true;

    final uid = _uid;
    if (uid == null) return false;

    try {
      // ── 1. Read Firestore (fast, offline-capable) ──────────────────────
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final planString = data['subscriptionPlan'] as String? ?? 'none';

      debugPrint('canAccessCourse($courseId): Firestore plan=$planString');

      if (planString == 'all') return true;

      if (planString == 'bundle4') {
        final List<dynamic> courses =
            (data['bundleCourseIds'] as List<dynamic>?) ?? [];
        return courses.contains(courseId);
      }

      if (planString == 'single') {
        return data['subscribedCourseId'] == courseId;
      }

      // ── 2. Trial check ─────────────────────────────────────────────────
      final trialCourseId = data['trialCourseId']  as String?;
      final trialExpiry   = data['trialExpiry']    as Timestamp?;
      if (trialCourseId == courseId && trialExpiry != null) {
        return trialExpiry.toDate().isAfter(DateTime.now());
      }

      // ── 3. Firestore says 'none' — fall back to RevenueCat live check ──
      // This handles the edge case where the user has a valid purchase but
      // _syncToFirestore hasn't run yet (e.g. reinstall, new device).
      debugPrint(
          'canAccessCourse: Firestore has no plan — checking RevenueCat live');
      final info = await Purchases.getCustomerInfo();
      final plan = _planFromInfo(info);

      if (plan == SubscriptionPlan.none) return false;

      // We found an entitlement that Firestore doesn't know about yet — sync it.
      await _syncToFirestore(info, markTrialUsed: false);

      // Re-run the Firestore check now that we've synced.
      return canAccessCourse(courseId);
    } catch (e) {
      debugPrint('canAccessCourse error: $e');
      return false;
    }
  }

  /// Whether the user can access a specific module.
  /// module-01 is always free for everyone.
  static Future<bool> canAccessModule({
    required String courseId,
    required String moduleId,
  }) async {
    if (moduleId == 'module-01') return true;
    return canAccessCourse(courseId);
  }

  static Future<SubscriptionPlan> getCurrentPlan() async {
    if (kIsWeb) return SubscriptionPlan.none;
    try {
      final info = await Purchases.getCustomerInfo();
      return _planFromInfo(info);
    } catch (e) {
      debugPrint('getCurrentPlan error: $e');
      return SubscriptionPlan.none;
    }
  }

  /// Real-time Firestore stream of the user's plan.
  /// Used by UI widgets that should react instantly to a purchase.
  static Stream<SubscriptionPlan> planStream() {
    if (kIsWeb) return Stream.value(SubscriptionPlan.none);
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? {};
      switch (data['subscriptionPlan'] as String? ?? 'none') {
        case 'all':     return SubscriptionPlan.all;
        case 'bundle4': return SubscriptionPlan.bundle4;
        case 'single':  return SubscriptionPlan.single;
        default:        return SubscriptionPlan.none;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Trial
  // ─────────────────────────────────────────────────────────────────────────

  static Future<bool> startTrial(String courseId) async {
    final uid = _uid;
    if (uid == null) return false;

    return _db.runTransaction<bool>((tx) async {
      final ref  = _db.collection('users').doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};

      if (data['hasUsedTrial'] == true) {
        debugPrint('startTrial: already used');
        return false;
      }

      final expiry = DateTime.now().add(const Duration(days: 7));
      tx.set(ref, {
        'trialCourseId':   courseId,
        'trialExpiry':     Timestamp.fromDate(expiry),
        'hasUsedTrial':    true,
        'trialStartedAt':  FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('startTrial: granted for $courseId until $expiry');
      return true;
    });
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

  static Future<bool> isInActiveTrial() async {
    if (kIsWeb) return false;
    try {
      final uid = _uid;
      if (uid == null) return false;
      final snap = await _db.collection('users').doc(uid).get();
      final data   = snap.data() ?? {};
      final expiry = data['trialExpiry'] as Timestamp?;
      if (expiry == null) return false;
      return expiry.toDate().isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  static SubscriptionPlan _planFromInfo(CustomerInfo info) {
    final active = info.entitlements.active;
    debugPrint('RC active entitlements: ${active.keys.toList()}');
    if (!active.containsKey(kEntitlementPro)) return SubscriptionPlan.none;

    final productId = active[kEntitlementPro]?.productIdentifier ?? '';
    debugPrint('RC active product: $productId');

    if (productId == kProductBundleAll) return SubscriptionPlan.all;
    if (productId == kProductBundle4)   return SubscriptionPlan.bundle4;
    if (productId == kProductSingle)    return SubscriptionPlan.single;

    return SubscriptionPlan.single; // unknown product → fail-safe to single
  }

  static Future<void> _syncToFirestore(
    CustomerInfo info, {
    String?       productId,
    String?       courseId,
    List<String>? selectedCourseIds,
    bool          markTrialUsed = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final resolvedProductId = productId ??
        info.entitlements.active[kEntitlementPro]?.productIdentifier ??
        '';

    SubscriptionPlan plan;
    if      (resolvedProductId == kProductBundleAll) plan = SubscriptionPlan.all;
    else if (resolvedProductId == kProductBundle4)   plan = SubscriptionPlan.bundle4;
    else if (resolvedProductId == kProductSingle)    plan = SubscriptionPlan.single;
    else                                              plan = _planFromInfo(info);

    final planString = {
      SubscriptionPlan.all:     'all',
      SubscriptionPlan.bundle4: 'bundle4',
      SubscriptionPlan.single:  'single',
      SubscriptionPlan.none:    'none',
      SubscriptionPlan.trial:   'trial',
    }[plan]!;

    final Map<String, dynamic> update = {
      'subscriptionPlan':       planString,
      'subscriptionUpdatedAt':  FieldValue.serverTimestamp(),
    };

    if (markTrialUsed) update['hasUsedTrial'] = true;

    // Single purchase — record which course was unlocked
    if (plan == SubscriptionPlan.single && courseId != null) {
      update['subscribedCourseId'] = courseId;
    }

    // Bundle-4 purchase — record the chosen course IDs
    // selectedCourseIds must be provided by the paywall before calling purchase().
    if (plan == SubscriptionPlan.bundle4) {
      if (selectedCourseIds != null && selectedCourseIds.isNotEmpty) {
        update['bundleCourseIds'] = selectedCourseIds;
      } else {
        // Safety: if somehow no selection was passed, log clearly so it's
        // easy to catch in testing — but don't crash.
        debugPrint(
            'WARNING: bundle4 purchase completed but selectedCourseIds is null/empty. '
            'bundleCourseIds will NOT be written to Firestore. '
            'Ensure the paywall collects course selections before calling purchase().');
      }
    }

    await _db
        .collection('users')
        .doc(uid)
        .set(update, SetOptions(merge: true));

    debugPrint('_syncToFirestore: wrote plan="$planString" for user $uid');
    if (plan == SubscriptionPlan.single)  debugPrint('  subscribedCourseId=${update['subscribedCourseId']}');
    if (plan == SubscriptionPlan.bundle4) debugPrint('  bundleCourseIds=${update['bundleCourseIds']}');
  }
}