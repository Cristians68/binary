import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../course_catalog.dart';
import '../credential.dart';
import 'app_router.dart';
import 'app_theme.dart';
import 'certificate_screen.dart';
import 'streak_service.dart';

/// Every certificate the learner has earned, and the credential on each.
///
/// WHY THIS EXISTS
/// ---------------
/// A certificate was reachable from exactly one place: the moment immediately
/// after passing the last quiz of a course. Backing out of that screen — or
/// closing the app — lost it permanently. There was no list, no history, and no
/// way to see the credential again, which makes "you get a certificate" a
/// claim the app did not actually honour.
///
/// Completion is read through [StreakService.completedCourseIds], which unions
/// the current `completedCourses` array with the legacy `badges.complete_<id>`
/// keys, so accounts that finished a course before that migration still see
/// their certificates here.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _EarnedCertificate {
  const _EarnedCertificate({
    required this.courseId,
    required this.title,
    required this.credentialId,
    this.completedAt,
  });

  final String courseId;
  final String title;
  final String credentialId;
  final DateTime? completedAt;
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  StreamSubscription<Map<String, dynamic>>? _statsSub;
  List<_EarnedCertificate> _certificates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // A live subscription rather than a one-shot read, for the same reason the
    // Progress tab needed one: finishing a course while this screen is open
    // must add the certificate to it.
    _statsSub = StreakService.statsStream().listen(
      _onStats,
      onError: (Object e) {
        debugPrint('CertificatesScreen stream error: $e');
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    super.dispose();
  }

  Future<void> _onStats(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final ids = StreakService.completedCourseIds(data).toList()..sort();

    // Completion dates live in the per-course progress documents.
    final dates = <String, DateTime?>{};
    try {
      final snaps = await Future.wait([
        for (final id in ids)
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('progress')
              .doc(id)
              .get(),
      ]);
      for (var i = 0; i < ids.length; i++) {
        dates[ids[i]] = (snaps[i].data()?['completedAt'] as Timestamp?)?.toDate();
      }
    } catch (e) {
      // A missing date is survivable; the certificate itself still stands.
      debugPrint('CertificatesScreen date load error: $e');
    }

    if (!mounted) return;
    setState(() {
      _certificates = [
        for (final id in ids)
          _EarnedCertificate(
            courseId: id,
            title: displayTitle(id),
            credentialId: courseCredentialId(uid: uid, courseId: id),
            completedAt: dates[id],
          ),
      ]..sort((a, b) {
          final x = a.completedAt, y = b.completedAt;
          if (x == null && y == null) return a.title.compareTo(b.title);
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x); // most recent first
        });
      _loading = false;
    });
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime? d) =>
      d == null ? 'Completed' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

  void _open(_EarnedCertificate cert) {
    HapticFeedback.selectionClick();
    final info = courseInfo(cert.courseId);
    Navigator.push(
      context,
      AppRouter.push(
        CertificateScreen(
          courseTitle: cert.title,
          courseTag: info?.tag ?? cert.courseId,
          color: AppColors.primary,
          courseId: cert.courseId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bg,
        elevation: 0,
        foregroundColor: theme.text,
        title: Text(
          'My certificates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.text,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: WebContentBounds(
          maxWidth: 720,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))
              : _certificates.isEmpty
                  ? _buildEmpty(theme)
                  : _buildList(theme),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeNotifier theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.rosette, size: 48, color: theme.subtext),
            const SizedBox(height: 16),
            Text(
              'No certificates yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: theme.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finish every module of a course and its certificate — with its '
              'own credential ID — appears here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: theme.subtext, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeNotifier theme) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: _certificates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final cert = _certificates[i];
        return GestureDetector(
          onTap: () => _open(cert),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.rosette,
                      size: 22, color: AppColors.green),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(cert.completedAt),
                        style: TextStyle(fontSize: 12, color: theme.subtext),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cert.credentialId.isEmpty ? '—' : cert.credentialId,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.subtext,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_right,
                    size: 16, color: theme.subtext),
              ],
            ),
          ),
        );
      },
    );
  }
}
