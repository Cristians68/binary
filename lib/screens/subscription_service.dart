import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'purchase_coordinator.dart';
import 'restore_result.dart';
import 'service_backend.dart';

export 'purchase_coordinator.dart'
    show kProductSingle, kProductBundle4, kProductBundleAll;

const String kEntitlementPro = 'B1nary Academy Pro';
const String kRevenueCatApiKey = String.fromEnvironment(
  'REVENUECAT_API_KEY',
  defaultValue: 'appl_HRXqLWNhneveCEBKZdSgczigiGk',
);

enum SubscriptionPlan { none, single, bundle4, all, trial }

class SubscriptionService {
  static FirebaseFirestore get _db => ServiceBackend.db;
  static String? get _uid => ServiceBackend.uid;
  static FirebaseFunctions get _fn => FirebaseFunctions.instance;

  static Future<void> configure() async {
    if (kIsWeb) return;
    try {
      await Purchases.setLogLevel(
          kReleaseMode ? LogLevel.warn : LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(kRevenueCatApiKey));
      await identifyUser();
    } catch (e) {
      debugPrint('RevenueCat configure failed: $e');
    }
  }

  static Future<void> identifyUser() async {
    if (kIsWeb) return;
    try {
      final uid = _uid;
      if (uid != null) await Purchases.logIn(uid);
    } catch (e) {
      debugPrint('RevenueCat identifyUser failed: $e');
    }
  }

  static Future<Map<String, dynamic>> _refreshEntitlement() async {
    final result = await _fn
        .httpsCallable(
          'refreshEntitlement',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<Map<String, dynamic>>();
    return result.data;
  }

  /// A server lookup repairs missing webhooks without silently initiating a
  /// store restore, which may transfer a receipt or show an Apple ID prompt.
  static Future<bool> syncEntitlementsOnLaunch() async {
    if (kIsWeb || _uid == null) return false;
    final uid = _uid;
    try {
      final state = await _refreshEntitlement();
      return _uid == uid && _hasPaidAccess(state);
    } catch (e) {
      debugPrint('syncEntitlementsOnLaunch failed: $e');
      return false;
    }
  }

  static Future<List<Package>> getPackages() async {
    if (kIsWeb) return [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('RevenueCat getPackages failed: $e');
      return [];
    }
  }

  static PurchaseCoordinator get _coordinator => PurchaseCoordinator(
        currentUid: () => _uid,
        identify: (uid) async {
          await Purchases.logIn(uid);
        },
        prepare: (request) async {
          try {
            final result = await _fn
                .httpsCallable(
                  'setPendingPurchase',
                  options: HttpsCallableOptions(
                      timeout: const Duration(seconds: 15)),
                )
                .call<Map<String, dynamic>>(request.payload);
            // An older function only returned {ok:true}; it cannot guarantee that
            // verification works. Never open StoreKit against that server version.
            if (result.data['ok'] != true ||
                result.data['alreadyOwned'] is! bool) {
              throw const PurchaseFailure(
                  'Purchases are temporarily unavailable. No payment was started.');
            }
            return result.data['alreadyOwned'] == true;
          } on FirebaseFunctionsException catch (e) {
            if (e.code == 'failed-precondition' && e.message != null) {
              throw PurchaseFailure('${e.message} No payment was started.');
            }
            rethrow;
          }
        },
        refresh: _refreshEntitlement,
        readAccount: (uid) async =>
            (await _db
                    .collection('users')
                    .doc(uid)
                    .get(const GetOptions(source: Source.server)))
                .data() ??
            {},
      );

  static Future<bool> purchase(
    Package package, {
    String? courseId,
    List<String>? selectedCourseIds,
  }) async {
    if (kIsWeb) return false;
    final request = PurchaseRequest(
      productId: package.storeProduct.identifier,
      courseId: courseId,
      selectedCourseIds: selectedCourseIds,
    );
    try {
      return await _coordinator.purchase(request, () async {
        await Purchases.purchase(PurchaseParams.package(package));
      });
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        final result = await restore();
        // Owning a different course must not dismiss this paywall as success.
        final uid = _uid;
        if (result.isApplied && uid != null) {
          final data = await _coordinator.readAccount(uid);
          if (_uid == uid && request.isApplied(data)) return true;
        }
        throw PurchaseFailure(result.isApplied
            ? 'Your previous purchases were restored. This selection is not included in them.'
            : result.displayMessage);
      }
      if (code == PurchasesErrorCode.paymentPendingError) {
        throw const PurchaseFailure(
            'Your payment is awaiting approval. Once approved, restore purchases to activate your courses.');
      }
      throw const PurchaseFailure(
          'The App Store could not complete your purchase. Please try again or restore purchases.');
    }
  }

  static Future<RestoreResult> restore() async {
    if (kIsWeb) {
      return const RestoreResult.failed(
          message: 'Purchases can only be restored in the iOS app.');
    }
    return _coordinator.restore(() async {
      final info = await Purchases.restorePurchases();
      return info.allPurchasedProductIdentifiers.any(isKnownPurchaseProduct);
    });
  }

  static bool planGrantsAccess(Map<String, dynamic> data, String courseId) =>
      paidCourseAccess(data, courseId);

  static Future<bool> canAccessCourse(String courseId,
      {bool cachedOnly = false}) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final snap = await _db.collection('users').doc(uid).get(GetOptions(
          source: cachedOnly ? Source.cache : Source.serverAndCache));
      if (_uid != uid) return false;
      final data = snap.data() ?? {};
      if (planGrantsAccess(data, courseId)) return true;
      final expiry = data['trialExpiry'];
      if (data['trialCourseId'] == courseId &&
          expiry is Timestamp &&
          expiry.toDate().isAfter(DateTime.now())) {
        return true;
      }
      // Launch and explicit purchase/restore reconcile access. Reading a
      // locked lesson must not launch a StoreKit restore behind the user's back.
      return false;
    } catch (e) {
      debugPrint('canAccessCourse error: $e');
      return false;
    }
  }

  static bool isFreePreviewModule(String moduleId) =>
      moduleId == 'module-1' || moduleId == 'module-01';

  static Future<bool> canAccessModule({
    required String courseId,
    required String moduleId,
    bool cachedOnly = false,
  }) async {
    if (isFreePreviewModule(moduleId)) return true;
    return canAccessCourse(courseId, cachedOnly: cachedOnly);
  }

  static SubscriptionPlan _plan(Map<String, dynamic> data) =>
      switch (data['subscriptionPlan']) {
        'all' => SubscriptionPlan.all,
        'bundle4' => SubscriptionPlan.bundle4,
        'single' => SubscriptionPlan.single,
        _ => SubscriptionPlan.none,
      };

  static bool _hasPaidAccess(Map<String, dynamic> data) =>
      data['subscriptionPlan'] == 'all' ||
      (data['purchasedCourseIds'] is List &&
          (data['purchasedCourseIds'] as List).isNotEmpty);

  static Future<SubscriptionPlan> getCurrentPlan() async {
    final uid = _uid;
    if (uid == null) return SubscriptionPlan.none;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      return _uid == uid ? _plan(snap.data() ?? {}) : SubscriptionPlan.none;
    } catch (_) {
      return SubscriptionPlan.none;
    }
  }

  static Stream<SubscriptionPlan> planStream() {
    if (_uid == null) return const Stream.empty();
    return ServiceBackend.watchUser().map((snap) => _plan(snap.data() ?? {}));
  }

  static Future<bool> startTrial(String courseId) async {
    if (_uid == null) return false;
    try {
      final res = await _fn
          .httpsCallable('startTrial')
          .call<Map<String, dynamic>>({'courseId': courseId});
      return res.data['granted'] == true;
    } catch (e) {
      debugPrint('startTrial failed: $e');
      return false;
    }
  }

  static Future<bool> hasUsedTrial() async {
    try {
      final uid = _uid;
      if (uid == null) return false;
      final snap = await _db.collection('users').doc(uid).get();
      return _uid == uid && snap.data()?['hasUsedTrial'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isInActiveTrial() async {
    try {
      final uid = _uid;
      if (uid == null) return false;
      final snap = await _db.collection('users').doc(uid).get();
      final expiry = snap.data()?['trialExpiry'];
      return _uid == uid &&
          expiry is Timestamp &&
          expiry.toDate().isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}
