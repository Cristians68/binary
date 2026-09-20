import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'service_backend.dart';
import 'subscription_service.dart';
import 'course_detail_screen.dart';
import 'app_router.dart';
import 'offline_service.dart';
import 'app_theme.dart';
import '../course_catalog.dart';

class OfflineDownloadsScreen extends StatefulWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  State<OfflineDownloadsScreen> createState() => _OfflineDownloadsScreenState();
}

class _OfflineDownloadsScreenState extends State<OfflineDownloadsScreen> {
  List<Map<String, dynamic>> _courses = [];
  Set<String> _downloadedIds = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _downloading = {};
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ServiceBackend.uid;
    setState(() => _loading = true);
    final downloaded = await OfflineService.getDownloadedCourses();
    if (!mounted || ServiceBackend.uid != uid) return;
    // Local downloads remain usable while the catalogue is loading or offline.
    setState(() {
      _downloadedIds = downloaded.toSet();
      _courses = downloaded.map((id) => <String, dynamic>{'id': id}).toList();
      _loading = downloaded.isEmpty;
    });
    try {
      // Load all enrolled/available courses
      final snap = await ServiceBackend.db
          .collection('courses')
          .orderBy('order')
          .get()
          .timeout(const Duration(seconds: 12));

      final courses = knownCourses(snap.docs
          .where((d) => !(d.data()['isComingSoon'] ?? false))
          .map((d) => {'id': d.id, ...d.data()})
          .toList());

      if (mounted && ServiceBackend.uid == uid) {
        final remoteIds = courses.map((course) => course['id']).toSet();
        setState(() {
          _courses = [
            ...courses,
            for (final id in downloaded)
              if (!remoteIds.contains(id)) {'id': id},
          ];
          _downloadedIds = downloaded.toSet();
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted && ServiceBackend.uid == uid) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _downloadedIds = downloaded.toSet();
          _courses =
              downloaded.map((id) => <String, dynamic>{'id': id}).toList();
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getModules(String courseId) async {
    try {
      final snap = await ServiceBackend.db
          .collection('courses')
          .doc(courseId)
          .collection('modules')
          .orderBy('order')
          .get()
          .timeout(const Duration(seconds: 12));
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _download(Map<String, dynamic> course) async {
    final courseId = course['id'] as String;
    if (_downloading[courseId] == true) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _downloading[courseId] = true;
      _downloadProgress[courseId] = 0;
    });

    final modules = await _getModules(courseId);

    final access = await SubscriptionService.canAccessCourse(courseId);
    if (!mounted) return;
    if (!access &&
        modules.any((m) =>
            !SubscriptionService.isFreePreviewModule(m['id'] as String))) {
      setState(() => _downloading[courseId] = false);
      _showSnack('Unlock this course before downloading all its lessons.');
      return;
    }

    if (modules.isEmpty) {
      if (mounted) {
        setState(() => _downloading[courseId] = false);
        _showSnack('No content found for this course.');
      }
      return;
    }

    final saved = await OfflineService.downloadCourse(
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
        if (saved == modules.length) _downloadedIds.add(courseId);
      });
      if (saved == modules.length) {
        HapticFeedback.heavyImpact();
        _showSnack(
            '${displayTitle(courseId)} lessons saved for offline study.');
      } else {
        _showSnack('Download incomplete. Check your connection and try again.');
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> course) async {
    final courseId = course['id'] as String;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Remove download?'),
        content: Text(
          'This will remove the offline content for ${displayTitle(courseId)}.',
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

    try {
      await OfflineService.deleteCourse(courseId: courseId);
    } catch (_) {
      if (mounted) {
        _showSnack('Could not remove the download. Please try again.');
      }
      return;
    }

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
        child: WebContentBounds(
            maxWidth: 720,
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
                            color: AppColors.green.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.green.withValues(alpha: 0.20)),
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
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.wifi_slash,
                            size: 18, color: AppColors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Save lessons to study offline. Reconnect to load new quizzes and save course progress.',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.subtext,
                                height: 1.4),
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
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Text(
                                      _loadFailed
                                          ? 'Could not load courses.'
                                          : 'No courses available.',
                                      style: TextStyle(
                                          fontSize: 14, color: theme.subtext)),
                                  if (_loadFailed)
                                    TextButton(
                                        onPressed: _load,
                                        child: const Text('Try again')),
                                ]))
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                              itemCount: _courses.length,
                              itemBuilder: (context, index) {
                                final course = _courses[index];
                                final courseId = course['id'] as String;
                                final color =
                                    Color(course['color'] ?? 0xFF6366F1);
                                final isDownloaded =
                                    _downloadedIds.contains(courseId);
                                final isDownloading =
                                    _downloading[courseId] == true;
                                final progress =
                                    _downloadProgress[courseId] ?? 0.0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDownloaded
                                        ? AppColors.green
                                            .withValues(alpha: 0.06)
                                        : theme.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isDownloaded
                                          ? AppColors.green
                                              .withValues(alpha: 0.2)
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
                                              color:
                                                  color.withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                            ),
                                            child: Icon(
                                                _iconForTag(
                                                    course['tag'] ?? ''),
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
                                                  displayTitle(courseId),
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
                                                      ? 'Lessons available offline'
                                                      : isDownloading
                                                          ? 'Downloading...'
                                                          : course[
                                                                  'subtitle'] ??
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
                                                value: progress > 0
                                                    ? progress
                                                    : null,
                                                color: AppColors.green,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          else if (isDownloaded)
                                            GestureDetector(
                                              onTap: () => _delete(course),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.red
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: AppColors.red
                                                          .withValues(
                                                              alpha: 0.2)),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.green
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: AppColors.green
                                                          .withValues(
                                                              alpha: 0.2)),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                      if (isDownloaded)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                            onPressed: () => Navigator.push(
                                                context,
                                                AppRouter.push(
                                                  CourseDetailScreen(
                                                    courseId: courseId,
                                                    downloadedOnly: true,
                                                    title:
                                                        displayTitle(courseId),
                                                    subtitle: '',
                                                    progress: 0,
                                                    color: color,
                                                    tag: course['tag']
                                                            as String? ??
                                                        courseInfo(courseId)
                                                            ?.tag ??
                                                        '',
                                                  ),
                                                )),
                                            icon: const Icon(
                                                Icons.menu_book_rounded),
                                            label: const Text('Study lessons'),
                                          ),
                                        ),
                                      if (isDownloading && progress > 0) ...[
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
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
            )),
      ),
    );
  }
}
