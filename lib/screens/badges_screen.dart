import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  // ✅ IDs match exactly what StreakService and ProgressService award
  static const List<Map<String, dynamic>> _allBadges = [
    {
      'id': 'streak_7',
      'title': '7-Day Streak',
      'desc': 'Study 7 days in a row',
      'icon': CupertinoIcons.flame_fill,
      'color': 0xFFFF9500,
    },
    {
      'id': 'streak_30',
      'title': '30-Day Streak',
      'desc': 'Study 30 days in a row',
      'icon': CupertinoIcons.flame_fill,
      'color': 0xFFEF4444,
    },
    {
      'id': 'streak_100',
      'title': '100-Day Streak',
      'desc': 'Study 100 days in a row',
      'icon': CupertinoIcons.flame_fill,
      'color': 0xFF6366F1,
    },
    {
      'id': 'quiz_first',
      'title': 'Quiz Starter',
      'desc': 'Pass your first quiz',
      'icon': CupertinoIcons.checkmark_seal_fill,
      'color': 0xFF10B981,
    },
    {
      'id': 'quiz_perfect',
      'title': 'Perfectionist',
      'desc': 'Score 100% on any quiz',
      'icon': CupertinoIcons.star_fill,
      'color': 0xFFF59E0B,
    },
    {
      'id': 'quiz_10',
      'title': 'Quiz Master',
      'desc': 'Pass 10 quizzes',
      'icon': CupertinoIcons.doc_checkmark_fill,
      'color': 0xFF3B82F6,
    },
    {
      'id': 'course_first',
      'title': 'Graduate',
      'desc': 'Complete your first course',
      'icon': CupertinoIcons.rosette,
      'color': 0xFF8B5CF6,
    },
    {
      'id': 'course_3',
      'title': 'Triple Threat',
      'desc': 'Complete 3 courses',
      'icon': CupertinoIcons.rosette,
      'color': 0xFF0071E3,
    },
    {
      'id': 'course_all',
      'title': 'Master',
      'desc': 'Complete all courses',
      'icon': CupertinoIcons.rosette,
      'color': 0xFF1DB954,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: uid == null
                  ? Center(
                      child: Text(
                        'Not signed in',
                        style: TextStyle(color: theme.subtext),
                      ),
                    )
                  : StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final data =
                            snap.data?.data() as Map<String, dynamic>? ?? {};

                        // ✅ badges is stored as a MAP {badgeId: Timestamp}
                        // not a List — read keys from the map
                        final badgesRaw = data['badges'];
                        Set<String> earnedIds = {};
                        if (badgesRaw is Map) {
                          earnedIds = badgesRaw.keys
                              .map((k) => k.toString())
                              .toSet();
                        }

                        return _buildGrid(earnedIds, theme);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeNotifier theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded,
                      size: 13, color: AppColors.amber),
                  const SizedBox(width: 5),
                  Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Badges',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: theme.text,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          // Earned count badge
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                .snapshots(),
            builder: (context, snap) {
              final data =
                  snap.data?.data() as Map<String, dynamic>? ?? {};
              final badgesRaw = data['badges'];
              int count = 0;
              if (badgesRaw is Map) count = badgesRaw.length;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count / ${_allBadges.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amber,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(Set<String> earnedIds, ThemeNotifier theme) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _allBadges.length,
      itemBuilder: (context, index) {
        final badge = _allBadges[index];
        final isEarned = earnedIds.contains(badge['id'] as String);
        final color = Color(badge['color'] as int);
        return _BadgeCard(
          badge: badge,
          color: color,
          isEarned: isEarned,
          theme: theme,
        );
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Map<String, dynamic> badge;
  final Color color;
  final bool isEarned;
  final ThemeNotifier theme;

  const _BadgeCard({
    required this.badge,
    required this.color,
    required this.isEarned,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isEarned
            ? color.withValues(alpha: 0.08)
            : theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEarned
              ? color.withValues(alpha: 0.25)
              : theme.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isEarned
                  ? color.withValues(alpha: 0.15)
                  : theme.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              badge['icon'] as IconData,
              color: isEarned ? color : theme.subtext,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            badge['title'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isEarned ? theme.text : theme.subtext,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge['desc'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: theme.subtext),
          ),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isEarned
                  ? color.withValues(alpha: 0.15)
                  : theme.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isEarned ? 'Earned ✓' : 'Locked',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isEarned ? color : theme.subtext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
