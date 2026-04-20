import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'subscription_service.dart';
import 'app_theme.dart';

class PaywallScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final Color courseColor;

  const PaywallScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseColor,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { single, bundle4, all }

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];
  bool _loading = true;
  bool _loadError = false; // NEW: surface load failures to the user
  bool _purchasing = false;
  _Plan _selected = _Plan.single;

  // ── Find the right package for the selected plan ──────────────────────────
  Package? _packageFor(_Plan plan) {
    final id = {
      _Plan.single: kProductSingle,
      _Plan.bundle4: kProductBundle4,
      _Plan.all: kProductBundleAll,
    }[plan]!;

    try {
      return _packages.firstWhere(
        (p) => p.storeProduct.identifier == id,
      );
    } catch (_) {
      // Product ID not found — do NOT silently fall back to another product.
      // Return null so the UI can show a clear error.
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  // ── Load packages with retry ──────────────────────────────────────────────
  Future<void> _loadPackages() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    final packages = await SubscriptionService.getPackages();
    if (mounted) {
      setState(() {
        _packages = packages;
        _loading = false;
        // If RC returned nothing, surface the error so user can retry.
        _loadError = packages.isEmpty;
      });
    }
  }

  // ── Purchase flow ─────────────────────────────────────────────────────────
  Future<void> _purchase() async {
    if (_purchasing) return;

    // Guard: packages not loaded.
    if (_packages.isEmpty) {
      _showError(
          'Products are still loading. Please wait a moment and try again.');
      return;
    }

    final package = _packageFor(_selected);

    // Guard: specific product not found in RevenueCat offerings.
    if (package == null) {
      _showError(
        'This product is not available right now. '
        'Please check your App Store connection and try again.',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _purchasing = true);

    try {
      final success = await SubscriptionService.purchase(
        package,
        courseId: _selected == _Plan.single ? widget.courseId : null,
        // bundle4: selectedCourseIds is null here because the user picks
        // courses after purchase (or on the courses screen). The entitlement
        // is what actually gates access. You can wire up a course-picker
        // sheet here if you want to collect selection at purchase time.
        selectedCourseIds: null,
      );

      if (success && mounted) {
        // Briefly show success haptic before popping.
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      // purchase() throws a clean String for user-facing errors.
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  // ── Restore purchases ─────────────────────────────────────────────────────
  Future<void> _restore() async {
    if (_purchasing) return;
    HapticFeedback.selectionClick();
    setState(() => _purchasing = true);

    try {
      final restored = await SubscriptionService.restore();
      if (!mounted) return;
      if (restored) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      } else {
        _showError(
          'No previous purchases found for this Apple ID. '
          'If you believe this is an error, contact support.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showError('Could not restore purchases. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Something went wrong'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String get _ctaLabel {
    if (_purchasing) return 'Processing…';
    switch (_selected) {
      case _Plan.single:
        return 'Start 7-Day Free Trial';
      case _Plan.bundle4:
        return 'Buy Now · \$99.99';
      case _Plan.all:
        return 'Buy Now · \$149.99';
    }
  }

  String get _trialNotice {
    switch (_selected) {
      case _Plan.single:
        return '7 days free, then \$14.99 one-time. Yours forever.';
      case _Plan.bundle4:
        return 'One-time payment. Choose any 4 courses. Yours forever.';
      case _Plan.all:
        return 'One-time payment. Every course + all future content. Yours forever.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: widget.courseColor,
                  strokeWidth: 2,
                ),
              )
            // ── Load error state with retry button ───────────────────────
            : _loadError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.wifi_exclamationmark,
                            size: 48,
                            color: theme.subtext,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Could not load products',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.text,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check your internet connection\nand try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.subtext,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: _loadPackages,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: widget.courseColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // ── Normal paywall ────────────────────────────────────────
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Close
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context, false),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: theme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: theme.border),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      size: 14,
                                      color: theme.subtext,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Hero icon
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: widget.courseColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  CupertinoIcons.lock_open_fill,
                                  color: widget.courseColor,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Headline
                              Text(
                                'Unlock ${widget.courseTitle}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: theme.text,
                                  letterSpacing: -0.8,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'One-time payment. Learn at your own pace.\nKeep access forever.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.subtext,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Feature list
                              ...[
                                'Flashcard lessons for every module',
                                'Quizzes after every module',
                                'Track streaks, badges & scores',
                                'Certification-focused content',
                                'Lifetime access — no subscription',
                              ].map(
                                (f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.checkmark_circle_fill,
                                        size: 18,
                                        color: AppColors.green,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          f,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: theme.text,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Plan selector
                              Text(
                                'CHOOSE YOUR PLAN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.subtext,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),

                              _buildPlanTile(
                                plan: _Plan.single,
                                title: widget.courseTitle,
                                subtitle: '1 course · 7-day free trial',
                                price: '\$14.99',
                                badge: 'FREE TRIAL',
                                badgeColor: AppColors.green,
                                color: widget.courseColor,
                                theme: theme,
                                // Warn if not loaded from RC
                                unavailable: _packageFor(_Plan.single) == null,
                              ),
                              const SizedBox(height: 10),

                              _buildPlanTile(
                                plan: _Plan.bundle4,
                                title: 'Any 4 Courses',
                                subtitle: 'Pick any 4 courses · one-time',
                                price: '\$99.99',
                                badge: 'SAVE 58%',
                                badgeColor: AppColors.amber,
                                color: AppColors.amber,
                                theme: theme,
                                unavailable: _packageFor(_Plan.bundle4) == null,
                              ),
                              const SizedBox(height: 10),

                              _buildPlanTile(
                                plan: _Plan.all,
                                title: 'Everything',
                                subtitle:
                                    'All courses + future content · one-time',
                                price: '\$149.99',
                                badge: 'BEST VALUE',
                                badgeColor: AppColors.primary,
                                color: AppColors.primary,
                                theme: theme,
                                unavailable: _packageFor(_Plan.all) == null,
                              ),
                              const SizedBox(height: 24),

                              // Notice box
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: widget.courseColor.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: widget.courseColor.withOpacity(0.18),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _selected == _Plan.single
                                          ? CupertinoIcons.gift_fill
                                          : CupertinoIcons.checkmark_seal_fill,
                                      size: 18,
                                      color: widget.courseColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _trialNotice,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.subtext,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),

                      // ── CTA ────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _purchasing ? null : _purchase,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 17),
                                decoration: BoxDecoration(
                                  color: _purchasing
                                      ? widget.courseColor.withOpacity(0.5)
                                      : widget.courseColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: _purchasing
                                    ? const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _ctaLabel,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: _purchasing ? null : _restore,
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
                            const SizedBox(height: 8),
                            Text(
                              'Payment processed by Apple. All sales final.\nContact support for refund requests.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.subtext.withOpacity(0.6),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPlanTile({
    required _Plan plan,
    required String title,
    required String subtitle,
    required String price,
    required String badge,
    required Color badgeColor,
    required Color color,
    required ThemeNotifier theme,
    required bool unavailable, // grayed out if RC didn't return this product
  }) {
    final selected = _selected == plan;
    final effectiveColor = unavailable ? theme.subtext : color;

    return GestureDetector(
      onTap: unavailable
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _selected = plan);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? effectiveColor.withOpacity(theme.isDark ? 0.12 : 0.06)
              : theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? effectiveColor.withOpacity(0.5) : theme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? effectiveColor : Colors.transparent,
                border: Border.all(
                  color: selected ? effectiveColor : theme.subtext,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: unavailable ? theme.subtext : theme.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: unavailable ? theme.border : badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          unavailable ? 'UNAVAILABLE' : badge,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: theme.subtext),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? effectiveColor : theme.subtext,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
