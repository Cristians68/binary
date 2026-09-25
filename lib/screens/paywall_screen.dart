import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'restore_result.dart';
import 'subscription_service.dart';
import '../app_links.dart';
import 'app_theme.dart';
import 'bundle_selection.dart';
import '../course_catalog.dart';

// ── All available courses the user can pick from in a bundle-4 plan ──────────
// Titles come from the shared catalogue so certification trademarks are never
// used as product names. See lib/course_catalog.dart.
final List<Map<String, String>> _kAllCourses = [
  for (final c in kCourseCatalog) {'id': c.id, 'title': c.title},
];

class PaywallScreen extends StatefulWidget {
  /// The course the user arrived from, or null when the paywall was opened
  /// from a generic entry point such as "Plans & Pricing" or the upgrade
  /// banner.
  ///
  /// This used to be non-nullable, and the three generic entry points each
  /// passed the literal `'itil-v4'` to satisfy it. That was not a placeholder:
  /// picking the Single plan from any of them bought IT Service Management
  /// Foundations, whatever course the user actually wanted, with no picker and
  /// nothing on screen naming what was about to be charged for. Null now means
  /// "no course chosen yet", and [_buildSinglePicker] makes the user choose.
  final String? courseId;
  final String courseTitle;
  final Color courseColor;

  /// When true, the All Courses plan is pre-selected instead of Single.
  /// Use this when opening the paywall from a generic "Plans & Pricing" entry
  /// rather than from a specific locked course.
  final bool defaultToAllPlans;
  final Future<List<Package>> Function() loadPackages;

  const PaywallScreen({
    super.key,
    this.courseId,
    required this.courseTitle,
    required this.courseColor,
    this.defaultToAllPlans = false,
    this.loadPackages = SubscriptionService.getPackages,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { single, bundle4, all }

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];
  bool _loading = true;

  /// True when RevenueCat returned no purchasable packages.
  ///
  /// This used to blank the entire paywall (`_loadError ? _buildErrorState()`),
  /// which is almost certainly why App Review reported under Guideline 2.1(b)
  /// that they "cannot locate the In-App Purchases". `getPackages()` swallows
  /// every RevenueCat error and returns `[]`, so one hiccup — or a sandbox
  /// account with no offerings attached — replaced every plan, price and
  /// purchase button with a "Could not load products" screen. The plans are
  /// now always rendered; only the purchase action is disabled.
  bool _productsUnavailable = false;
  bool _purchasing = false;
  late _Plan _selected;

  // Bundle-4: the courses the user has selected (max 4).
  // Pre-seed with the course they came from so it is already ticked.
  late Set<String> _bundle4Selection;

  /// Single: which course the one-course purchase is for.
  ///
  /// Seeded from [PaywallScreen.courseId] when the paywall was opened from a
  /// specific locked course, and left null otherwise so the user has to pick.
  late String? _singleSelection;

  @override
  void initState() {
    super.initState();
    _selected = widget.defaultToAllPlans ? _Plan.all : _Plan.single;
    final from = widget.courseId;
    _bundle4Selection = from != null ? {from} : <String>{};
    _singleSelection = from;
    _loadPackages();
  }

  /// The title shown for whatever single course is currently chosen.
  ///
  /// The catalogue name wins, because that is the trademark-safe one. It falls
  /// back to the title the paywall was opened with rather than to
  /// [displayTitle]'s raw-id fallback, so a course that is not catalogued yet
  /// reads as its name instead of as `binary-something-pro`.
  String get _singleTitle {
    final id = _singleSelection;
    if (id == null) return 'Single course';
    return courseInfo(id)?.title ??
        (id == widget.courseId ? widget.courseTitle : id);
  }

  Package? _packageFor(_Plan plan) {
    final id = {
      _Plan.single: _singleSelection == null
          ? null
          : courseInfo(_singleSelection!)?.productId,
      _Plan.bundle4: kProductBundle4,
      _Plan.all: kProductBundleAll,
    }[plan];
    if (id == null) return null;
    try {
      return _packages.firstWhere((p) => p.storeProduct.identifier == id);
    } catch (_) {
      return null;
    }
  }

  /// Live, localized price from the store. [fallback] only covers the brief
  /// window before RevenueCat's offerings load (or the rare case a product is
  /// misconfigured in App Store Connect) — it must never be the price actually
  /// charged, since App Store Connect pricing (and region-specific tiers) can
  /// change without a code deploy, and a stale hardcoded number would then be
  /// lying to the user about what they're about to pay.
  String _priceFor(_Plan plan, {required String fallback}) =>
      _packageFor(plan)?.storeProduct.priceString ?? fallback;

  bool get _selectedProductUnavailable =>
      (_selected != _Plan.single || _singleSelection != null) &&
      _packageFor(_selected) == null;

  /// "SAVE X%" computed from live numeric prices rather than a hardcoded
  /// dollar figure — a fixed "SAVE $10" is only true for one specific pair of
  /// USD prices and silently becomes a false claim (an App Store Review 2.3.1
  /// "inaccurate metadata" risk) the moment either price changes in App Store
  /// Connect or the user is in a different pricing region/currency. Percentage
  /// saved is currency-agnostic, so it stays correct everywhere.
  String get _bundle4SavingsBadge {
    final bundle = _packageFor(_Plan.bundle4)?.storeProduct;
    if (bundle == null || _bundle4Selection.length != 4) return 'BUNDLE';
    var fullPrice = 0.0;
    for (final courseId in _bundle4Selection) {
      final id = courseInfo(courseId)?.productId;
      final matches = _packages.where((p) => p.storeProduct.identifier == id);
      if (matches.isEmpty) return 'BUNDLE';
      final product = matches.first.storeProduct;
      if (product.currencyCode != bundle.currencyCode) return 'BUNDLE';
      fullPrice += product.price;
    }
    if (fullPrice <= 0 || bundle.price >= fullPrice) return 'BUNDLE';
    final percentSaved =
        (((fullPrice - bundle.price) / fullPrice) * 100).round();
    return percentSaved > 0 ? 'SAVE $percentSaved%' : 'BUNDLE';
  }

  Future<void> _loadPackages() async {
    setState(() {
      _loading = true;
      _productsUnavailable = false;
    });
    final packages = await widget.loadPackages();
    if (mounted) {
      setState(() {
        _packages = packages;
        _loading = false;
        _productsUnavailable = packages.isEmpty;
      });
    }
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  Future<void> _purchase() async {
    if (_purchasing) return;

    if (_packages.isEmpty) {
      // Previously "Products are still loading" — untrue once the load has
      // finished and failed, which left the user waiting for something that
      // was never going to arrive.
      _showError(
        'The App Store did not return any products. Check your connection and '
        'tap Retry. If you have already purchased, use Restore purchases.',
      );
      return;
    }

    // Single validation: the user must have chosen WHICH course. Without this
    // the purchase silently attaches to whatever course the paywall happened
    // to be opened from.
    if (_selected == _Plan.single && _singleSelection == null) {
      _showError('Please choose which course you want to unlock.');
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
        // Single: pass the course the user actually chose, which is only the
        // one they arrived from when they arrived from one.
        courseId: _selected == _Plan.single ? _singleSelection : null,
        // Bundle-4: pass the set of chosen courses as a list.
        selectedCourseIds:
            _selected == _Plan.bundle4 ? _bundle4Selection.toList() : null,
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
      final result = await SubscriptionService.restore();
      if (!mounted) return;
      if (result.isApplied) {
        final courseId = widget.courseId;
        if (courseId != null &&
            !await SubscriptionService.canAccessCourse(courseId)) {
          if (mounted) {
            _showError(
                'Your previous purchases were restored. This course is not included in them.');
          }
          return;
        }
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      } else {
        // Closing the paywall here would drop the user back onto content they
        // still cannot open. Stay put and say what actually happened.
        _showRestoreNotice(result);
      }
    } catch (e) {
      if (mounted) {
        _showRestoreNotice(RestoreResult.failed(message: e.toString()));
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  /// Restore feedback. Separate from [_showError] because "we found your
  /// purchase but it has not activated yet" is not an error and must not be
  /// titled like one.
  void _showRestoreNotice(RestoreResult result) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(result.title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(result.displayMessage),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    // A paid-but-not-yet-active purchase is not an error; titling it as one
    // reads like the charge failed and invites a second purchase.
    final paid = message.startsWith('Payment received');
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(paid ? 'Almost there' : 'Something went wrong'),
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
      case _Plan.single:
        if (_singleSelection == null) return 'Choose a course';
        return 'Unlock $_singleTitle · '
            '${_priceFor(_Plan.single, fallback: '\$14.99')}';
      case _Plan.bundle4:
        return _bundle4Selection.length == 4
            ? 'Unlock 4 Courses · ${_priceFor(_Plan.bundle4, fallback: '\$49.99')}'
            : 'Select ${4 - _bundle4Selection.length} more course${4 - _bundle4Selection.length == 1 ? '' : 's'}';
      case _Plan.all:
        return 'Unlock Everything · ${_priceFor(_Plan.all, fallback: '\$99.99')}';
    }
  }

  String get _planNotice {
    switch (_selected) {
      case _Plan.single:
        if (_singleSelection == null) {
          return 'One-time payment of ${_priceFor(_Plan.single, fallback: '\$14.99')}. Choose the course you want below.';
        }
        return 'One-time payment of ${_priceFor(_Plan.single, fallback: '\$14.99')}. Lifetime access to $_singleTitle.';
      case _Plan.bundle4:
        return 'One-time payment of ${_priceFor(_Plan.bundle4, fallback: '\$49.99')}. Choose any 4 courses. Yours forever.';
      case _Plan.all:
        return 'One-time payment of ${_priceFor(_Plan.all, fallback: '\$99.99')}. Every course + all future content. Yours forever.';
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
            : WebContentBounds(
                maxWidth: 640,
                child: Column(
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
                            if (_productsUnavailable ||
                                _selectedProductUnavailable) ...[
                              _buildUnavailableBanner(theme),
                              const SizedBox(height: 20),
                            ],
                            _buildPlanSection(theme),
                            // Course pickers — each only shown for its own plan.
                            if (_selected == _Plan.single) ...[
                              const SizedBox(height: 20),
                              _buildSinglePicker(theme),
                            ],
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
                )),
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
          title: _singleTitle,
          subtitle: '1 course · One-time purchase',
          price: _priceFor(_Plan.single, fallback: '\$14.99'),
          badge: 'STARTER',
          badgeColor: AppColors.green,
          color: widget.courseColor,
          theme: theme,
          unavailable: !_packages.any((p) => kCourseCatalog
              .any((c) => c.productId == p.storeProduct.identifier)),
        ),
        const SizedBox(height: 10),
        _buildPlanTile(
          plan: _Plan.bundle4,
          title: 'Any 4 Courses',
          subtitle: 'Pick any 4 courses · One-time',
          price: _priceFor(_Plan.bundle4, fallback: '\$49.99'),
          badge: _bundle4SavingsBadge,
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
          price: _priceFor(_Plan.all, fallback: '\$99.99'),
          badge: 'BEST VALUE',
          badgeColor: AppColors.primary,
          color: AppColors.primary,
          theme: theme,
          unavailable: _packageFor(_Plan.all) == null,
        ),
      ],
    );
  }

  /// Course picker shown when the Single plan is selected.
  ///
  /// Always shown, even when the paywall was opened from a specific course, so
  /// the user can both SEE which course they are about to buy and change their
  /// mind. Single-select: tapping a row replaces the choice rather than adding
  /// to it, which is what distinguishes this from the bundle-4 picker.
  Widget _buildSinglePicker(ThemeNotifier theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'WHICH COURSE?',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.subtext,
                  letterSpacing: 1.2),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _singleSelection != null
                    ? AppColors.green.withValues(alpha: 0.12)
                    : AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _singleSelection != null ? 'Selected ✓' : 'Pick one',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _singleSelection != null
                      ? AppColors.green
                      : AppColors.amber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._kAllCourses.map((course) {
          final id = course['id']!;
          final title = course['title']!;
          final isChecked = _singleSelection == id;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _singleSelection = id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: isChecked
                    ? widget.courseColor.withValues(alpha: 0.08)
                    : theme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isChecked
                      ? widget.courseColor.withValues(alpha: 0.35)
                      : theme.border,
                  width: isChecked ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Radio — round, unlike the bundle picker's square checkbox,
                  // because exactly one may be chosen.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color:
                          isChecked ? widget.courseColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChecked ? widget.courseColor : theme.subtext,
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
                        fontWeight:
                            isChecked ? FontWeight.w600 : FontWeight.w400,
                        color: isChecked ? theme.text : theme.subtext,
                        letterSpacing: -0.2,
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

  /// Course picker shown when bundle-4 plan is selected.
  /// The course the user arrived from is pre-ticked, and can be unticked like
  /// any other (see bundle_selection.dart).
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: remaining == 0
                    ? AppColors.green.withValues(alpha: 0.12)
                    : AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                remaining == 0 ? '4 / 4 selected ✓' : '$remaining more to pick',
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
          final id = course['id']!;
          final title = course['title']!;
          final isChecked = _bundle4Selection.contains(id);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _bundle4Selection =
                  toggleBundleCourse(_bundle4Selection, id));
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
                        fontWeight:
                            isChecked ? FontWeight.w600 : FontWeight.w400,
                        color: isChecked ? theme.text : theme.subtext,
                        letterSpacing: -0.2,
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
                style:
                    TextStyle(fontSize: 12, color: theme.subtext, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildCta(ThemeNotifier theme) {
    // CTA is disabled when the current plan's course choice is incomplete, or
    // when the store returned no packages to buy.
    final singleIncomplete =
        _selected == _Plan.single && _singleSelection == null;
    final bundle4Incomplete =
        _selected == _Plan.bundle4 && _bundle4Selection.length < 4;
    final ctaDisabled =
        singleIncomplete || bundle4Incomplete || _packageFor(_selected) == null;
    final ctaColor = ctaDisabled
        ? widget.courseColor.withValues(alpha: 0.4)
        : widget.courseColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: (_purchasing || ctaDisabled) ? null : _purchase,
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
                      (_productsUnavailable || _selectedProductUnavailable)
                          ? 'Purchases unavailable'
                          : _ctaLabel,
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
                onTap: () => _openUrl(kTermsUrl),
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
                onTap: () => _openUrl(kPrivacyUrl),
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
            'Payment processed by Apple.\nManage purchases and refund requests with Apple.',
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

  /// Shown in place of nothing — the plans stay on screen behind it.
  ///
  /// The point is that a reviewer, or a user on a flaky connection, can still
  /// SEE what is for sale. Only the purchase action is unavailable.
  Widget _buildUnavailableBanner(ThemeNotifier theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.wifi_exclamationmark,
              size: 20, color: theme.subtext),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _productsUnavailable
                      ? 'Purchases are unavailable right now'
                      : 'This selection is unavailable right now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The plans below are what is offered. Prices shown may not '
                  'be final until the store loads.',
                  style: TextStyle(
                      fontSize: 12.5, color: theme.subtext, height: 1.45),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _loadPackages,
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.courseColor,
                      decoration: TextDecoration.underline,
                      decorationColor: widget.courseColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan tile ─────────────────────────────────────────────────────────────

  Widget _buildPlanTile({
    required _Plan plan,
    required String title,
    required String subtitle,
    required String price,
    required String badge,
    required Color badgeColor,
    required Color color,
    required ThemeNotifier theme,
    required bool unavailable,
  }) {
    final selected = _selected == plan;
    final effectiveColor = unavailable ? theme.subtext : color;

    return GestureDetector(
      onTap: unavailable || _purchasing
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
            color:
                selected ? effectiveColor.withValues(alpha: 0.5) : theme.border,
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
                      style: TextStyle(fontSize: 12, color: theme.subtext)),
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
