import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'subscription_service.dart';
import 'paywall_screen.dart';
import 'app_theme.dart';

/// Wrap any course screen with this widget to enforce the paywall.
///
/// Usage:
/// ```dart
/// ContentGate(
///   courseId: widget.courseId,
///   courseTitle: widget.courseTag,
///   courseColor: widget.color,
///   child: ActualCourseScreen(...),
/// )
/// ```
///
/// The child is only shown when the user has a valid entitlement.
/// Otherwise a locked screen is shown with a button to open the paywall.
class ContentGate extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final Color courseColor;
  final Widget child;

  const ContentGate({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseColor,
    required this.child,
  });

  @override
  State<ContentGate> createState() => _ContentGateState();
}

class _ContentGateState extends State<ContentGate> {
  bool _checking = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final access = await SubscriptionService.canAccessCourse(widget.courseId);
    if (mounted) {
      setState(() {
        _hasAccess = access;
        _checking = false;
      });
    }
  }

  Future<void> _openPaywall() async {
    final purchased = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => PaywallScreen(
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          courseColor: widget.courseColor,
        ),
        fullscreenDialog: true,
      ),
    );

    // Re-check access after paywall closes — handles purchase + restore.
    if (purchased == true && mounted) {
      setState(() => _checking = true);
      await _check();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      final theme = AppTheme.of(context);
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(
          child: CircularProgressIndicator(
            color: widget.courseColor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Access granted — show the actual content.
    if (_hasAccess) return widget.child;

    // Access denied — show locked state.
    return _LockedScreen(
      courseTitle: widget.courseTitle,
      courseColor: widget.courseColor,
      onUnlock: _openPaywall,
    );
  }
}

// ── Locked screen shown when user has no entitlement ─────────────────────────
class _LockedScreen extends StatelessWidget {
  final String courseTitle;
  final Color courseColor;
  final VoidCallback onUnlock;

  const _LockedScreen({
    required this.courseTitle,
    required this.courseColor,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: courseColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: courseColor.withOpacity(0.20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 12,
                          color: courseColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 13,
                            color: courseColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Lock icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: courseColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  CupertinoIcons.lock_fill,
                  color: courseColor,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                courseTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Unlock this course to access all\nlessons, quizzes, and your certificate.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.subtext,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Unlock CTA
              GestureDetector(
                onTap: onUnlock,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    color: courseColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Unlock Course',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Restore
              GestureDetector(
                onTap: () async {
                  final restored = await SubscriptionService.restore();
                  if (restored && context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  'Restore purchases',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.subtext,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.subtext,
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
