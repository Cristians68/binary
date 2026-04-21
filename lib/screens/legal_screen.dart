import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
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
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 13, color: theme.subtext),
                          const SizedBox(width: 5),
                          Text('Back',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: theme.subtext,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Legal',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _LegalTile(
                    icon: CupertinoIcons.lock_shield_fill,
                    title: 'Privacy Policy',
                    subtitle: 'How we collect and use your data',
                    color: const Color(0xFF6366F1),
                    theme: theme,
                    onTap: () => _open('https://binaryacademy.app/privacy'),
                  ),
                  const SizedBox(height: 10),
                  _LegalTile(
                    icon: CupertinoIcons.doc_text_fill,
                    title: 'Terms of Service',
                    subtitle: 'Rules for using Binary Academy',
                    color: const Color(0xFF8B5CF6),
                    theme: theme,
                    onTap: () => _open('https://binaryacademy.app/terms'),
                  ),
                  const SizedBox(height: 10),
                  _LegalTile(
                    icon: CupertinoIcons.cart_fill,
                    title: 'Subscription Terms',
                    subtitle: 'Purchases, trials and refund policy',
                    color: const Color(0xFF10B981),
                    theme: theme,
                    onTap: () => _open(
                        'https://binaryacademy.app/terms#in-app-purchases'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Binary Academy\nVersion 1.0.0',
                style:
                    TextStyle(fontSize: 12, color: theme.subtext, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final ThemeNotifier theme;
  final VoidCallback onTap;

  const _LegalTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: theme.subtext)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: theme.subtext),
          ],
        ),
      ),
    );
  }
}
