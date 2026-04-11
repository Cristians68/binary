import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'subscription_service.dart';
import 'app_theme.dart';

class PaywallScreen extends StatefulWidget {
  /// The course the user was trying to open — pre-selects single plan
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

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];
  bool _loading = true;
  bool _purchasing = false;
  bool _selectedAll = false; // false = single course selected by default

  Package? get _singlePackage => _packages.firstWhere(
    (p) => p.storeProduct.identifier == kSingleCourseProductId,
    orElse: () => _packages.isNotEmpty ? _packages.first : throw Exception(),
  );

  Package? get _allPackage => _packages.firstWhere(
    (p) => p.storeProduct.identifier == kAllCoursesProductId,
    orElse: () => _packages.length > 1 ? _packages.last : throw Exception(),
  );

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final packages = await SubscriptionService.getPackages();
    if (mounted) {
      setState(() {
        _packages = packages;
        _loading = false;
      });
    }
  }

  Future<void> _purchase() async {
    if (_purchasing || _packages.isEmpty) return;
    HapticFeedback.mediumImpact();

    final package = _selectedAll ? _allPackage : _singlePackage;
    if (package == null) return;

    setState(() => _purchasing = true);

    try {
      final success = await SubscriptionService.purchase(
        package,
        courseId: _selectedAll ? null : widget.courseId,
      );
      if (success && mounted) {
        Navigator.pop(context, true); // true = access granted
      }
    } catch (e) {
      if (mounted) {
        _showError('Purchase failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    HapticFeedback.selectionClick();
    setState(() => _purchasing = true);
    final restored = await SubscriptionService.restore();
    if (mounted) {
      setState(() => _purchasing = false);
      if (restored) {
        Navigator.pop(context, true);
      } else {
        _showError('No active subscription found.');
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Oops'),
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
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Close button ──────────────────────────────────
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

                          // ── Hero icon ─────────────────────────────────────
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: widget.courseColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              CupertinoIcons.lock_open_fill,
                              color: widget.courseColor,
                              size: 32,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Headline ──────────────────────────────────────
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
                            'Start your 7-day free trial today.\nCancel anytime.',
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.subtext,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Feature bullets ───────────────────────────────
                          _buildFeature(
                            icon: CupertinoIcons.checkmark_circle_fill,
                            text: 'Flashcard lessons for every module',
                            color: AppColors.green,
                            theme: theme,
                          ),
                          _buildFeature(
                            icon: CupertinoIcons.checkmark_circle_fill,
                            text: 'Quiz after every module to test knowledge',
                            color: AppColors.green,
                            theme: theme,
                          ),
                          _buildFeature(
                            icon: CupertinoIcons.checkmark_circle_fill,
                            text: 'Track streaks, badges & quiz scores',
                            color: AppColors.green,
                            theme: theme,
                          ),
                          _buildFeature(
                            icon: CupertinoIcons.checkmark_circle_fill,
                            text: 'Certification-focused content',
                            color: AppColors.green,
                            theme: theme,
                          ),

                          const SizedBox(height: 32),

                          // ── Plan selector ─────────────────────────────────
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

                          // Single course plan
                          _buildPlanTile(
                            selected: !_selectedAll,
                            title: widget.courseTitle,
                            subtitle: '1 course · billed monthly',
                            price: '\$14.99',
                            badge: null,
                            color: widget.courseColor,
                            theme: theme,
                            onTap: () => setState(() => _selectedAll = false),
                          ),

                          const SizedBox(height: 10),

                          // All courses plan
                          _buildPlanTile(
                            selected: _selectedAll,
                            title: 'All Courses',
                            subtitle: 'Every course · billed monthly',
                            price: '\$29.99',
                            badge: 'BEST VALUE',
                            color: AppColors.primary,
                            theme: theme,
                            onTap: () => setState(() => _selectedAll = true),
                          ),

                          const SizedBox(height: 24),

                          // ── Trial notice ──────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: widget.courseColor.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: widget.courseColor.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.gift_fill,
                                  size: 18,
                                  color: widget.courseColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '7 days free, then '
                                    '${_selectedAll ? '\$29.99' : '\$14.99'}'
                                    '/month. Cancel anytime in Settings.',
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

                  // ── Bottom CTA ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _purchasing ? null : _purchase,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            decoration: BoxDecoration(
                              color: _purchasing
                                  ? widget.courseColor.withValues(alpha: 0.5)
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
                                : const Text(
                                    'Start Free Trial',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
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
                          onTap: _restore,
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
                          'Subscriptions auto-renew unless cancelled 24 hours\nbefore the end of the current period.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.subtext.withValues(alpha: 0.6),
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

  Widget _buildFeature({
    required IconData icon,
    required String text,
    required Color color,
    required ThemeNotifier theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: theme.text,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTile({
    required bool selected,
    required String title,
    required String subtitle,
    required String price,
    required String? badge,
    required Color color,
    required ThemeNotifier theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: theme.isDark ? 0.12 : 0.06)
              : theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : theme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio dot
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : theme.subtext,
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
                          color: theme.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
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
                color: selected ? color : theme.subtext,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
