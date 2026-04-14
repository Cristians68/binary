import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'streak_service.dart';
import 'app_theme.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen>
    with SingleTickerProviderStateMixin {
  late Future<({StreakData streak, DailyGoalData goal, List<BadgeData> badges})>
      _future;
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
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _future = StreakService.fetchAll();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = StreakService.fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  );
                }

                final data = snap.data;
                if (data == null) {
                  return Center(
                    child: Text(
                      'Could not load data.',
                      style: TextStyle(color: theme.subtext),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 24),
                    _buildStreakCard(theme, data.streak),
                    const SizedBox(height: 16),
                    _buildDailyGoalCard(theme, data.goal),
                    const SizedBox(height: 28),
                    _buildBadgesSection(theme, data.badges),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeNotifier theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Progress',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: theme.text,
            letterSpacing: -1.0,
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _showGoalEditor(theme);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.slider_horizontal_3,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  'Goal',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Streak card ────────────────────────────────────────────────────────────
  Widget _buildStreakCard(ThemeNotifier theme, StreakData streak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Daily Streak',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStreakStat(
                  theme,
                  '${streak.current}',
                  'Current',
                  const Color(0xFFF97316),
                ),
              ),
              Container(width: 1, height: 48, color: theme.border),
              Expanded(
                child: _buildStreakStat(
                  theme,
                  '${streak.longest}',
                  'Longest',
                  AppColors.primary,
                ),
              ),
              Container(width: 1, height: 48, color: theme.border),
              Expanded(
                child: _buildStreakStat(
                  theme,
                  _streakStatus(streak),
                  'Today',
                  AppColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _streakStatus(StreakData streak) {
    if (streak.lastLogin == null) return '—';
    final now = DateTime.now();
    final last = streak.lastLogin!;
    final isToday =
        last.year == now.year && last.month == now.month && last.day == now.day;
    return isToday ? '✓' : '—';
  }

  Widget _buildStreakStat(
      ThemeNotifier theme, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: theme.subtext),
        ),
      ],
    );
  }

  // ── Daily goal card ────────────────────────────────────────────────────────
  Widget _buildDailyGoalCard(ThemeNotifier theme, DailyGoalData goal) {
    final pct = (goal.progress.clamp(0.0, 1.0));
    final color = goal.isComplete ? AppColors.green : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Goal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  goal.isComplete
                      ? 'Complete! 🎉'
                      : '${goal.todayPoints} / ${goal.target} pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: theme.isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPointPill(theme, '📖', '+10', 'per lesson'),
              const SizedBox(width: 8),
              _buildPointPill(theme, '✅', '+20', 'per quiz'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointPill(
      ThemeNotifier theme, String emoji, String pts, String label) {
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
            '$pts $label',
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

  // ── Badges section ─────────────────────────────────────────────────────────
  Widget _buildBadgesSection(ThemeNotifier theme, List<BadgeData> badges) {
    final earned = badges.where((b) => b.isEarned).toList();
    final locked = badges.where((b) => !b.isEarned).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Badges',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.text,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '${earned.length} / ${badges.length}',
              style: TextStyle(fontSize: 13, color: theme.subtext),
            ),
          ],
        ),
        if (earned.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Earned',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.subtext,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 10),
          _buildBadgeGrid(theme, earned, unlocked: true),
        ],
        const SizedBox(height: 20),
        Text(
          'Locked',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.subtext,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 10),
        _buildBadgeGrid(theme, locked, unlocked: false),
      ],
    );
  }

  Widget _buildBadgeGrid(ThemeNotifier theme, List<BadgeData> badges,
      {required bool unlocked}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: badges.length,
      itemBuilder: (context, i) => _buildBadgeTile(theme, badges[i], unlocked),
    );
  }

  Widget _buildBadgeTile(ThemeNotifier theme, BadgeData badge, bool unlocked) {
    final color = unlocked ? _badgeColor(badge.category) : theme.subtext;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showBadgeDetail(theme, badge, unlocked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked ? color.withOpacity(0.08) : theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked ? color.withOpacity(0.25) : theme.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              unlocked ? badge.emoji : '🔒',
              style: TextStyle(
                fontSize: 28,
                color: unlocked ? null : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: unlocked ? theme.text : theme.subtext,
                letterSpacing: -0.1,
              ),
            ),
            if (unlocked && badge.earnedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(badge.earnedAt!),
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _badgeColor(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.streak:
        return const Color(0xFFF97316);
      case BadgeCategory.course:
        return AppColors.primary;
      case BadgeCategory.quiz:
        return AppColors.green;
    }
  }

  void _showBadgeDetail(ThemeNotifier theme, BadgeData badge, bool unlocked) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text('${badge.emoji} ${badge.title}'),
        message: Text(
          unlocked
              ? '${badge.description}\n\nEarned ${badge.earnedAt != null ? _formatDate(badge.earnedAt!) : ''}'
              : badge.description,
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
    );
  }

  void _showGoalEditor(ThemeNotifier theme) {
    int selected = 50;
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Set Daily Goal'),
        message: const Text('Choose your daily point target'),
        actions: [30, 50, 80, 100, 150].map((pts) {
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await StreakService.setDailyTarget(pts);
              _refresh();
            },
            child: Text('$pts points per day'),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
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
    return '${date.day}/${date.month}/${date.year}';
  }
}
