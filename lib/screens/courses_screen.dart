import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_detail_screen.dart';
import 'subscription_service.dart';
import 'subscription_gate.dart';
import 'app_theme.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final ScrollController _scrollController = ScrollController();
  List<_Course> _courses = [];
  bool _loading = true;
  SubscriptionPlan _plan = SubscriptionPlan.none;
  String? _subscribedCourseId;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadSubscription();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    final plan = await SubscriptionService.getCurrentPlan();
    if (plan == SubscriptionPlan.single) {
      final info = await SubscriptionService.getCustomerInfo();
      if (info == null) {
        if (mounted) setState(() => _plan = plan);
        return;
      }
      // Pull subscribed course from Firestore
      final uid = info.originalAppUserId;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final courseId = snap.data()?['subscribedCourseId'] as String?;
      if (mounted) {
        setState(() {
          _plan = plan;
          _subscribedCourseId = courseId;
        });
      }
    } else {
      if (mounted) setState(() => _plan = plan);
    }
  }

  Future<void> _loadCourses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .orderBy('order')
          .get();
      final courses = snapshot.docs.map((doc) {
        final data = doc.data();
        return _Course(
          id: doc.id,
          title: data['title'] ?? '',
          subtitle: data['subtitle'] ?? '',
          tag: data['tag'] ?? '',
          color: Color(data['color'] ?? 0xFF0071E3),
          progress: (data['progress'] ?? 0.0).toDouble(),
        );
      }).toList();
      if (mounted) {
        setState(() {
          _courses = courses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _courseIsLocked(_Course course) {
    if (_plan == SubscriptionPlan.all) return false;
    if (_plan == SubscriptionPlan.single) {
      return _subscribedCourseId != course.id;
    }
    return true;
  }

  void _openCourse(BuildContext context, _Course course) {
    SubscriptionGate.enter(
      context: context,
      courseId: course.id,
      courseTitle: course.title,
      courseColor: course.color,
      onGranted: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => CourseDetailScreen(
              title: course.title,
              subtitle: course.subtitle,
              progress: course.progress,
              color: course.color,
              tag: course.tag,
            ),
            transitionsBuilder: (_, animation, __, child) => SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      },
    );
  }

  IconData _iconForTag(String tag) {
    switch (tag) {
      case 'ITIL V4':
        return CupertinoIcons.doc_text_fill;
      case 'CSM':
        return CupertinoIcons.person_2_fill;
      case 'Networking':
        return CupertinoIcons.antenna_radiowaves_left_right;
      case 'Binary Network Pro':
        return CupertinoIcons.wifi;
      case 'Binary Cyber Pro':
        return CupertinoIcons.shield_fill;
      case 'Binary Cloud':
        return CupertinoIcons.cloud_fill;
      case 'Binary Cloud Pro':
        return CupertinoIcons.cloud_upload_fill;
      default:
        return CupertinoIcons.book_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final available = _courses.toList();

    return Scaffold(
      backgroundColor: theme.bg,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Courses',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                        letterSpacing: -1.5,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Everything you need to get certified.',
                      style: TextStyle(
                        fontSize: 17,
                        color: theme.subtext,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),

          // ── Search bar ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  boxShadow: theme.isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.search, color: theme.subtext, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      'Search courses...',
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.subtext,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_loading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else ...[
            if (available.isNotEmpty) ...[
              _sectionLabel('Available now', theme),
              _featuredCourse(context, available.first, theme),
              if (available.length > 1)
                _courseList(context, available.skip(1).toList(), theme),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(
    ThemeNotifier theme, {
    Color? accentColor,
    bool featured = false,
  }) {
    if (theme.isDark) {
      return BoxDecoration(
        color: featured
            ? (accentColor ?? AppColors.primary).withValues(alpha: 0.08)
            : AppColors.darkCard,
        borderRadius: BorderRadius.circular(featured ? 24 : 20),
        border: Border.all(
          color: featured
              ? (accentColor ?? AppColors.primary).withValues(alpha: 0.25)
              : AppColors.darkBorder,
        ),
      );
    }
    return BoxDecoration(
      color: AppColors.lightCard,
      borderRadius: BorderRadius.circular(featured ? 24 : 20),
      border: Border.all(color: AppColors.lightBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: featured ? 0.07 : 0.04),
          blurRadius: featured ? 20 : 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label, ThemeNotifier theme) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 14),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.subtext,
          letterSpacing: 1.4,
        ),
      ),
    ),
  );

  Widget _featuredCourse(
    BuildContext context,
    _Course course,
    ThemeNotifier theme,
  ) {
    final locked = _courseIsLocked(course);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _AnimatedCard(
          delay: Duration.zero,
          child: GestureDetector(
            onTap: () => _openCourse(context, course),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: _cardDecoration(
                theme,
                accentColor: course.color,
                featured: true,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: course.color.withValues(
                            alpha: theme.isDark ? 0.18 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _iconForTag(course.tag),
                          color: course.color,
                          size: 26,
                        ),
                      ),
                      const Spacer(),
                      if (locked)
                        _lockBadge(theme)
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? course.color.withValues(alpha: 0.15)
                                : course.color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            course.progress > 0 ? 'IN PROGRESS' : 'START',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.isDark ? course.color : Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    course.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    course.subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.subtext,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: locked ? 0 : course.progress,
                            backgroundColor: theme.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.lightBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              course.color,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        locked
                            ? 'Locked'
                            : '${(course.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          color: locked ? theme.subtext : course.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: locked ? theme.surface : course.color,
                      borderRadius: BorderRadius.circular(14),
                      border: locked ? Border.all(color: theme.border) : null,
                    ),
                    child: Text(
                      locked
                          ? 'Unlock course'
                          : course.progress > 0
                          ? 'Continue learning'
                          : 'Start course',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: locked ? theme.subtext : Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _courseList(
    BuildContext context,
    List<_Course> courses,
    ThemeNotifier theme,
  ) => SliverList(
    delegate: SliverChildBuilderDelegate((context, index) {
      final course = courses[index];
      final locked = _courseIsLocked(course);
      return _AnimatedCard(
        delay: Duration(milliseconds: 80 * (index + 1)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: GestureDetector(
            onTap: () => _openCourse(context, course),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(theme),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: course.color.withValues(
                        alpha: theme.isDark ? 0.15 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _iconForTag(course.tag),
                      color: course.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          course.subtitle,
                          style: TextStyle(fontSize: 12, color: theme.subtext),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: locked ? 0 : course.progress,
                            backgroundColor: theme.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.lightBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              course.color,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (locked)
                        _lockBadge(theme)
                      else
                        Text(
                          '${(course.progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: course.color,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Icon(
                          locked
                              ? CupertinoIcons.lock_fill
                              : Icons.arrow_forward_ios_rounded,
                          size: locked ? 12 : 11,
                          color: theme.subtext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }, childCount: courses.length),
  );

  Widget _lockBadge(ThemeNotifier theme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: theme.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.lock_fill, size: 10, color: theme.subtext),
        const SizedBox(width: 4),
        Text(
          'Locked',
          style: TextStyle(
            fontSize: 11,
            color: theme.subtext,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// ── Animated card ─────────────────────────────────────────────────────────────
class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedCard({required this.child, this.delay = Duration.zero});
  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── Model ─────────────────────────────────────────────────────────────────────
class _Course {
  final String id, title, subtitle, tag;
  final Color color;
  final double progress;
  const _Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.color,
    required this.progress,
  });
}
