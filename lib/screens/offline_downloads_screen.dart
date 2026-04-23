import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'offline_service.dart';
import 'app_theme.dart';

class OfflineDownloadsScreen extends StatefulWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  State<OfflineDownloadsScreen> createState() => _OfflineDownloadsScreenState();
}

class _OfflineDownloadsScreenState extends State<OfflineDownloadsScreen> {
  List<Map<String, dynamic>> _courses = [];
  Set<String> _downloadedIds = {};
  Map<String, double> _downloadProgress = {};
  Map<String, bool> _downloading = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Load all enrolled/available courses
      final snap = await FirebaseFirestore.instance
          .collection('courses')
          .orderBy('order')
          .get();

      final courses = snap.docs
          .where((d) => !(d.data()['isComingSoon'] ?? false))
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      final downloaded = await OfflineService.getDownloadedCourses();

      if (mounted) {
        setState(() {
          _courses = courses;
          _downloadedIds = downloaded.toSet();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getModules(String courseId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .collection('modules')
          .orderBy('order')
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _download(Map<String, dynamic> course) async {
    final courseId = course['id'] as String;
    HapticFeedback.mediumImpact();

    setState(() {
      _downloading[courseId] = true;
      _downloadProgress[courseId] = 0;
    });

    final modules = await _getModules(courseId);

    if (modules.isEmpty) {
      if (mounted) {
        setState(() => _downloading[courseId] = false);
        _showSnack('No content found for this course.');
      }
      return;
    }

    await OfflineService.downloadCourse(
      courseId: courseId,
      modules: modules,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _downloadProgress[courseId] = done / total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloading[courseId] = false;
        _downloadedIds.add(courseId);
      });
      HapticFeedback.heavyImpact();
      _showSnack('${course['title']} downloaded for offline use.');
    }
  }

  Future<void> _delete(Map<String, dynamic> course) async {
    final courseId = course['id'] as String;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Remove download?'),
        content: Text(
          'This will remove the offline content for ${course['title']}.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final modules = await _getModules(courseId);
    await OfflineService.deleteCourse(
      courseId: courseId,
      moduleIds: modules.map((m) => m['id'] as String).toList(),
    );

    if (mounted) {
      setState(() => _downloadedIds.remove(courseId));
      _showSnack('Download removed.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  IconData _iconForTag(String tag) {
    switch (tag) {
      case 'ITIL V4':
        return CupertinoIcons.doc_text_fill;
      case 'CSM':
        return CupertinoIcons.person_2_fill;
      case 'Binary Network Pro':
        return CupertinoIcons.wifi;
      case 'Binary Cyber Pro':
        return CupertinoIcons.shield_fill;
      case 'Binary Cloud':
        return CupertinoIcons.cloud_fill;
      case 'Binary Cloud Pro':
        return CupertinoIcons.cloud_upload_fill;
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                        color: AppColors.green.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.green.withOpacity(0.20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 12, color: AppColors.green),
                          SizedBox(width: 4),
                          Text('Back',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Download for Offline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info banner
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.green.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.wifi_slash,
                        size: 18, color: AppColors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Downloaded courses are available without an internet connection.',
                        style: TextStyle(
                            fontSize: 12, color: theme.subtext, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Course list
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.green, strokeWidth: 2))
                  : _courses.isEmpty
                      ? Center(
                          child: Text('No courses available.',
                              style: TextStyle(
                                  fontSize: 14, color: theme.subtext)))
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: _courses.length,
                          itemBuilder: (context, index) {
                            final course = _courses[index];
                            final courseId = course['id'] as String;
                            final color = Color(course['color'] ?? 0xFF6366F1);
                            final isDownloaded =
                                _downloadedIds.contains(courseId);
                            final isDownloading =
                                _downloading[courseId] == true;
                            final progress = _downloadProgress[courseId] ?? 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDownloaded
                                    ? AppColors.green.withOpacity(0.06)
                                    : theme.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDownloaded
                                      ? AppColors.green.withOpacity(0.2)
                                      : theme.border,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(13),
                                        ),
                                        child: Icon(
                                            _iconForTag(course['tag'] ?? ''),
                                            color: color,
                                            size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              course['title'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: theme.text,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isDownloaded
                                                  ? 'Available offline'
                                                  : isDownloading
                                                      ? 'Downloading...'
                                                      : course['subtitle'] ??
                                                          '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDownloaded
                                                    ? AppColors.green
                                                    : theme.subtext,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Action button
                                      if (isDownloading)
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            value:
                                                progress > 0 ? progress : null,
                                            color: AppColors.green,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else if (isDownloaded)
                                        GestureDetector(
                                          onTap: () => _delete(course),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.red
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: AppColors.red
                                                      .withOpacity(0.2)),
                                            ),
                                            child: const Text(
                                              'Remove',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.red,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: () => _download(course),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.green
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: AppColors.green
                                                      .withOpacity(0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                    CupertinoIcons
                                                        .arrow_down_circle_fill,
                                                    size: 13,
                                                    color: AppColors.green),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Download',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  // Progress bar during download
                                  if (isDownloading && progress > 0) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: theme.border,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                AppColors.green),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ],
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
}
