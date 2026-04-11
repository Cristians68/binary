import 'package:flutter/material.dart';
import 'subscription_service.dart';
import 'paywall_screen.dart';

/// Wrap any navigation call that leads into a course with this gate.
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

    // Show paywall and wait for result
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PaywallScreen(
          courseId: courseId,
          courseTitle: courseTitle,
          courseColor: courseColor,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (result == true && context.mounted) {
      onGranted();
    }
  }
}
