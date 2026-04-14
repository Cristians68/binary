import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'streak_service.dart';
import 'app_theme.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  List<Map<String, dynamic>> _lessons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      final stats = await StreakService.getStats();
      final raw = List<Map<String, dynamic>>.from(
        (stats['completedLessons'] as List<dynamic>? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );

      raw.sort((a, b) {
        final ta = (a['completedAt'] != null)
            ? (a['completedAt'] as dynamic).toDate() as DateTime
            : DateTime(0);
        final tb = (b['completedAt'] != null)
            ? (b['completedAt'] as dynamic).toDate() as DateTime
            : DateTime(0);
        return tb.compareTo(ta);
      });

      if (mounted) {
        setState(() {
          _lessons = raw;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return '';
      final dt = (timestamp as dynamic).toDate() as DateTime;
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Color _colorForTag(String tag) {
    switch (tag) {
      case 'Binary Network Pro':
        return const Color(0xFF3B82F6);
      case 'Binary Cyber Pro':
        return const Color(0xFFEF4444);
      case 'Binary Cloud':
        return const Color(0xFF06B6D4);
      case 'Binary Cloud Pro':
        return const Color(0xFF8B5CF6);
      case 'ITIL V4':
        return const Color(0xFFF59E0B);
      case 'CSM':
        return const Color(0xFF10B981);
      default:
        return AppColors.primary;
    }
  }

  IconData _iconForTag(String tag) {
    switch (tag) {
      case 'Binary Network Pro':
        return CupertinoIcons.wifi;
      case 'Binary Cyber Pro':
        return CupertinoIcons.shield_fill;
      case 'Binary Cloud':
        return CupertinoIcons.cloud_fill;
      case 'Binary Cloud Pro':
        return CupertinoIcons.cloud_upload_fill;
      case 'ITIL V4':
        return CupertinoIcons.doc_text_fill;
      case 'CSM':
        return CupertinoIcons.person_2_fill;
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 12,
                            color: AppColors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Completed Lessons',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (!_loading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_lessons.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.green,
                        strokeWidth: 2,
                      ),
                    )
                  : _lessons.isEmpty
                      ? _buildEmpty(theme)
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: _lessons.length,
                          itemBuilder: (context, index) {
                            final lesson = _lessons[index];
                            final tag =
                                (lesson['courseTag'] as String?) ?? 'Unknown';
                            final color = _colorForTag(tag);
                            final moduleTitle =
                                (lesson['moduleTitle'] as String?) ?? 'Lesson';
                            final date = _formatDate(lesson['completedAt']);

                            return _AnimatedItem(
                              delay: Duration(milliseconds: 40 * index),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.isDark
                                      ? color.withValues(alpha: 0.06)
                                      : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: theme.isDark
                                        ? color.withValues(alpha: 0.18)
                                        : AppColors.lightBorder,
                                  ),
                                  boxShadow: theme.isDark
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
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
                                        color: color.withValues(
                                          alpha: theme.isDark ? 0.15 : 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(
                                        _iconForTag(tag),
                                        color: color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            moduleTitle,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: theme.text,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            tag,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.subtext,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.green.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Done',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.green,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          date,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.subtext,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

  Widget _buildEmpty(ThemeNotifier theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                CupertinoIcons.book_fill,
                color: AppColors.green,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No lessons yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.text,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first lesson\nto see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.subtext,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedItem extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedItem({required this.child, this.delay = Duration.zero});

  @override
  State<_AnimatedItem> createState() => _AnimatedItemState();
}

class _AnimatedItemState extends State<_AnimatedItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
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
