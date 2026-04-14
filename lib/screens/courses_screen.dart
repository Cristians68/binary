import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_detail_screen.dart';
import 'app_router.dart';
import 'app_theme.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Map<String, dynamic>> _courses = [];
  Set<String> _enrolledIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final coursesSnap = await FirebaseFirestore.instance
          .collection('courses')
          .orderBy('order')
          .get();

      Set<String> enrolled = {};
      if (uid != null) {
        final userSnap =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = userSnap.data() ?? {};
        final enrolments = (data['enrolments'] as Map<String, dynamic>?) ?? {};
        enrolled = enrolments.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toSet();
      }

      if (mounted) {
        setState(() {
          _courses =
              coursesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _enrolledIds = enrolled;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleEnrolment(String courseId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    HapticFeedback.selectionClick();

    final isEnrolled = _enrolledIds.contains(courseId);

    // Optimistic update
    setState(() {
      if (isEnrolled) {
        _enrolledIds.remove(courseId);
      } else {
        _enrolledIds.add(courseId);
      }
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'enrolments': {courseId: !isEnrolled},
      }, SetOptions(merge: true));
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          if (isEnrolled) {
            _enrolledIds.add(courseId);
          } else {
            _enrolledIds.remove(courseId);
          }
        });
      }
    }
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
      default:
        return CupertinoIcons.book_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Courses',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enrol in courses to add them to your home screen.',
                    style: TextStyle(fontSize: 13, color: theme.subtext),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      itemCount: _courses.length,
                      itemBuilder: (context, i) {
                        final course = _courses[i];
                        final id = course['id'] as String;
                        final color = Color(course['color'] ?? 0xFF6366F1);
                        final isEnrolled = _enrolledIds.contains(id);

                        return _AnimatedCourseCard(
                          delay: Duration(milliseconds: 50 * i),
                          child: _buildCourseCard(
                            course: course,
                            color: color,
                            isEnrolled: isEnrolled,
                            theme: theme,
                            onEnrol: () => _toggleEnrolment(id),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                AppRouter.push(CourseDetailScreen(
                                  title: course['title'] ?? '',
                                  subtitle: course['subtitle'] ?? '',
                                  progress:
                                      (course['progress'] ?? 0.0).toDouble(),
                                  color: color,
                                  tag: course['tag'] ?? '',
                                )),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard({
    required Map<String, dynamic> course,
    required Color color,
    required bool isEnrolled,
    required ThemeNotifier theme,
    required VoidCallback onEnrol,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.isDark
              ? color.withValues(alpha: 0.07)
              : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.isDark
                ? color.withValues(alpha: isEnrolled ? 0.35 : 0.15)
                : isEnrolled
                    ? color.withValues(alpha: 0.3)
                    : AppColors.lightBorder,
            width: isEnrolled ? 1.5 : 1,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        course['tag'] ?? '',
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                    ],
                  ),
                ),
                if (isEnrolled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Enrolled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              course['subtitle'] ?? '',
              style: TextStyle(fontSize: 13, color: theme.subtext, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildCourseMeta(
                  theme,
                  CupertinoIcons.book_fill,
                  '${course['totalModules'] ?? 8} modules',
                  color,
                ),
                const SizedBox(width: 12),
                _buildCourseMeta(
                  theme,
                  CupertinoIcons.checkmark_seal_fill,
                  'Certificate',
                  color,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onEnrol,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isEnrolled ? theme.surface : color,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          isEnrolled ? Border.all(color: theme.border) : null,
                    ),
                    child: Text(
                      isEnrolled ? 'Unenrol' : 'Enrol',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isEnrolled ? theme.subtext : Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseMeta(
      ThemeNotifier theme, IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: theme.subtext, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _AnimatedCourseCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedCourseCard({required this.child, this.delay = Duration.zero});

  @override
  State<_AnimatedCourseCard> createState() => _AnimatedCourseCardState();
}

class _AnimatedCourseCardState extends State<_AnimatedCourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
