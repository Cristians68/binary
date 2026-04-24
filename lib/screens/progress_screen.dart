import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'course_detail_screen.dart';
import 'streak_service.dart';
import 'app_router.dart';
import 'app_theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  List<Map<String, dynamic>> _courses = [];
  Map<String, double> _userProgress = {};
  int _lessonsCompleted = 0;
  int _badgeCount = 0;
  int _streak = 0;
  List<BadgeData> _badges = [];
  List<Map<String, dynamic>> _recentActivity = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadCourses(), _loadUserData()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCourses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .orderBy('order')
          .get();
      if (mounted) {
        setState(() {
          _courses = snapshot.docs
              .where((d) => !(d.data()['isComingSoon'] ?? false))
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Load user doc and streak/badge data in parallel
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('progress')
            .get(),
        StreakService.fetchAll(),
      ]);

      final userSnap = results[0] as DocumentSnapshot;
      final progressSnap = results[1] as QuerySnapshot;
      final streakData = results[2]
          as ({StreakData streak, DailyGoalData goal, List<BadgeData> badges});

      final userData = userSnap.data() as Map<String, dynamic>? ?? {};

      // Per-user course progress
      final progressMap = <String, double>{};
      for (final doc in progressSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        progressMap[doc.id] =
            ((data['progress'] as num?) ?? 0.0).toDouble();
      }

      // Recent activity from completedLessons
      final raw = List<Map<String, dynamic>>.from(
        (userData['completedLessons'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
            [],
      );
      // Most recent first, limit to 5
      final activity = raw.reversed.take(5).toList();

      if (mounted) {
        setState(() {
          _userProgress = progressMap;
          _lessonsCompleted =
              ((userData['lessonsCompleted'] as num?) ?? 0).toInt();
          _streak = streakData.streak.current;
          _badges = streakData.badges;
          _badgeCount = streakData.badges.where((b) => b.isEarned).length;
          _recentActivity = activity;
        });
      }
    } catch (e) {
      debugPrint('ProgressScreen._loadUserData error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _overallProgress {
    if (_courses.isEmpty) return 0.0;
    final total = _courses.fold<double>(
      0,
      (sum, c) => sum + (_userProgress[c['id'] as String] ?? 0.0),
    );
    return total / _courses.length;
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
    return Scaffold(
      backgroundColor: theme.bg,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeader(theme),
              _buildOverallProgress(theme),
              _buildSectionLabel('Course breakdown', theme),
              _buildCourseBreakdown(theme),
              _buildSectionLabel('Badges earned', theme),
              _buildBadges(theme),
              _buildSectionLabel('Recent activity', theme),
              _buildActivity(theme),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeNotifier theme) {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                  letterSpacing: -1.2,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your learning journey.',
                style: TextStyle(
                    fontSize: 17,
                    color: theme.subtext,
                    letterSpacing: -0.2),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallProgress(ThemeNotifier theme) {
    final pct = _overallProgress;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: pct,
                      backgroundColor: theme.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      strokeWidth: 7,
                    ),
                    Center(
                      child: Text(
                        '${(pct * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _statRow(
                      CupertinoIcons.checkmark_seal_fill,
                      '$_lessonsCompleted lesson${_lessonsCompleted == 1 ? '' : 's'} completed',
                      AppColors.green,
                      theme,
                    ),
                    const SizedBox(height: 6),
                    _statRow(
                      CupertinoIcons.rosette,
                      '$_badgeCount badge${_badgeCount == 1 ? '' : 's'} earned',
                      AppColors.amber,
                      theme,
                    ),
                    const SizedBox(height: 6),
                    _statRow(
                      CupertinoIcons.flame_fill,
                      '$_streak day streak',
                      AppColors.red,
                      theme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(
      IconData icon, String text, Color color, ThemeNotifier theme) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
              fontSize: 12, color: theme.subtext, letterSpacing: -0.1),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, ThemeNotifier theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 14),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.subtext,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildCourseBreakdown(ThemeNotifier theme) {
    if (_loading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Text('No courses yet',
                style: TextStyle(fontSize: 14, color: theme.subtext)),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final course = _courses[index];
            final courseId = course['id'] as String;
            final color = Color(course['color'] ?? 0xFF6366F1);
            final tag = course['tag'] ?? '';
            // ✅ Use per-user progress, not shared course field
            final progress = _userProgress[courseId] ?? 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  AppRouter.push(CourseDetailScreen(
                    title: course['title'] ?? '',
                    subtitle: course['subtitle'] ?? '',
                    progress: progress,
                    color: color,
                    tag: tag,
                  )),
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_iconForTag(tag),
                            color: color, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course['title'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.text,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: theme.border,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: _courses.length,
        ),
      ),
    );
  }

  Widget _buildBadges(ThemeNotifier theme) {
    final earned = _badges.where((b) => b.isEarned).toList();

    if (earned.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              children: [
                Icon(CupertinoIcons.rosette,
                    size: 36, color: theme.subtext),
                const SizedBox(height: 12),
                Text(
                  'No badges yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.subtext,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete lessons to earn badges',
                  style:
                      TextStyle(fontSize: 12, color: theme.subtext),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: earned
              .map((b) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(b.emoji,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          b.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildActivity(ThemeNotifier theme) {
    if (_recentActivity.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              children: [
                Icon(CupertinoIcons.time,
                    size: 36, color: theme.subtext),
                const SizedBox(height: 12),
                Text(
                  'No activity yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.subtext,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start a lesson to see your activity here',
                  style:
                      TextStyle(fontSize: 12, color: theme.subtext),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _recentActivity[index];
            final pct = (item['percent'] as num?)?.toInt() ?? 0;
            final color = pct >= 80
                ? AppColors.green
                : pct >= 60
                    ? AppColors.amber
                    : AppColors.red;
            final ts =
                (item['completedAt'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('$pct%',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['moduleTitle'] as String? ?? 'Lesson',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['courseTag'] as String? ?? '',
                          style: TextStyle(
                              fontSize: 12, color: theme.subtext),
                        ),
                      ],
                    ),
                  ),
                  if (ts != null)
                    Text(
                      _formatDate(ts),
                      style: TextStyle(
                          fontSize: 11, color: theme.subtext),
                    ),
                ],
              ),
            );
          },
          childCount: _recentActivity.length,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return '${date.month}/${date.day}';
  }
}
