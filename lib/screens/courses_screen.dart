import 'package:flutter/material.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  static const _courses = [
    _Course(
      title: 'ITIL V4 Foundation',
      subtitle: '7 modules · Service management',
      icon: '📋',
      color: Color(0xFF6366F1),
      tag: 'ITIL V4',
      progress: 0.35,
    ),
    _Course(
      title: 'CSM Fundamentals',
      subtitle: '6 modules · Scrum & agile',
      icon: '🤝',
      color: Color(0xFF10B981),
      tag: 'CSM',
      progress: 0.10,
    ),
    _Course(
      title: 'Networking Basics',
      subtitle: '8 modules · TCP/IP, DNS, subnets',
      icon: '🌐',
      color: Color(0xFFF59E0B),
      tag: 'Networking',
      progress: 0.05,
    ),
    _Course(
      title: 'Slack for IT Teams',
      subtitle: '4 modules · Collaboration tools',
      icon: '💬',
      color: Color(0xFFEC4899),
      tag: 'Slack',
      progress: 0.0,
    ),
  ];

  static const _comingSoon = [
    _ComingSoon(title: 'CompTIA Security+', icon: '🔐', color: Color(0xFFEF4444)),
    _ComingSoon(title: 'CompTIA Network+', icon: '🌐', color: Color(0xFF3B82F6)),
    _ComingSoon(title: 'Cloud Fundamentals', icon: '☁️', color: Color(0xFF06B6D4)),
    _ComingSoon(title: 'Cybersecurity Basics', icon: '🛡️', color: Color(0xFF8B5CF6)),
  ];

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeader(),
          _buildSearchBar(),
          _buildSectionLabel('Available now'),
          _buildFeaturedCourse(context, _courses.first),
          _buildCourseList(context),
          _buildSectionLabel('Coming soon'),
          _buildComingSoonGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
              Text(
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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

  // Large featured card for the first course
  Widget _buildFeaturedCourse(BuildContext context, _Course course) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _AnimatedCard(
          delay: const Duration(milliseconds: 0),
          child: GestureDetector(
            onTap: () => _openCourse(context, course),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: course.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: course.color.withOpacity(0.3)),
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
                        child: Center(
                          child: Text(course.icon,
                              style: const TextStyle(fontSize: 26)),
                        ),
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
                          'IN PROGRESS',
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
                            backgroundColor: Colors.white.withOpacity(0.08),
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
                    child: const Center(
                      child: Text(
                        'Continue learning',
                        style: TextStyle(
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

  // Remaining courses as compact cards
  Widget _buildCourseList(BuildContext context) {
    final rest = _courses.skip(1).toList();
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final course = rest[index];
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
                        child: Center(
                          child: Text(course.icon,
                              style: const TextStyle(fontSize: 22)),
                        ),
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
        childCount: rest.length,
      ),
    );
  }

  Widget _buildComingSoonGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _comingSoon[index];
            return _AnimatedCard(
              delay: Duration(milliseconds: 60 * index),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: item.color.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.icon,
                        style: const TextStyle(fontSize: 26)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.5),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Coming soon',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: item.color.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// Data classes
class _Course {
  final String title;
  final String subtitle;
  final String icon;
  final Color color;
  final String tag;
  final double progress;

  const _Course({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tag,
    required this.progress,
  });
}

class _ComingSoon {
  final String title;
  final String icon;
  final Color color;

  const _ComingSoon({
    required this.title,
    required this.icon,
    required this.color,
  });
}