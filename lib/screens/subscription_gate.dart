import 'package:flutter/material.dart';
import 'subscription_service.dart';
import 'paywall_screen.dart';

/// Wraps navigation into a course with an access check.
///
/// Usage:
///   SubscriptionGate.enter(
///     context,
///     courseId: 'binary-network-pro',
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
    final canAccess = false; // TEMP: force paywall for screenshots

    if (canAccess) {
      onGranted();
      return;
    }

    if (!context.mounted) return;

    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => PaywallScreen(
          courseId: courseId,
          courseTitle: courseTitle,
          courseColor: courseColor,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (result == true && context.mounted) {
      onGranted();
    }
  }
}
