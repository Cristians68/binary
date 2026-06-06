import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'subscription_service.dart';
import 'app_theme.dart';

// ── All available courses the user can pick from in a bundle-4 plan ──────────
const List<Map<String, String>> _kAllCourses = [
  {'id': 'itil-v4',           'title': 'ITIL V4 Foundation'},
  {'id': 'csm',               'title': 'CSM Fundamentals'},
  {'id': 'binary-network-pro','title': 'Binary Network Pro'},
  {'id': 'binary-cyber-pro',  'title': 'Binary Cyber Pro'},
  {'id': 'binary-cloud',      'title': 'Binary Cloud'},
  {'id': 'binary-cloud-pro',  'title': 'Binary Cloud Pro'},
];

class PaywallScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final Color  courseColor;
  /// When true, the All Courses plan is pre-selected instead of Single.
  /// Use this when opening the paywall from a generic "Plans & Pricing" entry
  /// rather than from a specific locked course.
  final bool defaultToAllPlans;

  const PaywallScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.courseColor,
    this.defaultToAllPlans = false,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { single, bundle4, all }

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages    = [];
  bool          _loading     = true;
  bool          _loadError   = false;
  bool          _purchasing  = false;
  late _Plan    _selected;

  // Bundle-4: the courses the user has selected (max 4).
  // Pre-seed with the course they came from so it is already ticked.
  late Set<String> _bundle4Selection;

  @override
  void initState() {
    super.initState();
    _selected = widget.defaultToAllPlans ? _Plan.all : _Plan.single;
    _bundle4Selection = {widget.courseId};
    _loadPackages();
  }

  Package? _packageFor(_Plan plan) {
    final id = {
      _Plan.single:  kProductSingle,
      _Plan.bundle4: kProductBundle4,
      _Plan.all:     kProductBundleAll,
    }[plan]!;
    try {
      return _packages.firstWhere((p) => p.storeProduct.identifier == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPackages() async {
    setState(() { _loading = true; _loadError = false; });
    final packages = await SubscriptionService.getPackages();
    if (mounted) {
      setState(() {
        _packages  = packages;
        _loading   = false;
        _loadError = packages.isEmpty;
      });
    }
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  Future<void> _purchase() async {
    if (_purchasing) return;

    if (_packages.isEmpty) {
      _showError('Products are still loading. Please wait a moment and try again.');
      return;
    }

    // Bundle-4 validation: user must pick exactly 4 courses before buying.
    if (_selected == _Plan.bundle4 && _bundle4Selection.length != 4) {
      _showError(
        'Please select exactly 4 courses before purchasing the bundle.\n\n'
        'You have selected ${_bundle4Selection.length} so far.',
      );
      return;
    }

    final package = _packageFor(_selected);
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
        // Single: pass the course the user arrived from.
        courseId: _selected == _Plan.single ? widget.courseId : null,
        // Bundle-4: pass the set of chosen courses as a list.
        selectedCourseIds: _selected == _Plan.bundle4
            ? _bundle4Selection.toList()
            : null,
      );

      if (success && mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

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
      if (mounted) _showError('Could not restore purchases. Please try again.');
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

  Future<void> _openUrl(String url) async {
    HapticFeedback.selectionClick();
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open $url: $e');
    }
  }

  // ── Labels ────────────────────────────────────────────────────────────────

  String get _ctaLabel {
    if (_purchasing) return 'Processing…';
    switch (_selected) {
      case _Plan.single:  return 'Unlock for \$14.99';
      case _Plan.bundle4: return _bundle4Selection.length == 4
          ? 'Unlock 4 Courses · \$49.99'
          : 'Select ${4 - _bundle4Selection.length} more course${4 - _bundle4Selection.length == 1 ? '' : 's'}';
      case _Plan.all:     return 'Unlock Everything · \$99.99';
    }
  }

  String get _planNotice {
    switch (_selected) {
      case _Plan.single:
        return 'One-time payment of \$14.99. Lifetime access to this course.';
      case _Plan.bundle4:
        return 'One-time payment of \$49.99. Choose any 4 courses. Yours forever.';
      case _Plan.all:
        return 'One-time payment of \$99.99. Every course + all future content. Yours forever.';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                    color: widget.courseColor, strokeWidth: 2))
            : _loadError
                ? _buildErrorState(theme)
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCloseButton(theme),
                              const SizedBox(height: 24),
                              _buildHeroSection(theme),
                              const SizedBox(height: 28),
                              _buildFeatureList(theme),
                              const SizedBox(height: 28),
                              _buildPlanSection(theme),
                              // Bundle-4 course picker — only shown when
                              // the bundle4 plan is selected.
                              if (_selected == _Plan.bundle4) ...[
                                const SizedBox(height: 20),
                                _buildBundle4Picker(theme),
                              ],
                              const SizedBox(height: 20),
                              _buildNoticeBox(theme),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      _buildCta(theme),
                    ],
                  ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _buildCloseButton(ThemeNotifier theme) {
    return Align(
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
          child: Icon(CupertinoIcons.xmark, size: 14, color: theme.subtext),
        ),
      ),
    );
  }

  Widget _buildHeroSection(ThemeNotifier theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: widget.courseColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(CupertinoIcons.lock_open_fill,
              color: widget.courseColor, size: 32),
        ),
        const SizedBox(height: 20),
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
          style: TextStyle(fontSize: 15, color: theme.subtext, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildFeatureList(ThemeNotifier theme) {
    const features = [
      'Flashcard lessons for every module',
      'Quizzes after every module',
      'Track streaks, badges & scores',
      'Certification-focused content',
      'Lifetime access — no subscription',
    ];
    return Column(
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.checkmark_circle_fill,
                        size: 18, color: AppColors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(f,
                          style: TextStyle(
                              fontSize: 14,
                              color: theme.text,
                              letterSpacing: -0.2)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildPlanSection(ThemeNotifier theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE YOUR PLAN',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.subtext,
              letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        _buildPlanTile(
          plan: _Plan.single,
          title: widget.courseTitle,
          subtitle: '1 course · One-time purchase',
          price: '\$14.99',
          badge: 'STARTER',
          badgeColor: AppColors.green,
          color: widget.courseColor,
          theme: theme,
          unavailable: _packageFor(_Plan.single) == null,
        ),
        const SizedBox(height: 10),
        _buildPlanTile(
          plan: _Plan.bundle4,
          title: 'Any 4 Courses',
          subtitle: 'Pick any 4 courses · One-time',
          price: '\$49.99',
          badge: 'SAVE \$10',
          badgeColor: AppColors.amber,
          color: AppColors.amber,
          theme: theme,
          unavailable: _packageFor(_Plan.bundle4) == null,
        ),
        const SizedBox(height: 10),
        _buildPlanTile(
          plan: _Plan.all,
          title: 'Everything',
          subtitle: 'All courses + future content · One-time',
          price: '\$99.99',
          badge: 'BEST VALUE',
          badgeColor: AppColors.primary,
          color: AppColors.primary,
          theme: theme,
          unavailable: _packageFor(_Plan.all) == null,
        ),
      ],
    );
  }

  /// Course picker shown when bundle-4 plan is selected.
  /// The course the user arrived from is pre-ticked and cannot be removed.
  Widget _buildBundle4Picker(ThemeNotifier theme) {
    final remaining = 4 - _bundle4Selection.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SELECT YOUR 4 COURSES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.subtext,
                  letterSpacing: 1.2),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: remaining == 0
                    ? AppColors.green.withValues(alpha: 0.12)
                    : AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                remaining == 0
                    ? '4 / 4 selected ✓'
                    : '$remaining more to pick',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: remaining == 0 ? AppColors.green : AppColors.amber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._kAllCourses.map((course) {
          final id        = course['id']!;
          final title     = course['title']!;
          final isLocked  = id == widget.courseId; // pre-selected, can't deselect
          final isChecked = _bundle4Selection.contains(id);
          final canSelect = !isChecked && _bundle4Selection.length < 4;

          return GestureDetector(
            onTap: () {
              if (isLocked) return; // can't deselect the originating course
              HapticFeedback.selectionClick();
              setState(() {
                if (isChecked) {
                  _bundle4Selection.remove(id);
                } else if (canSelect) {
                  _bundle4Selection.add(id);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: isChecked
                    ? AppColors.amber.withValues(alpha: 0.08)
                    : theme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isChecked
                      ? AppColors.amber.withValues(alpha: 0.35)
                      : theme.border,
                  width: isChecked ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isChecked ? AppColors.amber : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isChecked ? AppColors.amber : theme.subtext,
                        width: 2,
                      ),
                    ),
                    child: isChecked
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isChecked
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isChecked ? theme.text : theme.subtext,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  // Lock badge for the pre-selected course
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'INCLUDED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amber,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNoticeBox(ThemeNotifier theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.courseColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.courseColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.checkmark_seal_fill,
              size: 18, color: widget.courseColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_planNotice,
                style: TextStyle(
                    fontSize: 12, color: theme.subtext, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildCta(ThemeNotifier theme) {
    // CTA is disabled when bundle-4 is selected but fewer than 4 chosen.
    final bundle4Incomplete =
        _selected == _Plan.bundle4 && _bundle4Selection.length < 4;
    final ctaColor = bundle4Incomplete
        ? widget.courseColor.withValues(alpha: 0.4)
        : widget.courseColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: (_purchasing || bundle4Incomplete) ? null : _purchase,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: _purchasing
                    ? widget.courseColor.withValues(alpha: 0.5)
                    : ctaColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _purchasing
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openUrl('https://binaryapp.org/terms'),
                child: Text('Terms of Service',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.subtext,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.subtext.withValues(alpha: 0.5))),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('·',
                    style: TextStyle(fontSize: 11, color: theme.subtext)),
              ),
              GestureDetector(
                onTap: () => _openUrl('https://binaryapp.org/privacy'),
                child: Text('Privacy Policy',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.subtext,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.subtext.withValues(alpha: 0.5))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Payment processed by Apple. All sales final.\nContact support for refund requests.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
                color: theme.subtext.withValues(alpha: 0.6),
                height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState(ThemeNotifier theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.wifi_exclamationmark,
                size: 48, color: theme.subtext),
            const SizedBox(height: 20),
            Text('Could not load products',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                    letterSpacing: -0.4)),
            const SizedBox(height: 8),
            Text('Check your internet connection\nand try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: theme.subtext, height: 1.5)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loadPackages,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.courseColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Plan tile ─────────────────────────────────────────────────────────────

  Widget _buildPlanTile({
    required _Plan      plan,
    required String     title,
    required String     subtitle,
    required String     price,
    required String     badge,
    required Color      badgeColor,
    required Color      color,
    required ThemeNotifier theme,
    required bool       unavailable,
  }) {
    final selected        = _selected == plan;
    final effectiveColor  = unavailable ? theme.subtext : color;

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
              ? effectiveColor.withValues(alpha: theme.isDark ? 0.12 : 0.06)
              : theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? effectiveColor.withValues(alpha: 0.5)
                : theme.border,
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
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: unavailable ? theme.subtext : theme.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
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
                              letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: theme.subtext)),
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