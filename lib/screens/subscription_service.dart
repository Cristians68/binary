import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Product identifiers ──────────────────────────────────────────────────────
const String kProductSingle = 'binary_course_single';
const String kProductBundle4 = 'binary_bundle_4';
const String kProductBundleAll = 'binary_bundle_all';

// ── Single entitlement covering all plans (matches RevenueCat setup) ─────────
const String kEntitlementPro = 'B1nary Academy Pro';

// ── RevenueCat API key ───────────────────────────────────────────────────────
// In production builds, pass via:
//   flutter build ios --dart-define=REVENUECAT_API_KEY=appl_xxx
// Falls back to the hardcoded value if not provided so existing builds still work.
const String kRevenueCatApiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: 'appl_HRXqLWNhneveCEBKZdSgczigiGk',
);

enum SubscriptionPlan { none, single, bundle4, all, trial }

class SubscriptionService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Configure RevenueCat. Call this once in main() before runApp().
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

  /// Identify user with RevenueCat after they sign in.
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

  /// Silently sync entitlements on app launch / sign-in.
  /// Fixes the race condition where a purchase made on Device A
  /// hasn't yet propagated to Firestore when the user opens Device B.
  /// Returns true if the user has any active entitlement.
  static Future<bool> syncEntitlementsOnLaunch() async {
    if (kIsWeb) return false;
    if (_uid == null) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      final hasActive = info.entitlements.active.isNotEmpty;
      if (hasActive) {
        // Sync to Firestore but DON'T mark hasUsedTrial — this is a
        // background sync, not a fresh purchase or trial start.
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

  /// Fetch available packages from RevenueCat.
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

  /// Purchase a package.
  /// Returns true on success, false if user cancelled.
  /// Throws a user-facing message string on actual error.
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
        productId: package.storeProduct.identifier,
        courseId: courseId,
        selectedCourseIds: selectedCourseIds,
        // A successful purchase is not the same as starting a trial.
        // Trial usage is tracked separately by startTrial().
        markTrialUsed: false,
      );
      return true;
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('cancel') || err.contains('usercancel')) {
        debugPrint('RevenueCat: user cancelled purchase');
        return false;
      }
      if (err.contains('alreadypurchased') || err.contains('already')) {
        debugPrint('RevenueCat: already purchased, restoring');
        await restore();
        return true;
      }
      debugPrint('RevenueCat purchase error: $e');
      throw 'Purchase failed. Please try again or restore purchases.';
    }
  }

  /// Restore previously purchased non-consumables.
  /// Returns true if the user has any active entitlement after restore.
  static Future<bool> restore() async {
    if (kIsWeb) return false;
    try {
      debugPrint('RevenueCat: restoring purchases');
      final info = await Purchases.restorePurchases();
      // Restore is a sync, not a new purchase — never mark trial used.
      await _syncToFirestore(info, markTrialUsed: false);
      final hasActive = info.entitlements.active.isNotEmpty;
      debugPrint('RevenueCat: restore complete, hasActive=$hasActive');
      return hasActive;
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Trial (kept for future use — not used in v1.0 launch)
  // ─────────────────────────────────────────────────────────────────────────

  /// Start a 7-day free trial for a specific course.
  /// One trial per user lifetime — call hasUsedTrial() to gate the UI.
  /// Returns true if trial was started, false if user already used theirs.
  ///
  /// NOTE: Not used in v1.0 launch (we use "first module free" instead).
  /// Kept here for potential future use.
  static Future<bool> startTrial(String courseId) async {
    final uid = _uid;
    if (uid == null) return false;

    return _db.runTransaction<bool>((tx) async {
      final ref = _db.collection('users').doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};

      if (data['hasUsedTrial'] == true) {
        debugPrint('startTrial: user $uid already used trial');
        return false;
      }

      final expiry = DateTime.now().add(const Duration(days: 7));
      tx.set(
        ref,
        {
          'trialCourseId': courseId,
          'trialExpiry': Timestamp.fromDate(expiry),
          'hasUsedTrial': true,
          'trialStartedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint('startTrial: trial granted for course $courseId until $expiry');
      return true;
    });
  }

  /// Whether the user has already consumed their one free trial.
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

  /// Whether the user is currently inside an active trial period.
  static Future<bool> isInActiveTrial() async {
    if (kIsWeb) return false;
    try {
      final uid = _uid;
      if (uid == null) return false;
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final expiry = data['trialExpiry'] as Timestamp?;
      if (expiry == null) return false;
      return expiry.toDate().isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Access Checks
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether the user can access a specific course.
  /// Checks (in order): all-bundle, 4-bundle, single, active trial.
  static Future<bool> canAccessCourse(String courseId) async {
    if (kIsWeb) return true;
    try {
      final info = await Purchases.getCustomerInfo();
      final plan = _planFromInfo(info);
      debugPrint('canAccessCourse($courseId): plan=$plan');

      if (plan == SubscriptionPlan.all) return true;

      final uid = _uid;
      if (uid == null) return false;

      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? {};

      if (plan == SubscriptionPlan.bundle4) {
        final List<dynamic> courses =
            (data['bundleCourseIds'] as List<dynamic>?) ?? [];
        return courses.contains(courseId);
      }

      if (plan == SubscriptionPlan.single) {
        return data['subscribedCourseId'] == courseId;
      }

      // Trial check
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

  /// Whether the user can access a specific module of a course.
  ///
  /// Free preview: the FIRST module of every course (`module-01`) is always
  /// accessible to everyone, even users who haven't purchased anything.
  /// This lets users try a full lesson before deciding to buy.
  ///
  /// For all other modules, falls back to the regular course access check
  /// (which considers single-course purchase, bundle, all-courses, etc.).
  static Future<bool> canAccessModule({
    required String courseId,
    required String moduleId,
  }) async {
    // First module of every course is always free — preview access.
    if (moduleId == 'module-01') return true;

    // Otherwise, check normal course/bundle/all-courses access.
    return canAccessCourse(courseId);
  }

  /// Get the current plan from RevenueCat (authoritative source).
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

  /// Real-time stream of the user's plan from Firestore.
  /// For UI updates that should react to purchase/restore.
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

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Determine the user's plan from their active RevenueCat entitlement.
  /// Since all products share one entitlement, we use the product
  /// identifier on the active entitlement to distinguish tier.
  static SubscriptionPlan _planFromInfo(CustomerInfo info) {
    final active = info.entitlements.active;
    debugPrint('RC active entitlements: ${active.keys.toList()}');

    if (!active.containsKey(kEntitlementPro)) return SubscriptionPlan.none;

    final productId = active[kEntitlementPro]?.productIdentifier ?? '';
    debugPrint('RC active product: $productId');

    if (productId == kProductBundleAll) return SubscriptionPlan.all;
    if (productId == kProductBundle4) return SubscriptionPlan.bundle4;
    if (productId == kProductSingle) return SubscriptionPlan.single;

    // Entitlement active but product unrecognised — fail safe to single
    return SubscriptionPlan.single;
  }

  /// Sync purchase / entitlement state to Firestore.
  ///
  /// [markTrialUsed] is intentionally false by default. The trial
  /// consumption flag should ONLY be set by [startTrial], not by
  /// passive syncs (restore, app-launch resync, post-purchase update).
  /// This prevents users from being locked out of trials they never used.
  static Future<void> _syncToFirestore(
    CustomerInfo info, {
    String? productId,
    String? courseId,
    List<String>? selectedCourseIds,
    bool markTrialUsed = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final resolvedProductId = productId ??
        info.entitlements.active[kEntitlementPro]?.productIdentifier ??
        '';

    SubscriptionPlan plan;
    if (resolvedProductId == kProductBundleAll) {
      plan = SubscriptionPlan.all;
    } else if (resolvedProductId == kProductBundle4) {
      plan = SubscriptionPlan.bundle4;
    } else if (resolvedProductId == kProductSingle) {
      plan = SubscriptionPlan.single;
    } else {
      plan = _planFromInfo(info);
    }

    final planString = {
      SubscriptionPlan.all: 'all',
      SubscriptionPlan.bundle4: 'bundle4',
      SubscriptionPlan.single: 'single',
      SubscriptionPlan.none: 'none',
      SubscriptionPlan.trial: 'trial',
    }[plan]!;

    final Map<String, dynamic> update = {
      'subscriptionPlan': planString,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
    };

    if (markTrialUsed) {
      update['hasUsedTrial'] = true;
    }

    if (plan == SubscriptionPlan.single && courseId != null) {
      update['subscribedCourseId'] = courseId;
    }

    if (plan == SubscriptionPlan.bundle4 && selectedCourseIds != null) {
      update['bundleCourseIds'] = selectedCourseIds;
    }

    await _db
        .collection('users')
        .doc(uid)
        .set(update, SetOptions(merge: true));
    debugPrint('Synced plan "$planString" to Firestore for $uid');
  }
}