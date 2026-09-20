import 'package:flutter/material.dart';

import '../content_source.dart';
import 'app_theme.dart';

class ContentUnavailableScreen extends StatelessWidget {
  const ContentUnavailableScreen({
    super.key,
    required this.title,
    required this.color,
    required this.onRetry,
    this.onPractice,
  });

  final String title;
  final Color color;
  final VoidCallback onRetry;
  final VoidCallback? onPractice;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bg,
        foregroundColor: theme.text,
        title: Text(title),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: color),
                const SizedBox(height: 20),
                Text('Let’s try that again',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: theme.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                    'This module could not be loaded. Check your connection '
                    'and course access, then try again. Your progress is safe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.subtext, height: 1.5)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(backgroundColor: color),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                if (onPractice != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: onPractice,
                      child: const Text('Practice with a sample')),
                  Text(
                      'Sample practice does not count toward course completion.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.subtext, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContentNotice extends StatelessWidget {
  const ContentNotice({super.key, required this.origin});

  final ContentOrigin origin;

  @override
  Widget build(BuildContext context) {
    if (origin == ContentOrigin.live) return const SizedBox.shrink();
    final theme = AppTheme.of(context);
    final sample = origin == ContentOrigin.substitute;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
            sample
                ? 'Sample practice · Progress and certificates are not awarded.'
                : 'Saved copy · You’re studying previously loaded content.',
            style: TextStyle(color: theme.text, fontSize: 12, height: 1.4)),
      ),
    );
  }
}
