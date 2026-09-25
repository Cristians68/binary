import '../course_catalog.dart';
import 'restore_result.dart';

const kProductSingle = 'binary_course_single'; // Restore only.
const kProductBundle4 = 'binary_bundle_4';
const kProductBundleAll = 'binary_bundle_all';

bool isKnownPurchaseProduct(String id) =>
    id == kProductSingle ||
    id == kProductBundle4 ||
    id == kProductBundleAll ||
    kCourseCatalog.any((course) => course.productId == id);

/// Mirrors Firestore's server-enforced paid access decision.
bool paidCourseAccess(Map<String, dynamic> data, String courseId) {
  final plan = data['subscriptionPlan'];
  if (plan == 'all') return true;
  if (plan != 'single' && plan != 'bundle4') return false;
  final purchased = data['purchasedCourseIds'];
  if (purchased is List && purchased.contains(courseId)) return true;
  if (plan == 'single') return data['subscribedCourseId'] == courseId;
  final bundle = data['bundleCourseIds'];
  return bundle is List && bundle.contains(courseId);
}

class PurchaseRequest {
  PurchaseRequest({
    required this.productId,
    String? courseId,
    List<String>? selectedCourseIds,
  }) {
    if (productId == kProductBundleAll &&
        courseId == null &&
        selectedCourseIds == null) {
      courseIds = const [];
    } else if (productId == kProductBundle4 &&
        courseId == null &&
        selectedCourseIds != null &&
        selectedCourseIds.length == 4 &&
        selectedCourseIds.toSet().length == 4 &&
        selectedCourseIds
            .every((id) => kCourseCatalog.any((c) => c.id == id))) {
      courseIds = List.unmodifiable(selectedCourseIds);
    } else if (courseId != null &&
        selectedCourseIds == null &&
        kCourseCatalog
            .any((c) => c.id == courseId && c.productId == productId)) {
      courseIds = [courseId];
    } else {
      throw const PurchaseFailure(
          'Choose a valid course or four different courses for your bundle.');
    }
  }

  final String productId;
  late final List<String> courseIds;

  Map<String, dynamic> get payload => {
        'productId': productId,
        if (productId == kProductBundle4) 'courseIds': courseIds,
        if (productId != kProductBundle4 && courseIds.isNotEmpty)
          'courseId': courseIds.single,
      };

  bool isApplied(Map<String, dynamic> data) => productId == kProductBundleAll
      ? data['subscriptionPlan'] == 'all'
      : courseIds.every((id) => paidCourseAccess(data, id));
}

class PurchaseFailure implements Exception {
  const PurchaseFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Coordinates payment and activation with explicit boundaries around charging.
/// Dependencies also let tests prove that a failed preflight never opens StoreKit.
class PurchaseCoordinator {
  PurchaseCoordinator({
    required this.currentUid,
    required this.identify,
    required this.prepare,
    required this.refresh,
    required this.readAccount,
    this.attempts = 5,
    Future<void> Function()? pause,
  }) : pause = pause ??
            (() => Future<void>.delayed(const Duration(milliseconds: 600)));

  final String? Function() currentUid;
  final Future<void> Function(String uid) identify;
  final Future<bool> Function(PurchaseRequest request) prepare;
  final Future<Map<String, dynamic>> Function() refresh;
  final Future<Map<String, dynamic>> Function(String uid) readAccount;
  final Future<void> Function() pause;
  final int attempts;

  void _checkAccount(String uid) {
    if (currentUid() != uid) {
      throw const PurchaseFailure(
          'Your account changed. Sign in to the account you used for this purchase, then restore purchases.');
    }
  }

  Future<bool> purchase(
      PurchaseRequest request, Future<void> Function() buy) async {
    final uid = currentUid();
    if (uid == null) throw const PurchaseFailure('Sign in before purchasing.');
    try {
      await identify(uid);
      _checkAccount(uid);
      final alreadyOwned = await prepare(request);
      _checkAccount(uid);
      if (alreadyOwned) {
        final data = await readAccount(uid);
        _checkAccount(uid);
        if (request.isApplied(data)) return true;
        throw const PurchaseFailure(
            'Your purchase is still updating. Restore purchases before trying again.');
      }
    } on PurchaseFailure {
      rethrow;
    } catch (_) {
      throw const PurchaseFailure(
          'Purchases are temporarily unavailable. No payment was started. Please try again later.');
    }

    // Store errors/cancellations are handled by SubscriptionService. Everything
    // after this boundary must tell the customer payment has already succeeded.
    await buy();
    for (var attempt = 0; attempt < attempts; attempt++) {
      _checkAccount(uid);
      try {
        await refresh();
      } catch (_) {/* The webhook may still succeed. */}
      _checkAccount(uid);
      try {
        final data = await readAccount(uid);
        _checkAccount(uid);
        if (request.isApplied(data)) return true;
      } on PurchaseFailure {
        rethrow;
      } catch (_) {/* Retry a transient read failure. */}
      if (attempt + 1 < attempts) await pause();
    }
    throw const PurchaseFailure(
        'Payment received. Your courses are still being activated. '
        'If they remain locked, tap Restore purchases. You do not need to buy again.');
  }

  Future<RestoreResult> restore(Future<bool> Function() restoreStore) async {
    final uid = currentUid();
    if (uid == null) {
      return const RestoreResult.failed(
          message: 'Sign in before restoring purchases.');
    }
    var storeFoundPurchase = false;
    try {
      await identify(uid);
      _checkAccount(uid);
      storeFoundPurchase = await restoreStore();
      _checkAccount(uid);
      for (var attempt = 0; attempt < attempts; attempt++) {
        final state = await refresh();
        _checkAccount(uid);
        final products = state['activeProductIds'];
        if (products is! List) {
          throw const PurchaseFailure('Could not verify restored purchases.');
        }
        if (products.isEmpty) {
          if (storeFoundPurchase && attempt + 1 < attempts) {
            await pause();
            continue;
          }
          return const RestoreResult.nothing();
        }
        storeFoundPurchase = true;
        final unresolved = state['unresolvedProductIds'];
        if (unresolved is List && unresolved.isNotEmpty) {
          return const RestoreResult.pending();
        }
        final data = await readAccount(uid);
        _checkAccount(uid);
        final courses = state['purchasedCourseIds'];
        final applied = state['subscriptionPlan'] == 'all'
            ? data['subscriptionPlan'] == 'all'
            : courses is List &&
                courses.isNotEmpty &&
                courses
                    .every((id) => id is String && paidCourseAccess(data, id));
        if (applied) return const RestoreResult.applied();
        if (attempt + 1 < attempts) await pause();
      }
      return const RestoreResult.pending();
    } on PurchaseFailure catch (error) {
      return RestoreResult.failed(message: error.message);
    } catch (_) {
      return storeFoundPurchase
          ? const RestoreResult.pending()
          : const RestoreResult.failed(
              message:
                  'Could not verify your purchases. Check your connection and try again.');
    }
  }
}
