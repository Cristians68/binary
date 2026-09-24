import 'package:flutter/material.dart';
import 'app_router.dart';
import 'subscription_service.dart';
import 'paywall_screen.dart';

/// Wraps navigation into a course with an access check.
///
/// Usage:
///   SubscriptionGate.enter(
///     context,
///     courseId: 'binary-network-professional',
///     courseTitle: 'Network Professional',
///     courseColor: Colors.blue,
///     onGranted: () => Navigator.push(context, AppRouter.push(CourseDetailScreen(...))),
///   );
class SubscriptionGate {
  static Future<void> enter({
    required BuildContext context,
    required String courseId,
    required String courseTitle,
    required Color courseColor,
    required VoidCallback onGranted,
  }) async {
    final canAccess = await SubscriptionService.canAccessCourse(courseId);

    if (canAccess) {
      onGranted();
      return;
    }

    if (!context.mounted) return;

    final result = await Navigator.push<bool>(
      context,
      // Swipe back from the left edge like every other screen; a swipe
      // returns null, which is "not purchased" below.
      AppRouter.push<bool>(PaywallScreen(
        courseId: courseId,
        courseTitle: courseTitle,
        courseColor: courseColor,
      )),
    );

    if (result == true && context.mounted) {
      onGranted();
    }
  }
}