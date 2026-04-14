import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'welcome_screen.dart';
import 'course_detail_screen.dart';
import 'app_router.dart';
import 'badges_screen.dart';
import 'lessons_screen.dart';
import 'quiz_score_screen.dart';
import 'streak_service.dart';
import 'app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _loadingCourses = true;
  bool _seeding = false;

  int _streak = 0;
  int _badgeCount = 0;
  int _lessonCount = 0;
  String _avgQuizScore = '-';
  int _dailyPoints = 0;
  int _dailyTarget = 50;

  @override
  void initState() {
    super.initState();
    _initStreak();
    _seedAndLoad();
  }

  Future<void> _initStreak() async {
    await StreakService.checkAndUpdateStreak();
  }

  Future<void> _seedAndLoad() async {
    final db = FirebaseFirestore.instance;
    if (mounted) setState(() => _seeding = true);
    await _seedAllCourses(db);
    if (mounted) setState(() => _seeding = false);
    await _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .orderBy('order')
          .get();
      if (mounted) {
        setState(() {
          _courses =
              snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _loadingCourses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCourses = false);
    }
  }

  Future<void> _seedAllCourses(FirebaseFirestore db) async {
    await _seedCourse(db, 'binary-network-professional', {
      'title': 'Network Professional',
      'subtitle':
          'Master modern networking from fundamentals to advanced design',
      'tag': 'Binary Network Pro',
      'color': 0xFF3B82F6,
      'order': 1,
      'isComingSoon': false,
      'progress': 0.0,
      'totalModules': 20,
    }, []);

    await _seedCourse(db, 'binary-cybersecurity-professional', {
      'title': 'Cybersecurity Professional',
      'subtitle': 'Threats, defenses, and ethical hacking techniques',
      'tag': 'Binary Cyber Pro',
      'color': 0xFFEF4444,
      'order': 2,
      'isComingSoon': false,
      'progress': 0.0,
      'totalModules': 20,
    }, []);

    await _seedCourse(db, 'binary-cloud-fundamentals', {
      'title': 'Cloud Fundamentals',
      'subtitle': 'Cloud concepts, services, and core architecture',
      'tag': 'Binary Cloud',
      'color': 0xFF06B6D4,
      'order': 3,
      'isComingSoon': false,
      'progress': 0.0,
      'totalModules': 20,
    }, []);

    await _seedCourse(db, 'binary-cloud-professional', {
      'title': 'Cloud Professional',
      'subtitle': 'Advanced cloud design, deployment, and optimization',
      'tag': 'Binary Cloud Pro',
      'color': 0xFF8B5CF6,
      'order': 4,
      'isComingSoon': false,
      'progress': 0.0,
      'totalModules': 20,
    }, []);
  }

  Future<void> _seedCourse(
    FirebaseFirestore db,
    String docId,
    Map<String, dynamic> courseData,
    List<Map<String, dynamic>> modules,
  ) async {
    final ref = db.collection('courses').doc(docId);
    await ref.set(courseData);
  }

  void _onStatsUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    // Badges — stored as a map of badgeId -> timestamp
    final badgesMap = data['badges'] as Map<String, dynamic>? ?? {};
    final badges = badgesMap.length;

    // Completed lessons
    final lessons = (data['completedLessons'] as List<dynamic>?)?.length ?? 0;

    // Quiz scores
    final scores = List<Map<String, dynamic>>.from(
      (data['quizScores'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
          [],
    );
    String avgScore = '-';
    if (scores.isNotEmpty) {
      final avg = scores.fold<double>(
            0,
            (s, e) => s + ((e['score'] as num?) ?? 0).toDouble(),
          ) /
          scores.length;
      avgScore = '${avg.toStringAsFixed(0)}%';
    }

    // Streak — now stored as nested map
    final streakMap = data['streak'] as Map<String, dynamic>? ?? {};
    final streak = (streakMap['current'] as num?)?.toInt() ?? 0;

    // Daily goal — points-based
    final goalMap = data['dailyGoal'] as Map<String, dynamic>? ?? {};
    final dailyPoints = (goalMap['todayPoints'] as num?)?.toInt() ?? 0;
    final dailyTarget = (goalMap['target'] as num?)?.toInt() ?? 50;

    setState(() {
      _streak = streak;
      _badgeCount = badges;
      _lessonCount = lessons;
      _avgQuizScore = avgScore;
      _dailyPoints = dailyPoints;
      _dailyTarget = dailyTarget;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFirstName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ')[0];
    }
    return 'there';
  }

  void _navigateToCourse(Map<String, dynamic> course) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      AppRouter.push(
        CourseDetailScreen(
          title: course['title'] ?? '',
          subtitle: course['subtitle'] ?? '',
          progress: (course['progress'] ?? 0.0).toDouble(),
          color: Color(course['color'] ?? 0xFF6366F1),
          tag: course['tag'] ?? '',
        ),
      ),
    );
  }

  void _showSignOutSheet(ThemeNotifier theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.subtext.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary,
              child: Text(
                _getFirstName().isNotEmpty
                    ? _getFirstName()[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getFirstName(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.text,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: TextStyle(fontSize: 13, color: theme.subtext),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () async {
                Navigator.pop(sheetContext);
                await AuthService.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    AppRouter.fade(const WelcomeScreen()),
                    (r) => false,
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.square_arrow_left,
                      color: AppColors.red,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Sign out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

    if (_seeding) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
              const SizedBox(height: 20),
              Text(
                'Setting up your courses…',
                style: TextStyle(fontSize: 15, color: theme.subtext),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.bg,
      body: StreamBuilder<Map<String, dynamic>>(
        stream: StreakService.statsStream(),
        builder: (context, snap) {
          if (snap.hasData) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _onStatsUpdate(snap.data!),
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 20),
                  _buildStreakCard(theme),
                  const SizedBox(height: 20),
                  _buildDailyGoal(theme),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Continue learning', theme),
                  const SizedBox(height: 12),
                  if (_loadingCourses)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (_courses.isEmpty)
                    _buildEmptyCourses(theme)
                  else
                    ..._courses.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildCourseCard(c, theme),
                      ),
                    ),
                  if (_courses.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSectionTitle("Today's picks", theme),
                    const SizedBox(height: 12),
                    _buildTodayCard(
                      icon: _iconForTag(_courses.first['tag'] ?? ''),
                      title: _courses.first['title'] ?? '',
                      sub: '${_courses.first['tag']} · Module 1',
                      color: Color(_courses.first['color'] ?? 0xFF6366F1),
                      course: _courses.first,
                      theme: theme,
                    ),
                    if (_courses.length > 1) ...[
                      const SizedBox(height: 8),
                      _buildTodayCard(
                        icon: _iconForTag(_courses[1]['tag'] ?? ''),
                        title: _courses[1]['title'] ?? '',
                        sub: '${_courses[1]['tag']} · Module 1',
                        color: Color(_courses[1]['color'] ?? 0xFF10B981),
                        course: _courses[1],
                        theme: theme,
                      ),
                    ],
                  ],
                  const SizedBox(height: 28),
                  _buildSectionTitle('Stats', theme),
                  const SizedBox(height: 12),
                  _buildStatsRow(theme),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeNotifier theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.subtext,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  CupertinoIcons.hand_raised_fill,
                  size: 15,
                  color: Color(0xFFF59E0B),
                ),
              ],
            ),
            Text(
              _getFirstName(),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: theme.text,
                letterSpacing: -1.0,
                height: 1.1,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _showSignOutSheet(theme),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(
              _getFirstName().isNotEmpty
                  ? _getFirstName()[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(ThemeNotifier theme) {
    final label = _streak == 1 ? '1 day streak!' : '$_streak day streak!';
    final sub = _streak == 0
        ? 'Start your streak today!'
        : _streak < 3
            ? 'Great start — keep going!'
            : _streak < 7
                ? 'You\'re building momentum!'
                : 'You\'re on a roll!';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              CupertinoIcons.flame_fill,
              color: AppColors.amber,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(fontSize: 12, color: theme.subtext),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.rosette,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_streak',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoal(ThemeNotifier theme) {
    final pct = (_dailyPoints / _dailyTarget).clamp(0.0, 1.0);
    final isComplete = _dailyPoints >= _dailyTarget;
    final color = isComplete ? AppColors.green : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily goal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                isComplete
                    ? 'Complete! 🎉'
                    : '$_dailyPoints / $_dailyTarget pts',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: theme.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildPointPill(theme, '📖', '+10 per lesson'),
              const SizedBox(width: 8),
              _buildPointPill(theme, '✅', '+20 per quiz'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointPill(ThemeNotifier theme, String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
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

  Widget _buildEmptyCourses(ThemeNotifier theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(CupertinoIcons.book_fill, size: 32, color: theme.subtext),
            const SizedBox(height: 12),
            Text(
              'No courses yet',
              style: TextStyle(fontSize: 14, color: theme.subtext),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, ThemeNotifier theme) {
    final color = Color(course['color'] ?? 0xFF6366F1);
    final progress = (course['progress'] ?? 0.0).toDouble();
    return GestureDetector(
      onTap: () => _navigateToCourse(course),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.isDark
              ? color.withValues(alpha: 0.07)
              : AppColors.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.isDark
                ? color.withValues(alpha: 0.2)
                : AppColors.lightBorder,
          ),
          boxShadow: theme.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: theme.isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _iconForTag(course['tag'] ?? ''),
                color: color,
                size: 22,
              ),
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
                  const SizedBox(height: 2),
                  Text(
                    course['subtitle'] ?? '',
                    style: TextStyle(fontSize: 12, color: theme.subtext),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          theme.isDark ? theme.border : AppColors.lightBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 12,
                  color: theme.subtext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard({
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required Map<String, dynamic> course,
    required ThemeNotifier theme,
  }) {
    return GestureDetector(
      onTap: () => _navigateToCourse(course),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.isDark
              ? color.withValues(alpha: 0.07)
              : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.isDark
                ? color.withValues(alpha: 0.18)
                : AppColors.lightBorder,
          ),
          boxShadow: theme.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: theme.isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(fontSize: 11, color: theme.subtext),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Start',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeNotifier theme) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: theme.subtext,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildStatsRow(ThemeNotifier theme) {
    return Row(
      children: [
        _buildStatCard(
          icon: CupertinoIcons.rosette,
          iconColor: AppColors.amber,
          bgColor: AppColors.amber,
          label: 'Badges',
          value: '$_badgeCount',
          theme: theme,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(context, AppRouter.push(const BadgesScreen()));
          },
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: CupertinoIcons.checkmark_seal_fill,
          iconColor: AppColors.green,
          bgColor: AppColors.green,
          label: 'Lessons',
          value: '$_lessonCount',
          theme: theme,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(context, AppRouter.push(const LessonsScreen()));
          },
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          icon: Icons.track_changes_rounded,
          iconColor: AppColors.primary,
          bgColor: AppColors.primary,
          label: 'Quiz score',
          value: _avgQuizScore,
          theme: theme,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(context, AppRouter.push(const QuizScoreScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required ThemeNotifier theme,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.subtext,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
