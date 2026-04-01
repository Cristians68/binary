import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeader(),
              _buildOverallProgress(),
              _buildSectionLabel('Course breakdown'),
              _buildCourseBreakdown(),
              _buildSectionLabel('Badges earned'),
              _buildBadges(),
              _buildSectionLabel('Recent activity'),
              _buildActivity(),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
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
                'Progress',
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
                'Your learning journey.',
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

  Widget _buildOverallProgress() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.25)),
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
                      value: 0.17,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6366F1)),
                      strokeWidth: 7,
                    ),
                    const Center(
                      child: Text(
                        '17%',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                    const Text(
                      'Overall progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _statRow(CupertinoIcons.checkmark_seal_fill,
                        '12 lessons completed',
                        const Color(0xFF10B981)),
                    const SizedBox(height: 6),
                    _statRow(CupertinoIcons.rosette, '3 badges earned',
                        const Color(0xFFF59E0B)),
                    const SizedBox(height: 6),
                    _statRow(CupertinoIcons.flame_fill, '7 day streak',
                        const Color(0xFFEF4444)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 14),
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

  Widget _buildCourseBreakdown() {
    final courses = [
      ('ITIL V4 Foundation', 0.35, const Color(0xFF6366F1),
          CupertinoIcons.doc_text_fill),
      ('CSM Fundamentals', 0.10, const Color(0xFF10B981),
          CupertinoIcons.person_2_fill),
      ('Networking Basics', 0.05, const Color(0xFFF59E0B),
          CupertinoIcons.antenna_radiowaves_left_right),
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final course = courses[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: course.$3.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: course.$3.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: course.$3.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(course.$4,
                          color: course.$3, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.$1,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: course.$2,
                              backgroundColor:
                                  Colors.white.withOpacity(0.08),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      course.$3),
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${(course.$2 * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: course.$3,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: courses.length,
        ),
      ),
    );
  }

  Widget _buildBadges() {
    final badges = [
      ('First lesson', CupertinoIcons.star_fill,
          const Color(0xFFF59E0B)),
      ('7 day streak', CupertinoIcons.flame_fill,
          const Color(0xFFEF4444)),
      ('Quiz master', Icons.track_changes_rounded,
          const Color(0xFF6366F1)),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: badges.asMap().entries.map((entry) {
            final badge = entry.value;
            final isLast = entry.key == badges.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: badge.$3.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: badge.$3.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: badge.$3.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(badge.$2,
                            color: badge.$3, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        badge.$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActivity() {
    final activities = [
      (CupertinoIcons.book_fill, 'Completed: Key Concepts',
          '2h ago', const Color(0xFF6366F1)),
      (CupertinoIcons.checkmark_seal_fill, 'Quiz passed: SVS Module',
          'Yesterday', const Color(0xFF10B981)),
      (CupertinoIcons.flame_fill, 'Streak reached 7 days',
          '2 days ago', const Color(0xFFF59E0B)),
      (CupertinoIcons.rosette, 'Badge earned: First lesson',
          '3 days ago', const Color(0xFFEC4899)),
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final a = activities[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.07)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: a.$4.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child:
                          Icon(a.$1, color: a.$4, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        a.$2,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Text(
                      a.$3,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: activities.length,
        ),
      ),
    );
  }
}