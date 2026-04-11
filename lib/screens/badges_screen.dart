import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  static const List<Map<String, dynamic>> _allBadges = [
    {
      'id': 'first_lesson',
      'title': 'First Step',
      'desc': 'Complete your first lesson',
      'icon': CupertinoIcons.star_fill,
      'color': 0xFFF59E0B,
    },
    {
      'id': 'streak_3',
      'title': '3-Day Streak',
      'desc': 'Study 3 days in a row',
      'icon': CupertinoIcons.flame_fill,
      'color': 0xFFEF4444,
    },
    {
      'id': 'streak_7',
      'title': 'Week Warrior',
      'desc': 'Study 7 days in a row',
      'icon': CupertinoIcons.flame_fill,
      'color': 0xFFFF6B00,
    },
    {
      'id': 'perfect_quiz',
      'title': 'Perfect Score',
      'desc': 'Get 100% on any quiz',
      'icon': CupertinoIcons.checkmark_seal_fill,
      'color': 0xFF10B981,
    },
    {
      'id': 'course_complete',
      'title': 'Graduate',
      'desc': 'Complete a full course',
      'icon': CupertinoIcons.rosette,
      'color': 0xFF6366F1,
    },
    {
      'id': 'quiz_5',
      'title': 'Quiz Master',
      'desc': 'Complete 5 quizzes',
      'icon': CupertinoIcons.doc_checkmark_fill,
      'color': 0xFF3B82F6,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: uid == null
                  ? const Center(
                      child: Text(
                        'Not signed in',
                        style: TextStyle(color: Colors.white54),
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
                        final earned = List<String>.from(
                          (data['badges'] as List<dynamic>?) ?? [],
                        );
                        return _buildGrid(earned);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 13,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Badges',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<String> earned) {
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
        final isEarned = earned.contains(badge['id']);
        final color = Color(badge['color'] as int);
        return _BadgeCard(badge: badge, color: color, isEarned: isEarned);
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Map<String, dynamic> badge;
  final Color color;
  final bool isEarned;

  const _BadgeCard({
    required this.badge,
    required this.color,
    required this.isEarned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isEarned
            ? color.withOpacity(0.08)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEarned
              ? color.withOpacity(0.25)
              : Colors.white.withOpacity(0.07),
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
                  ? color.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              badge['icon'] as IconData,
              color: isEarned ? color : Colors.white.withOpacity(0.2),
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
              color: isEarned ? Colors.white : Colors.white.withOpacity(0.3),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge['desc'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isEarned
                  ? Colors.white.withOpacity(0.4)
                  : Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 10),
          if (isEarned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Earned',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Locked',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
