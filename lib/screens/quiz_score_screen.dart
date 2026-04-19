import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class QuizScoreScreen extends StatelessWidget {
  const QuizScoreScreen({super.key});

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
                        if (snap.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          );
                        }
                        final data =
                            snap.data?.data() as Map<String, dynamic>? ?? {};
                        final scores = List<Map<String, dynamic>>.from(
                          (data['quizScores'] as List<dynamic>?)?.map(
                                (e) => Map<String, dynamic>.from(e as Map),
                              ) ??
                              [],
                        );
                        return _buildContent(scores, theme);
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Quiz Scores',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: theme.text,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> scores, ThemeNotifier theme) {
    if (scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.track_changes_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No quizzes taken yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete a lesson to unlock quizzes',
              style: TextStyle(
                fontSize: 13,
                color: theme.subtext,
              ),
            ),
          ],
        ),
      );
    }

    final avg = scores.fold<double>(
          0,
          (sum, s) => sum + ((s['score'] as num?) ?? 0).toDouble(),
        ) /
        scores.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Avg Score',
                  '${avg.toStringAsFixed(0)}%',
                  AppColors.primary,
                  theme,
                ),
              ),
              Container(width: 1, height: 40, color: theme.border),
              Expanded(
                child: _buildSummaryItem(
                  'Quizzes Taken',
                  '${scores.length}',
                  AppColors.green,
                  theme,
                ),
              ),
              Container(width: 1, height: 40, color: theme.border),
              Expanded(
                child: _buildSummaryItem(
                  'Best Score',
                  '${scores.map((s) => (s['score'] as num?) ?? 0).reduce((a, b) => a > b ? a : b)}%',
                  AppColors.amber,
                  theme,
                ),
              ),
            ],
          ),
        ),

        // Score rows
        ...List.generate(scores.length, (i) {
          final score = scores[scores.length - 1 - i];
          final pct = ((score['score'] as num?) ?? 0).toInt();
          final title = score['quizTitle'] as String? ?? 'Quiz';
          final course = score['course'] as String? ?? '';
          final takenAt = (score['takenAt'] as Timestamp?)?.toDate();
          final color = pct >= 80
              ? AppColors.green
              : pct >= 60
                  ? AppColors.amber
                  : AppColors.red;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
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
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        course,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.subtext,
                        ),
                      ),
                    ],
                  ),
                ),
                if (takenAt != null)
                  Text(
                    _formatDate(takenAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.subtext,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryItem(
      String label, String value, Color color, ThemeNotifier theme) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: theme.subtext),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return '${date.month}/${date.day}';
  }
}
