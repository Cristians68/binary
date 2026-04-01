import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  List<_Course> _courses = [];
  bool _loading = true;

  static const _comingSoon = [
    _ComingSoon(title: 'CompTIA Security+', color: Color(0xFFEF4444)),
    _ComingSoon(title: 'CompTIA Network+', color: Color(0xFF3B82F6)),
    _ComingSoon(title: 'Cloud Fundamentals', color: Color(0xFF06B6D4)),
    _ComingSoon(title: 'Cybersecurity Basics', color: Color(0xFF8B5CF6)),
  ];

  @override
  void initState() {
    super.initState();
    _loadCourses();
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
          color: Color(data['color'] ?? 0xFF6366F1),
          progress: (data['progress'] ?? 0.0).toDouble(),
          isComingSoon: data['isComingSoon'] ?? false,
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

  void _openCourse(BuildContext context, _Course course) {
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
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
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
      case 'Slack':
        return CupertinoIcons.chat_bubble_2_fill;
      default:
        return CupertinoIcons.book_fill;
    }
  }

  IconData _iconForComingSoon(String title) {
    if (title.contains('Security')) return CupertinoIcons.lock_shield_fill;
    if (title.contains('Network')) return CupertinoIcons.wifi;
    if (title.contains('Cloud')) return CupertinoIcons.cloud_fill;
    if (title.contains('Cyber')) return CupertinoIcons.shield_fill;
    return CupertinoIcons.book_fill;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableCourses =
        _courses.where((c) => !c.isComingSoon).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeader(),
          _buildSearchBar(),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6366F1),
                  strokeWidth: 2,
                ),
              ),
            )
          else ...[
            _buildSectionLabel('Available now'),
            if (availableCourses.isNotEmpty)
              _buildFeaturedCourse(context, availableCourses.first),
            if (availableCourses.length > 1)
              _buildCourseList(
                  context, availableCourses.skip(1).toList()),
            _buildSectionLabel('Coming soon'),
            _buildComingSoonList(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Courses',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1.2,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Everything you need to get certified.',
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.white.withOpacity(0.45),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  color: Colors.white.withOpacity(0.3), size: 20),
              const SizedBox(width: 12),
              Text(
                'Search courses...',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.3),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 14),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.35),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCourse(BuildContext context, _Course course) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _AnimatedCard(
          delay: Duration.zero,
          child: GestureDetector(
            onTap: () => _openCourse(context, course),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: course.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: course.color.withOpacity(0.3)),
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
                          color: course.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(_iconForTag(course.tag),
                            color: course.color, size: 26),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: course.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: course.color.withOpacity(0.3)),
                        ),
                        child: Text(
                          course.progress > 0 ? 'IN PROGRESS' : 'START',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: course.color,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: course.progress,
                            backgroundColor:
                                Colors.white.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                course.color),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(course.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          color: course.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: course.color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        course.progress > 0
                            ? 'Continue learning'
                            : 'Start course',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
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

  Widget _buildCourseList(
      BuildContext context, List<_Course> courses) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final course = courses[index];
          return _AnimatedCard(
            delay: Duration(milliseconds: 80 * (index + 1)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: GestureDetector(
                onTap: () => _openCourse(context, course),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: course.color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: course.color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: course.color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_iconForTag(course.tag),
                            color: course.color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              course.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: course.progress,
                                backgroundColor:
                                    Colors.white.withOpacity(0.08),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        course.color),
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
                            '${(course.progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: course.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.25)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: courses.length,
      ),
    );
  }

  Widget _buildComingSoonList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _comingSoon[index];
            return _AnimatedCard(
              delay: Duration(milliseconds: 60 * index),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: item.color.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_iconForComingSoon(item.title),
                            color: item.color, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.5),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Soon',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: item.color.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: _comingSoon.length,
        ),
      ),
    );
  }
}

// Scroll-reveal animation wrapper
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
    ).animate(CurvedAnimation(
        parent: _controller, curve: Curves.easeOutCubic));
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
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// Data classes
class _Course {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final String tag;
  final double progress;
  final bool isComingSoon;

  const _Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.tag,
    required this.progress,
    required this.isComingSoon,
  });
}

class _ComingSoon {
  final String title;
  final Color color;

  const _ComingSoon({
    required this.title,
    required this.color,
  });
}