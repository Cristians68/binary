import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lesson_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final double progress;
  final Color color;
  final String tag;

  const CourseDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
    required this.tag,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modules = _getModules();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          _buildProgressBar(),
          _buildModuleList(context, modules),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // Background gradient
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withOpacity(0.22),
                  widget.color.withOpacity(0.04),
                  const Color(0xFF0A0A0F),
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Animated back button
                      _BackButton(
                        color: widget.color,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 32),
                      // Tag pill
                      _TagPill(tag: widget.tag, color: widget.color),
                      const SizedBox(height: 14),
                      // Title
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -1.2,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w400,
                        ),
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

  Widget _buildProgressBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your progress',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.35),
                    letterSpacing: -0.1,
                  ),
                ),
                Text(
                  '${(widget.progress * 100).toInt()}% complete',
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: widget.progress,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleList(
      BuildContext context, List<Map<String, dynamic>> modules) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _AnimatedModule(
              delay: Duration(milliseconds: 60 * index),
              child: _buildModuleCard(context, modules[index], index),
            );
          },
          childCount: modules.length,
        ),
      ),
    );
  }

  Widget _buildModuleCard(
      BuildContext context, Map<String, dynamic> module, int index) {
    final status = module['status'] as String;
    final isLocked = status == 'locked';
    final isDone = status == 'done';
    final isActive = status == 'active';

    final statusColor = isLocked
        ? Colors.white.withOpacity(0.15)
        : isDone
            ? const Color(0xFF10B981)
            : widget.color;

    return GestureDetector(
      onTap: isLocked
          ? null
          : () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, animation, __) => LessonScreen(
                    moduleTitle: module['title'],
                    courseTag: widget.tag,
                    color: widget.color,
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
                      child:
                          FadeTransition(opacity: animation, child: child),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isActive
              ? widget.color.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? widget.color.withOpacity(0.3)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isDone
                    ? Icon(Icons.check_rounded, size: 18, color: statusColor)
                    : isLocked
                        ? Icon(Icons.lock_outline_rounded,
                            size: 15, color: statusColor)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module['title'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isLocked
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    module['sub'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isDone)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981).withOpacity(0.9),
                  ),
                ),
              )
            else if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              )
            else
              Icon(Icons.lock_outline_rounded,
                  size: 14, color: Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getModules() {
    if (widget.tag == 'ITIL V4') {
      return [
        {'title': 'What is ITIL?', 'sub': '5 flashcards · quiz', 'status': 'done'},
        {'title': 'Key Concepts', 'sub': '6 flashcards · quiz', 'status': 'done'},
        {'title': 'Service Value System', 'sub': '8 flashcards · quiz', 'status': 'active'},
        {'title': '4 Dimensions Model', 'sub': '5 flashcards · quiz', 'status': 'locked'},
        {'title': 'Guiding Principles', 'sub': '7 flashcards · quiz', 'status': 'locked'},
        {'title': 'Practices Overview', 'sub': '6 flashcards · quiz', 'status': 'locked'},
        {'title': 'Final Quiz', 'sub': '20 questions', 'status': 'locked'},
      ];
    } else if (widget.tag == 'CSM') {
      return [
        {'title': 'What is Scrum?', 'sub': '5 flashcards · quiz', 'status': 'active'},
        {'title': 'The Scrum Team', 'sub': '6 flashcards · quiz', 'status': 'locked'},
        {'title': 'Scrum Events', 'sub': '5 flashcards · quiz', 'status': 'locked'},
        {'title': 'Scrum Artifacts', 'sub': '4 flashcards · quiz', 'status': 'locked'},
        {'title': 'Definition of Done', 'sub': '3 flashcards · quiz', 'status': 'locked'},
        {'title': 'Final Quiz', 'sub': '20 questions', 'status': 'locked'},
      ];
    } else {
      return [
        {'title': 'What is a Network?', 'sub': '5 flashcards · quiz', 'status': 'active'},
        {'title': 'IP Addresses', 'sub': '6 flashcards · quiz', 'status': 'locked'},
        {'title': 'DNS & Routing', 'sub': '5 flashcards · quiz', 'status': 'locked'},
        {'title': 'TCP/IP Deep Dive', 'sub': '7 flashcards · quiz', 'status': 'locked'},
        {'title': 'Subnetting', 'sub': '6 flashcards · quiz', 'status': 'locked'},
        {'title': 'Network Security', 'sub': '5 flashcards · quiz', 'status': 'locked'},
        {'title': 'Final Quiz', 'sub': '20 questions', 'status': 'locked'},
      ];
    }
  }
}

// Animated back button with press scale effect
class _BackButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const _BackButton({required this.color, required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 13,
                color: widget.color,
              ),
              const SizedBox(width: 5),
              Text(
                'Courses',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.color,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tag pill with fade-in animation
class _TagPill extends StatefulWidget {
  final String tag;
  final Color color;

  const _TagPill({required this.tag, required this.color});

  @override
  State<_TagPill> createState() => _TagPillState();
}

class _TagPillState extends State<_TagPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    Future.delayed(const Duration(milliseconds: 150), () {
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
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withOpacity(0.25)),
          ),
          child: Text(
            widget.tag.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.color,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// Scroll-reveal animation wrapper for modules
class _AnimatedModule extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedModule({required this.child, this.delay = Duration.zero});

  @override
  State<_AnimatedModule> createState() => _AnimatedModuleState();
}

class _AnimatedModuleState extends State<_AnimatedModule>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
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
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}