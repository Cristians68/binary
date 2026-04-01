import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildAvatar(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildSection('Account', [
                _buildSettingsItem(Icons.person_outline, 'Edit profile', const Color(0xFF6366F1)),
                _buildSettingsItem(Icons.notifications_outlined, 'Notifications', const Color(0xFF6366F1)),
                _buildSettingsItem(Icons.lock_outline, 'Change password', const Color(0xFF6366F1)),
              ]),
              const SizedBox(height: 16),
              _buildSection('Learning', [
                _buildSettingsItem(Icons.bar_chart, 'My stats', const Color(0xFF10B981)),
                _buildSettingsItem(Icons.emoji_events_outlined, 'Badges', const Color(0xFF10B981)),
                _buildSettingsItem(Icons.download_outlined, 'Download for offline', const Color(0xFF10B981)),
              ]),
              const SizedBox(height: 16),
              _buildSection('Support', [
                _buildSettingsItem(Icons.help_outline, 'Help center', const Color(0xFFF59E0B)),
                _buildSettingsItem(Icons.feedback_outlined, 'Send feedback', const Color(0xFFF59E0B)),
                _buildSettingsItem(Icons.info_outline, 'About Binary', const Color(0xFFF59E0B)),
              ]),
              const SizedBox(height: 24),
              _buildSignOut(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: const Color(0xFF6366F1),
          child: const Text('JD', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        const Text('John Doe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text('IT Learner · Level 2', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4))),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatItem('12', 'Lessons'),
        _buildDivider(),
        _buildStatItem('3', 'Badges'),
        _buildDivider(),
        _buildStatItem('7', 'Day streak'),
        _buildDivider(),
        _buildStatItem('84%', 'Avg score'),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 0.5, height: 30, color: Colors.white.withOpacity(0.1));
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.4), letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white))),
          Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white.withOpacity(0.25)),
        ],
      ),
    );
  }

  Widget _buildSignOut() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
      ),
      child: const Text('Sign out', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
    );
  }
}