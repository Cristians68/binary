import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'notification_prefs.dart';
import 'notification_prefs_service.dart';
import 'notification_service.dart';

/// Asks for notification permission in our own words before the OS does.
///
/// The app used to call `requestPermissions()` unconditionally from
/// `AuthService` the moment a user signed in — before they had seen a lesson,
/// a streak, or any reason to say yes. iOS grants that prompt **once**: a user
/// who declines can never be asked again from inside the app, only from
/// Settings. Spending it on a stranger is the worst possible moment.
///
/// This screen is shown after the first completed lesson, when the user has
/// something worth protecting, and the OS prompt fires only if they opt in.
class NotificationPrimingScreen extends StatefulWidget {
  const NotificationPrimingScreen({super.key});

  @override
  State<NotificationPrimingScreen> createState() =>
      _NotificationPrimingScreenState();

  /// Show this once, after the first completed lesson.
  ///
  /// Returns immediately if it has already been shown on this install, so
  /// callers can invoke it on every lesson completion without checking.
  static Future<void> showIfNeeded(BuildContext context) async {
    if (await NotificationPrefsService.hasBeenPrimed()) return;
    if (!context.mounted) return;

    // Marked before showing, not after. A crash or a back-swipe mid-prompt
    // would otherwise re-ask on the next lesson, which is exactly the nagging
    // this screen exists to avoid.
    await NotificationPrefsService.markPrimed();
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NotificationPrimingScreen(),
      ),
    );
  }
}

class _NotificationPrimingScreenState extends State<NotificationPrimingScreen> {
  bool _busy = false;

  Future<void> _enable() async {
    HapticFeedback.selectionClick();
    setState(() => _busy = true);

    final granted = await NotificationService.requestPermissions();

    // Save either way. A denied prompt still means "this user wanted
    // reminders", so if they later enable notifications in iOS Settings the
    // reminders they chose are already scheduled and waiting.
    await NotificationPrefsService.save(const NotificationPrefs());

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reminders are off in iOS Settings. You can turn them on any time '
            'under Settings → Notifications.',
          ),
        ),
      );
    }
  }

  Future<void> _skip() async {
    HapticFeedback.selectionClick();
    // An explicit "not now" is a real preference: record it so the settings
    // sheet opens showing reminders off rather than claiming they are on.
    await NotificationPrefsService.save(
      const NotificationPrefs(master: false),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Keep your streak alive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'A single daily reminder at a time you choose. Nothing else — '
                'no marketing, and you can turn it off in Profile whenever '
                'you like.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.subtext,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _enable,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Turn on reminders',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: Text(
                  'Not now',
                  style: TextStyle(fontSize: 16, color: theme.subtext),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
