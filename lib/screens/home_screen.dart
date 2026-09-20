import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'course_detail_screen.dart';
import 'app_router.dart';
import 'badges_screen.dart';
import 'paywall_screen.dart';
import 'lessons_screen.dart';
import 'quiz_score_screen.dart';
import 'streak_logic.dart';
import 'streak_service.dart';
import 'review_service.dart';
import 'review_screen.dart';
import 'app_theme.dart';
import 'learning_widgets.dart';
import 'courses_screen.dart';
import 'service_backend.dart';
import 'sign_out.dart';
import '../course_catalog.dart';

// Safely cast a Firestore value to Map<String, dynamic>.
// On web, nested maps can arrive as Map<Object, Object>.
Map<String, dynamic> _toMap(dynamic value) {
  if (value == null) return {};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return {};
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onBrowseCourses, this.learnerName});
  final VoidCallback? onBrowseCourses;
  final String? learnerName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Every course, in catalogue order. Static content, so it is read once.
  List<Map<String, dynamic>> _allCourses = [];

  /// Which of them this user is in. Comes from the live user document, so
  /// enrolling on the Courses tab shows up here without a relaunch.
  Set<String> _enrolledIds = {};
  bool _loadingCourses = true;

  /// Derived, never stored: one join, shared with the Courses tab, so the two
  /// cannot drift apart again.
  List<Map<String, dynamic>> get _enrolledCourses =>
      StreakService.enrolledCoursesFrom(_allCourses, _enrolledIds)
          .map((course) =>
              {...course, 'progress': _courseProgress[course['id']] ?? 0.0})
          .toList();

  int _streak = 0;
  int _badgeCount = 0;
  int _lessonCount = 0;
  String _avgQuizScore = '-';
  int _dailyPoints = 0;
  int _dailyTarget = 50;

  /// Whether the user owns the All Courses plan. Drives the upgrade card.
  bool _hasFullAccess = false;

  int _reviewDue = 0;
  String? _reviewNextLabel;

  StreamSubscription<Map<String, dynamic>>? _statsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _progressSub;
  Map<String, double> _courseProgress = {};

  @override
  void initState() {
    super.initState();
    _initStreak();
    _loadCatalogue();
    _loadReviewQueue();
    _statsSub = StreakService.statsStream().listen(
      _onStatsUpdate,
      onError: (Object error) => debugPrint('Home stats: $error'),
    );
    final uid = ServiceBackend.uid;
    if (uid != null) {
      _progressSub = ServiceBackend.watchProgress().listen((snapshot) {
        if (!mounted) return;
        setState(() => _courseProgress = {
              for (final doc in snapshot.docs)
                doc.id: ((doc.data()['progress'] as num?) ?? 0)
                    .toDouble()
                    .clamp(0.0, 1.0),
            });
      }, onError: (Object error) => debugPrint('Home progress: $error'));
    }
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _initStreak() async {
    await StreakService.checkAndUpdateStreak();
  }

  /// Read the course catalogue once.
  ///
  /// This deliberately does NOT read the user document. It used to, in the
  /// same one-shot: that read ran once in initState, and because
  /// MainNavigation builds every tab in an IndexedStack at launch it ran
  /// before the user had done anything and never ran again. Enrolling on the
  /// Courses tab left Home saying "No courses yet" until the next cold start,
  /// and on that start the read could race ServerClock's lastSeenAt write and
  /// come back with a document holding nothing else. Enrolments now arrive on
  /// the stream instead; only the catalogue is fetched here.
  Future<void> _loadCatalogue() async {
    try {
      final coursesSnap =
          await ServiceBackend.db.collection('courses').orderBy('order').get();

      if (mounted) {
        setState(() {
          _allCourses = knownCourses(
              coursesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
          _loadingCourses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCourses = false);
    }
  }

  void _onStatsUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    // Use _toMap so web's Map<Object,Object> is handled safely
    final badgesMap = _toMap(data['badges']);
    final streakMap = _toMap(data['streak']);
    final goalMap = _toMap(data['dailyGoal']);

    final lessons = (data['completedLessons'] as List<dynamic>?)?.length ?? 0;

    final rawScores = data['quizScores'];
    List<Map<String, dynamic>> scores = [];
    if (rawScores is List) {
      scores = rawScores
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }

    String avgScore = '-';
    if (scores.isNotEmpty) {
      final avg = scores.fold<double>(
            0,
            (s, e) => s + ((e['score'] as num?) ?? 0).toDouble(),
          ) /
          scores.length;
      avgScore = '${avg.toStringAsFixed(0)}%';
    }

    setState(() {
      _enrolledIds = StreakService.enrolledCourseIdsFrom(data);
      _streak = (streakMap['current'] as num?)?.toInt() ?? 0;
      // Only badges the grid can display — see knownEarnedBadges.
      _badgeCount =
          knownEarnedBadges(badgesMap.keys.map((k) => k.toString())).length;
      _lessonCount = lessons;
      _avgQuizScore = avgScore;
      _dailyPoints = (goalMap['todayPoints'] as num?)?.toInt() ?? 0;
      _dailyTarget = (goalMap['target'] as num?)?.toInt() ?? 50;
      // Read from the same live stream as everything else, so the upgrade
      // card disappears the moment the webhook grants the entitlement.
      _hasFullAccess = (data['subscriptionPlan'] as String?) == 'all';
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFirstName() {
    if (widget.learnerName != null) return widget.learnerName!.split(' ').first;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ')[0];
    }
    // "there" was the fallback, which rendered as a 32pt bold "there" under
    // "Good evening" — the first thing a guest, and therefore an App Review
    // tester, sees. A guest has no name because they chose not to give one;
    // greeting them by the app's name reads as deliberate rather than broken.
    return AuthService.isGuest ? 'Welcome' : 'there';
  }

  void _navigateToCourse(Map<String, dynamic> course) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      AppRouter.push(
        CourseDetailScreen(
          courseId: (course['id'] as String?) ?? '',
          title: displayTitle((course['id'] as String?) ?? ''),
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
                await signOutToWelcome(context);
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
                    Icon(CupertinoIcons.square_arrow_left,
                        color: AppColors.red, size: 18),
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
      case 'Binary Network Pro':
        return CupertinoIcons.wifi;
      case 'Binary Cyber Pro':
        return CupertinoIcons.shield_fill;
      case 'Binary Cloud':
        return CupertinoIcons.cloud_fill;
      case 'Binary Cloud Pro':
        return CupertinoIcons.cloud_upload_fill;
      case 'Binary AI':
        return CupertinoIcons.sparkles;
      default:
        return CupertinoIcons.book_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isWide = kIsWeb && MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 900 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.all(isWide ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 24),
                    _buildLearningHero(theme),
                    if (!_hasFullAccess) ...[
                      const SizedBox(height: 16),
                      _buildUpgradeCard(theme),
                    ],
                    const SizedBox(height: 24),
                    _buildStudyPulse(theme),
                    const SizedBox(height: 28),
                    _buildReviewCard(theme),
                    _buildSectionTitle('Your courses', theme),
                    const SizedBox(height: 12),
                    _buildEnrolledCourses(theme, isWide: isWide),
                    SizedBox(height: isWide ? 36 : 28),
                    _buildSectionTitle('Your progress', theme),
                    const SizedBox(height: 12),
                    _buildStatsRow(theme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Refreshed on every return to the tab, since a quiz taken elsewhere in the
  /// app changes the queue without this screen rebuilding on its own.
  Future<void> _loadReviewQueue() async {
    final due = await ReviewService.dueCount();
    final label = await ReviewService.nextDueLabel();
    if (!mounted) return;
    setState(() {
      _reviewDue = due;
      _reviewNextLabel = label;
    });
  }

  /// The review entry point. Hidden entirely until the user has actually
  /// missed something, so a new account is not shown an empty feature.
  /// Opens the paywall with every plan shown.
  void _openPaywall() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const PaywallScreen(
          courseTitle: 'B1nary',
          courseColor: AppColors.primary,
          defaultToAllPlans: true,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _browseCourses() {
    if (widget.onBrowseCourses != null) {
      widget.onBrowseCourses!();
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Course library')),
                  body: const CoursesScreen(),
                )));
  }

  Widget _buildLearningHero(ThemeNotifier theme) {
    final continuing = _enrolledCourses
        .where((course) => course['progress'] < 1)
        .toList()
      ..sort((a, b) =>
          (b['progress'] as double).compareTo(a['progress'] as double));
    final course = continuing.isNotEmpty
        ? continuing.first
        : _allCourses.isNotEmpty
            ? _allCourses.first
            : null;
    final progress =
        course == null ? 0.0 : (_courseProgress[course['id']] ?? 0.0);
    return LearningHero(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      StudyLabel(
          continuing.isNotEmpty
              ? 'PICK UP WHERE YOU LEFT OFF'
              : 'YOUR NEXT CHAPTER',
          onDark: true,
          icon: Icons.auto_stories_rounded),
      const SizedBox(height: 22),
      Text(
          course == null
              ? 'Make room for\na new skill.'
              : displayTitle(course['id'] as String),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w700,
              height: 1.22,
              letterSpacing: -.8)),
      const SizedBox(height: 12),
      Text(
          continuing.isNotEmpty
              ? 'Small steps add up. Your next lesson is waiting.'
              : 'Start with a free module and see what you can learn.',
          style: const TextStyle(
              color: Color(0xFFC4D3EB), fontSize: 14, height: 1.5)),
      if (continuing.isNotEmpty) ...[
        const SizedBox(height: 22),
        ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: .15),
                valueColor: const AlwaysStoppedAnimation(AppColors.mint))),
        const SizedBox(height: 8),
        Text('${(progress * 100).round()}% of course completed',
            style: const TextStyle(color: Color(0xFFC4D3EB), fontSize: 11)),
      ],
      const SizedBox(height: 22),
      FilledButton(
          onPressed: _loadingCourses
              ? null
              : course == null
                  ? _browseCourses
                  : () => _navigateToCourse(course),
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.mint,
              foregroundColor: AppColors.ink,
              disabledBackgroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: Text(
              _loadingCourses
                  ? 'Loading your courses…'
                  : continuing.isNotEmpty
                      ? 'Continue learning'
                      : course == null
                          ? 'Explore courses'
                          : 'Try a free lesson',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700))),
    ]));
  }

  Widget _buildUpgradeCard(ThemeNotifier theme) => Material(
      color: theme.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openPaywall,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.workspace_premium_outlined,
                  color: AppColors.primary, size: 23),
              const SizedBox(width: 12),
              Expanded(
                  child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: 'Go further with B1nary\n',
                            style: TextStyle(
                                color: theme.text,
                                fontWeight: FontWeight.w700)),
                        TextSpan(
                            text: 'View plans · One-time purchase',
                            style:
                                TextStyle(color: theme.subtext, fontSize: 12)),
                      ]),
                      style: const TextStyle(fontSize: 13, height: 1.5))),
              Icon(Icons.arrow_forward_rounded, color: theme.subtext, size: 19),
            ])),
      ));

  Widget _buildReviewCard(ThemeNotifier theme) {
    if (_reviewNextLabel == null) return const SizedBox.shrink();

    final ready = _reviewDue > 0;
    final accent = ready ? AppColors.indigo : theme.subtext;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: ready
            ? () async {
                await Navigator.of(context).push(
                  AppRouter.fade(const ReviewScreen()),
                );
                _loadReviewQueue();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ready
                  ? AppColors.indigo.withValues(alpha: 0.5)
                  : theme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(CupertinoIcons.arrow_2_circlepath,
                    color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready
                          ? '$_reviewDue question${_reviewDue == 1 ? "" : "s"} to review'
                          : 'All caught up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ready
                          ? 'Questions you missed, back on schedule'
                          : _reviewNextLabel!,
                      style: TextStyle(fontSize: 13, color: theme.subtext),
                    ),
                  ],
                ),
              ),
              if (ready)
                Icon(CupertinoIcons.chevron_right,
                    color: theme.subtext, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeNotifier theme) {
    final name = _getFirstName();
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_getGreeting(),
            style: TextStyle(fontSize: 13, color: theme.subtext)),
        const SizedBox(height: 5),
        Text(
            name == 'Welcome' || name == 'there'
                ? 'Ready to learn?'
                : 'Let’s learn, $name.',
            style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: theme.text,
                letterSpacing: -1,
                height: 1.2)),
      ])),
      const SizedBox(width: 12),
      IconButton.filledTonal(
          onPressed: () => _showSignOutSheet(theme),
          tooltip: 'Account options',
          style: IconButton.styleFrom(
              backgroundColor: theme.card, minimumSize: const Size(48, 48)),
          icon: Text(name.isNotEmpty ? name[0].toUpperCase() : 'B',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700))),
    ]);
  }

  Widget _buildStudyPulse(ThemeNotifier theme) {
    final target = _dailyTarget > 0 ? _dailyTarget : 50;
    final progress = (_dailyPoints / target).clamp(0.0, 1.0);
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StudyLabel('$_streak day${_streak == 1 ? '' : 's'} in a row',
                    icon: Icons.local_fire_department_rounded,
                    color: theme.isDark
                        ? AppColors.amber
                        : const Color(0xFFB96B08)),
                Text(progress >= 1 ? 'Daily goal complete' : 'Today’s momentum',
                    style: TextStyle(
                        color: theme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
          const SizedBox(height: 18),
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: theme.surface,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
          const SizedBox(height: 12),
          Text(
              '$_dailyPoints / $target points  ·  +10 per lesson  ·  +20 per quiz',
              style:
                  TextStyle(color: theme.subtext, fontSize: 12, height: 1.6)),
        ]));
  }

  Widget _buildEnrolledCourses(ThemeNotifier theme, {bool isWide = false}) {
    if (_loadingCourses) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    if (_enrolledCourses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          children: [
            Icon(CupertinoIcons.book_fill, size: 36, color: theme.subtext),
            const SizedBox(height: 14),
            Text('Make this space yours',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.text)),
            const SizedBox(height: 6),
            Text(
              'Save a course from the library and it will be waiting here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.subtext, height: 1.5),
            ),
          ],
        ),
      );
    }

    // Desktop: 2-column grid
    if (isWide && _enrolledCourses.length > 1) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.6,
        ),
        itemCount: _enrolledCourses.length,
        itemBuilder: (_, i) => _buildCourseCard(_enrolledCourses[i], theme),
      );
    }

    // Mobile: single column
    return Column(
      children: _enrolledCourses.map((c) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildCourseCard(c, theme),
        );
      }).toList(),
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
              child: Icon(_iconForTag(course['tag'] ?? ''),
                  color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayTitle(course['id'] as String? ?? ''),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(course['subtitle'] ?? '',
                      style: TextStyle(fontSize: 12, color: theme.subtext)),
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
                Text('${(progress * 100).toInt()}%',
                    style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Icon(CupertinoIcons.chevron_right,
                    size: 12, color: theme.subtext),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeNotifier theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: theme.text,
        letterSpacing: -.4,
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
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: theme.subtext, letterSpacing: 0.1)),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                      letterSpacing: -0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
