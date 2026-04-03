import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'course_detail_screen.dart';
import 'app_router.dart';

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
    _loadCourses();
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _iconForTag(String tag) {
    switch (tag) {
      case 'ITIL V4': return CupertinoIcons.doc_text_fill;
      case 'CSM': return CupertinoIcons.person_2_fill;
      case 'Networking': return CupertinoIcons.antenna_radiowaves_left_right;
      default: return CupertinoIcons.book_fill;
    }
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
              const Text('Progress',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1.2,
                    height: 1.05,
                  )),
              const SizedBox(height: 6),
              Text('Your learning journey.',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white.withOpacity(0.45),
                    letterSpacing: -0.2,
                  )),
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
                width: 88, height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 0.0,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6366F1)),
                      strokeWidth: 7,
                    ),
                    const Center(
                      child: Text('0%',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        )),
                    const SizedBox(height: 10),
                    _statRow(CupertinoIcons.checkmark_seal_fill,
                        '0 lessons completed', const Color(0xFF10B981)),
                    const SizedBox(height: 6),
                    _statRow(CupertinoIcons.rosette, '0 badges earned',
                        const Color(0xFFF59E0B)),
                    const SizedBox(height: 6),
                    _statRow(CupertinoIcons.flame_fill, '0 day streak',
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
        Text(text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: -0.1,
            )),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 14),
        child: Text(label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.35),
              letterSpacing: 1.2,
            )),
      ),
    );
  }

  Widget _buildCourseBreakdown() {
    if (_courses.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Text('No courses yet',
                style: TextStyle(
                    fontSize: 14, color: Colors.white.withOpacity(0.3))),
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
            final color = Color(course['color'] ?? 0xFF6366F1);
            final progress = (course['progress'] ?? 0.0).toDouble();
            final tag = course['tag'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    AppRouter.push(CourseDetailScreen(
                      title: course['title'] ?? '',
                      subtitle: course['subtitle'] ?? '',
                      progress: progress,
                      color: color,
                      tag: tag,
                    )),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_iconForTag(tag), color: color, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(course['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                )),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor:
                                    Colors.white.withOpacity(0.08),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text('${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: -0.3,
                          )),
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

  Widget _buildBadges() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            children: [
              Icon(CupertinoIcons.rosette,
                  size: 36, color: Colors.white.withOpacity(0.15)),
              const SizedBox(height: 12),
              Text('No badges yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.4),
                    letterSpacing: -0.3,
                  )),
              const SizedBox(height: 4),
              Text('Complete lessons to earn badges',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withOpacity(0.25))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivity() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            children: [
              Icon(CupertinoIcons.time,
                  size: 36, color: Colors.white.withOpacity(0.15)),
              const SizedBox(height: 12),
              Text('No activity yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.4),
                    letterSpacing: -0.3,
                  )),
              const SizedBox(height: 4),
              Text('Start a lesson to see your activity here',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withOpacity(0.25))),
            ],
          ),
        ),
      ),
    );
  }
}