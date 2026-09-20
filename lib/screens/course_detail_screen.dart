import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../course_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'service_backend.dart';
import 'offline_service.dart';
import 'lesson_screen.dart';
import 'subscription_service.dart';
import 'paywall_screen.dart';
import 'app_router.dart';
import 'app_theme.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String title;
  final String subtitle;
  final double progress;
  final Color color;
  final String tag;
  final bool downloadedOnly;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
    required this.tag,
    this.downloadedOnly = false,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  // ── Animations ──────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  // ── State ────────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _modules = [];
  Map<String, String> _userModuleStatus = {};
  bool _loading = true;
  bool _hasPaidAccess = false;
  bool _loadFailed = false;
  double get _progress => _modules.isEmpty
      ? 0
      : _modules
              .where((module) => _userModuleStatus[module['id']] == 'done')
              .length /
          _modules.length;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerFade =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_loadModules(), _checkAccess()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadModules() async {
    try {
      final uid = ServiceBackend.uid;

      // The downloads entry point reads its local manifest without a network wait.
      final modules = widget.downloadedOnly
          ? await OfflineService.loadCachedModules(widget.courseId)
          : (await ServiceBackend.db
                  .collection('courses')
                  .doc(widget.courseId)
                  .collection('modules')
                  .orderBy('order')
                  .get()
                  .timeout(const Duration(seconds: 12)))
              .docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();

      // Load per-user module completion status
      Map<String, String> userStatus = {};
      if (uid != null) {
        try {
          final userModulesSnap = await ServiceBackend.db
              .collection('users')
              .doc(uid)
              .collection('progress')
              .doc(widget.courseId)
              .collection('modules')
              .get(GetOptions(
                  source: widget.downloadedOnly
                      ? Source.cache
                      : Source.serverAndCache))
              .timeout(const Duration(seconds: 12));
          for (final doc in userModulesSnap.docs) {
            final data = doc.data();
            userStatus[doc.id] = (data['status'] as String?) ?? 'locked';
          }
        } catch (_) {}
      }

      if (mounted && ServiceBackend.uid == uid) {
        setState(() {
          _modules = modules;
          _userModuleStatus = userStatus;
          _loadFailed = widget.downloadedOnly && modules.isEmpty;
        });
      }
    } catch (_) {
      final cached = await OfflineService.loadCachedModules(widget.courseId);
      if (mounted) {
        setState(() {
          _modules = cached;
          _loadFailed = cached.isEmpty;
        });
      }
    }
  }

  Future<void> _checkAccess() async {
    try {
      final hasAccess = await SubscriptionService.canAccessCourse(
          widget.courseId,
          cachedOnly: widget.downloadedOnly);
      if (mounted) setState(() => _hasPaidAccess = hasAccess);
    } catch (_) {}
  }

  // ── Module status helpers ─────────────────────────────────────────────────────
  String _moduleStatus(Map<String, dynamic> module) {
    final moduleId = module['id'] as String;
    // If we have a user-specific status, use that
    if (_userModuleStatus.containsKey(moduleId)) {
      return _userModuleStatus[moduleId]!;
    }
    // Fall back to the shared module status
    return (module['status'] as String?) ?? 'locked';
  }

  bool _canAccessModule(Map<String, dynamic> module, int index) {
    // Progress is display state, never a purchase entitlement.
    return _hasPaidAccess ||
        SubscriptionService.isFreePreviewModule(module['id'] as String);
  }

  void _openModule(Map<String, dynamic> module, int index) {
    if (!_canAccessModule(module, index)) {
      HapticFeedback.mediumImpact();
      _showPaywall();
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      AppRouter.push(
        LessonScreen(
          moduleTitle: displayModuleTitle(module['title'] as String?),
          courseTag: widget.tag,
          color: widget.color,
          moduleId: module['id'] as String,
          courseId: widget.courseId,
          downloadedOnly: widget.downloadedOnly,
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _showPaywall() {
    Navigator.push(
      context,
      AppRouter.push(
        PaywallScreen(
          courseId: widget.courseId,
          courseTitle: widget.title,
          courseColor: widget.color,
        ),
      ),
    ).then((_) {
      // Re-check access after paywall is dismissed, in case a purchase occurred
      if (mounted) _checkAccess();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: WebContentBounds(
        maxWidth: 720,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(context, theme),
            if (_loading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: widget.color,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              _buildModuleList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeNotifier theme) {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // Gradient wash behind header
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withValues(alpha: theme.isDark ? 0.20 : 0.10),
                  widget.color.withValues(alpha: theme.isDark ? 0.04 : 0.02),
                  theme.bg,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(
                position: _headerSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _BackButton(
                            color: widget.color,
                            theme: theme,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Title
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                          letterSpacing: -1.2,
                          height: 1.05,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Subtitle
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          color: theme.subtext,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Progress bar (only if the user has started)
                      if (_progress > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.subtext,
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: widget.color,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: theme.border,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(widget.color),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Free trial banner — shown when user doesn't have paid access
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: (!_loading && !_hasPaidAccess)
                            ? _FreeBanner(
                                key: const ValueKey('banner'),
                                color: widget.color,
                              )
                            : const SizedBox(key: ValueKey('empty'), height: 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleList(ThemeNotifier theme) {
    if (_modules.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.book_fill, size: 40, color: theme.subtext),
                const SizedBox(height: 16),
                Text(
                  _loadFailed
                      ? 'Could not load modules'
                      : 'Modules coming soon',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.text),
                ),
                const SizedBox(height: 6),
                Text(
                  _loadFailed
                      ? 'Check your connection and try again.'
                      : 'Check back shortly.',
                  style: TextStyle(fontSize: 13, color: theme.subtext),
                ),
                if (_loadFailed) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final module = _modules[i];
            final status = _moduleStatus(module);
            final canAccess = _canAccessModule(module, i);
            return _ModuleCard(
              module: module,
              index: i,
              status: status,
              canAccess: canAccess,
              hasPaidAccess: _hasPaidAccess,
              color: widget.color,
              theme: theme,
              onTap: () => _openModule(module, i),
            );
          },
          childCount: _modules.length,
        ),
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final Color color;
  final ThemeNotifier theme;
  final VoidCallback onTap;

  const _BackButton({
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              'Back',
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeBanner extends StatelessWidget {
  final Color color;

  const _FreeBanner({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.gift_fill, size: 13, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Module 1 is free — try it now',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final Map<String, dynamic> module;
  final int index;
  final String status;
  final bool canAccess;
  final bool hasPaidAccess;
  final Color color;
  final ThemeNotifier theme;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.index,
    required this.status,
    required this.canAccess,
    required this.hasPaidAccess,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final raw = displayModuleTitle(module['title'] as String?);
    final title = raw.isEmpty ? 'Module ${index + 1}' : raw;
    // Use Firestore subtitle (e.g. "6 flashcards · 6 questions") when available
    final subtitle = (module['subtitle'] as String?);
    final isDone = status == 'done';
    final isLocked = !canAccess;
    // Show FREE badge on the first module when user hasn't purchased
    final showFreeBadge =
        SubscriptionService.isFreePreviewModule(module['id'] as String) &&
            !hasPaidAccess &&
            !isDone;

    Color statusColor;
    IconData statusIcon;
    if (isDone) {
      statusColor = AppColors.green;
      statusIcon = CupertinoIcons.checkmark_circle_fill;
    } else if (isLocked) {
      statusColor = theme.subtext;
      statusIcon = CupertinoIcons.lock_fill;
    } else {
      statusColor = color;
      statusIcon = CupertinoIcons.play_circle_fill;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? AppColors.green.withValues(alpha: 0.25)
                : isLocked
                    ? theme.border
                    : color.withValues(alpha: 0.25),
            width: isLocked ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Number badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isLocked
                    ? Icon(CupertinoIcons.lock_fill,
                        size: 14, color: statusColor)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Title + subtitle — takes all remaining width
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: title text + optional FREE badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isLocked ? theme.subtext : theme.text,
                            letterSpacing: -0.2,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (showFreeBadge) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'FREE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle != null && subtitle.isNotEmpty
                        ? subtitle
                        : isDone
                            ? 'Completed'
                            : isLocked
                                ? 'Locked — unlock to access'
                                : 'Tap to start',
                    style: TextStyle(fontSize: 12, color: statusColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right action area
            if (showFreeBadge)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Try free',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
              )
            else if (isLocked)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.isDark
                      ? theme.surface
                      : theme.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.lock_fill,
                        size: 10, color: theme.subtext),
                    const SizedBox(width: 4),
                    Text(
                      'Unlock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.subtext,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(statusIcon, size: 20, color: statusColor),
          ],
        ),
      ),
    );
  }
}
