import 'package:flutter/material.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Progress', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Your learning journey', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4))),
              const SizedBox(height: 24),
              _buildOverallProgress(),
              const SizedBox(height: 24),
              _buildSectionTitle('Course breakdown'),
              const SizedBox(height: 12),
              _buildProgressBar('ITIL V4 Foundation', 0.35, const Color(0xFF6366F1)),
              const SizedBox(height: 10),
              _buildProgressBar('CSM Fundamentals', 0.10, const Color(0xFF10B981)),
              const SizedBox(height: 10),
              _buildProgressBar('Networking Basics', 0.05, const Color(0xFFF59E0B)),
              const SizedBox(height: 24),
              _buildSectionTitle('Badges earned'),
              const SizedBox(height: 12),
              _buildBadges(),
              const SizedBox(height: 24),
              _buildSectionTitle('Recent activity'),
              const SizedBox(height: 12),
              _buildActivity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.4), letterSpacing: 0.8));
  }

  Widget _buildOverallProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80, height: 80,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: 0.17,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  strokeWidth: 7,
                ),
                const Center(
                  child: Text('17%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall progress', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text('12 lessons completed', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                const SizedBox(height: 4),
                Text('3 badges earned', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                const SizedBox(height: 4),
                Text('7 day streak 🔥', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
              Text('${(value * 100).toInt()}%', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadges() {
    final badges = [
      {'icon': '🏆', 'label': 'First lesson', 'color': const Color(0xFFF59E0B)},
      {'icon': '🔥', 'label': '7 day streak', 'color': const Color(0xFFEF4444)},
      {'icon': '🎯', 'label': 'Quiz master', 'color': const Color(0xFF6366F1)},
    ];

    return Row(
      children: badges.map((badge) {
        final color = badge['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Text(badge['icon'] as String, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(badge['label'] as String, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivity() {
    final activities = [
      {'icon': '📖', 'text': 'Completed: Key Concepts', 'time': '2h ago', 'color': const Color(0xFF6366F1)},
      {'icon': '✅', 'text': 'Quiz passed: SVS Module', 'time': 'Yesterday', 'color': const Color(0xFF10B981)},
      {'icon': '🔥', 'text': 'Streak reached 7 days', 'time': '2 days ago', 'color': const Color(0xFFF59E0B)},
      {'icon': '🏆', 'text': 'Badge earned: First lesson', 'time': '3 days ago', 'color': const Color(0xFFEC4899)},
    ];

    return Column(
      children: activities.map((a) {
        final color = a['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(a['icon'] as String, style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(a['text'] as String, style: const TextStyle(fontSize: 13, color: Colors.white))),
              Text(a['time'] as String, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35))),
            ],
          ),
        );
      }).toList(),
    );
  }
}