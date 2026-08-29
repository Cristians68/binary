import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  static FirebaseFunctions get _fn => FirebaseFunctions.instance;

  static Future<void> configure() async {
    if (kIsWeb) return;
    try {
      // Debug logging prints purchase payloads and the customer's entitlement
      // state into the device log. Keep it out of release builds.
      await Purchases.setLogLevel(
        kReleaseMode ? LogLevel.warn : LogLevel.debug,
      );
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
      // Read-only. Entitlements are written by the RevenueCat webhook; if the
      // store says the user has one but Firestore does not, a restore (which
      // re-triggers the webhook) is the recovery path — not a client write.
      final info = await Purchases.getCustomerInfo();
      final hasActive = info.entitlements.active.isNotEmpty;
      if (hasActive) {
        final snap = await _db.collection('users').doc(_uid).get();
        final plan = snap.data()?['subscriptionPlan'] as String? ?? 'none';
        if (plan == 'none') {
          debugPrint('Store has entitlement but Firestore does not — restoring');
          await Purchases.restorePurchases();
          await _awaitEntitlement(timeout: const Duration(seconds: 8));
        }
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
      // Record WHICH course(s) this purchase is for, before paying. The server
      // promotes this to a real entitlement only once RevenueCat confirms
      // payment via webhook — writing it here grants nothing on its own.
      await _setPendingPurchase(
        courseId: courseId,
        courseIds: selectedCourseIds,
      );

      debugPrint('RevenueCat: purchasing ${package.storeProduct.identifier}');
      await Purchases.purchase(PurchaseParams.package(package));
      debugPrint('RevenueCat: purchase success — awaiting webhook');

      // The entitlement lands in Firestore when the webhook fires. planStream()
      // is a live snapshot listener, so the UI updates on its own.
      await _awaitEntitlement();
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
      // Restoring re-associates the store receipt with this RevenueCat user,
      // which triggers a TRANSFER/RENEWAL webhook. The server writes the
      // entitlement; we just wait for it to arrive.
      final info = await Purchases.restorePurchases();
      final hasActive = info.entitlements.active.isNotEmpty;
      if (hasActive) await _awaitEntitlement();
      debugPrint('RevenueCat: restore complete — hasActive=$hasActive');
      return hasActive;
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
      return false;
    }
  }

  /// Poll Firestore briefly for the webhook-written entitlement.
  ///
  /// Webhook delivery is typically sub-second but is not synchronous with the
  /// StoreKit callback, so without this the paywall can close before the plan
  /// lands and the user sees a locked screen for a course they just bought.
  static Future<void> _awaitEntitlement({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final snap = await _db.collection('users').doc(uid).get();
        final plan = snap.data()?['subscriptionPlan'] as String? ?? 'none';
        if (plan != 'none') {
          debugPrint('_awaitEntitlement: plan="$plan" landed');
          return;
        }
      } catch (e) {
        debugPrint('_awaitEntitlement read failed: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    debugPrint('_awaitEntitlement: timed out — webhook may be delayed');
  }

  /// Tell the server which course(s) the imminent purchase is for.
  static Future<void> _setPendingPurchase({
    String? courseId,
    List<String>? courseIds,
  }) async {
    if (courseId == null && (courseIds == null || courseIds.isEmpty)) return;
    try {
      await _fn.httpsCallable('setPendingPurchase').call<void>({
        if (courseId != null) 'courseId': courseId,
        if (courseIds != null && courseIds.isNotEmpty) 'courseIds': courseIds,
      });
    } catch (e) {
      // Non-fatal: the webhook still grants the plan, it just may not know
      // which single course to attach. Surfaced in logs for support.
      debugPrint('setPendingPurchase failed: $e');
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
    // NOTE: web deliberately does NOT short-circuit to `true`. It used to,
    // which made the entire paid catalogue free on the Firebase Hosting build.
    // Web has no StoreKit, so it cannot *sell* — but it can still read the
    // entitlement the user already owns, which is all this check needs.
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
      // the entitlement webhook hasn't landed yet (e.g. reinstall, new device).
      // There is no RevenueCat SDK on web, so Firestore is final there.
      if (kIsWeb) return false;

      debugPrint(
          'canAccessCourse: Firestore has no plan — checking RevenueCat live');
      final info = await Purchases.getCustomerInfo();
      if (_planFromInfo(info) == SubscriptionPlan.none) return false;

      // The store says this user owns something Firestore hasn't recorded —
      // usually a reinstall whose webhook predates this device. Restoring
      // re-fires the webhook; the server then writes the entitlement.
      await Purchases.restorePurchases();
      await _awaitEntitlement(timeout: const Duration(seconds: 8));

      final retry = await _db.collection('users').doc(uid).get();
      return (retry.data()?['subscriptionPlan'] as String? ?? 'none') != 'none';
    } catch (e) {
      debugPrint('canAccessCourse error: $e');
      return false;
    }
  }

  /// Module IDs that are free for everyone — the course preview.
  ///
  /// Both spellings are accepted on purpose. The seed scripts write `module-1`
  /// while the in-app content and this check originally used `module-01`, so
  /// the strings never matched and NOTHING was ever free — every user hit a
  /// paywall on the first tap. Matching both is the safe fix; normalising the
  /// data can follow without re-breaking the funnel.
  static bool isFreePreviewModule(String moduleId) {
    final normalised = moduleId.replaceFirst(
      RegExp(r'^module-0*'),
      'module-',
    );
    return normalised == 'module-1';
  }

  /// Whether the user can access a specific module.
  /// The first module of every course is always free.
  static Future<bool> canAccessModule({
    required String courseId,
    required String moduleId,
  }) async {
    if (isFreePreviewModule(moduleId)) return true;
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

  /// Start the one-time free trial.
  ///
  /// This used to run as a client-side Firestore transaction, which meant the
  /// user could simply reset `hasUsedTrial` on their own document and farm
  /// unlimited trials. It is now a Cloud Function: the client can ask, but only
  /// the server can grant.
  static Future<bool> startTrial(String courseId) async {
    if (_uid == null) return false;
    try {
      final res = await _fn
          .httpsCallable('startTrial')
          .call<Map<String, dynamic>>({'courseId': courseId});
      final granted = res.data['granted'] == true;
      debugPrint('startTrial: granted=$granted for $courseId');
      return granted;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('startTrial failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('startTrial failed: $e');
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

  // _syncToFirestore was removed deliberately. Entitlement fields are now
  // written only by functions/entitlements.js (Admin SDK). If you reintroduce
  // a client-side writer here, firestore.rules will reject it — and the
  // paywall bypass it caused will come back. See docs/SECURITY.md.
}
