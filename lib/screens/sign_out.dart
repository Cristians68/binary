import 'package:flutter/material.dart';

import 'app_router.dart';
import 'auth_service.dart';
import 'welcome_screen.dart';

Future<void> signOutToWelcome(BuildContext context) async {
  try {
    // AuthService awaits listener cancellation before clearing credentials.
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      AppRouter.fade(const WelcomeScreen()),
      (route) => false,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not sign out. Please try again.')),
    );
  }
}
