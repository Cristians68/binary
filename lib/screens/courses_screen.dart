import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'course_detail_screen.dart';
import 'paywall_screen.dart';
import 'app_router.dart';
import 'app_theme.dart';
import 'learning_widgets.dart';
import '../course_catalog.dart';
import 'streak_service.dart';
import 'service_backend.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Map<String, dynamic>> _courses = [];
  Set<String> _enrolledIds = {};
  bool _loading = true, _loadFailed = false, _hasFullAccess = false;
  String _filter = 'All';
  final _search = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _statsSub;
  static const _filters = [
    'All',
    'My courses',
    'Networking',
    'Security',
    'Cloud',
    'AI',
    'Business'
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalogue();
    _statsSub = StreakService.statsStream().listen((data) {
      if (!mounted) return;
      setState(() {
        _enrolledIds = StreakService.enrolledCourseIdsFrom(data);
        _hasFullAccess = data['subscriptionPlan'] == 'all';
      });
    }, onError: (Object error) => debugPrint('Courses stats: $error'));
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final snap = await ServiceBackend.db
          .collection('courses')
          .orderBy('order')
          .get()
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _courses = knownCourses(
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  String _category(Map<String, dynamic> course) {
    final tag = (course['tag'] ?? courseInfo(course['id'] as String)?.tag ?? '')
        .toString();
    if (tag.contains('Network')) return 'Networking';
    if (tag.contains('Cyber')) return 'Security';
    if (tag.contains('Cloud')) return 'Cloud';
    if (tag.contains('AI')) return 'AI';
    return 'Business';
  }

  List<Map<String, dynamic>> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _courses.where((course) {
      final id = course['id'] as String;
      final matches = _filter == 'All' ||
          (_filter == 'My courses'
              ? _enrolledIds.contains(id)
              : _category(course) == _filter);
      final text = '${displayTitle(id)} ${course['subtitle'] ?? ''} '
          '${courseInfo(id)?.preparesFor ?? ''}';
      return matches && text.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleEnrollment(String courseId) async {
    final uid = ServiceBackend.uid;
    if (uid == null) return;
    HapticFeedback.selectionClick();
    final enrolled = _enrolledIds.contains(courseId);
    setState(() =>
        enrolled ? _enrolledIds.remove(courseId) : _enrolledIds.add(courseId));
    try {
      await safeUpdate(ServiceBackend.db.collection('users').doc(uid),
          {'enrolments.$courseId': !enrolled});
    } catch (_) {
      if (!mounted || ServiceBackend.uid != uid) return;
      setState(() => enrolled
          ? _enrolledIds.add(courseId)
          : _enrolledIds.remove(courseId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update your courses. Please try again.')));
    }
  }

  void _openCourse(Map<String, dynamic> course) {
    HapticFeedback.selectionClick();
    final id = course['id'] as String;
    Navigator.push(
        context,
        AppRouter.push(CourseDetailScreen(
          courseId: id,
          title: displayTitle(id),
          subtitle: course['subtitle'] ?? '',
          progress: 0,
          color: Color(course['color'] ?? AppColors.primary.toARGB32()),
          tag: course['tag'] ?? courseInfo(id)?.tag ?? '',
        )));
  }

  void _openPlans() => Navigator.push(
      context,
      MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const PaywallScreen(
              courseTitle: 'B1nary',
              courseColor: AppColors.primary,
              defaultToAllPlans: true)));
  IconData _icon(String category) => switch (category) {
        'Networking' => Icons.hub_outlined,
        'Security' => Icons.shield_outlined,
        'Cloud' => Icons.cloud_outlined,
        'AI' => Icons.auto_awesome_outlined,
        _ => Icons.workspaces_outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final visible = _visible;
    final resultCount = visible.length;
    return Scaffold(
        backgroundColor: theme.bg,
        body: SafeArea(
            child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: LayoutBuilder(builder: (context, constraints) {
                final spacious = constraints.maxWidth >= 700 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 18;
                final columns =
                    spacious ? (constraints.maxWidth >= 1050 ? 3 : 2) : 1;
                final inset = spacious ? 32.0 : 20.0;
                return RefreshIndicator(
                    onRefresh: _loadCatalogue,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                            padding: EdgeInsets.fromLTRB(inset, 24, inset, 20),
                            sliver: SliverToBoxAdapter(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const StudyLabel('THE COURSE LIBRARY',
                                      icon: Icons.auto_stories_outlined),
                                  const SizedBox(height: 14),
                                  Text('What will you\nlearn next?',
                                      style: TextStyle(
                                          color: theme.text,
                                          fontSize: spacious ? 38 : 32,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                          letterSpacing: -1.2)),
                                  const SizedBox(height: 10),
                                  Text(
                                      'Real skills, one lesson at a time. Every first module is free.',
                                      style: TextStyle(
                                          color: theme.subtext,
                                          fontSize: 14,
                                          height: 1.6)),
                                  const SizedBox(height: 24),
                                  TextField(
                                      controller: _search,
                                      onChanged: (_) => setState(() {}),
                                      textInputAction: TextInputAction.search,
                                      style: TextStyle(
                                          color: theme.text, fontSize: 14),
                                      decoration: InputDecoration(
                                          hintText: 'Search courses or skills',
                                          hintStyle:
                                              TextStyle(color: theme.subtext),
                                          prefixIcon: Icon(Icons.search_rounded,
                                              color: theme.subtext),
                                          suffixIcon: _search.text.isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: 'Clear search',
                                                  icon: const Icon(
                                                      Icons.close_rounded),
                                                  onPressed: () =>
                                                      setState(_search.clear)),
                                          filled: true,
                                          fillColor: theme.card,
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 18),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                  color: theme.border)),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                  color: theme.border)),
                                          focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)))),
                                  const SizedBox(height: 16),
                                  SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                          children: _filters
                                              .map((label) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 8),
                                                  child: ChoiceChip(
                                                    label: Text(label),
                                                    selected: _filter == label,
                                                    showCheckmark: false,
                                                    selectedColor:
                                                        AppColors.primary,
                                                    backgroundColor: theme.card,
                                                    labelStyle: TextStyle(
                                                        color: _filter == label
                                                            ? Colors.white
                                                            : theme.subtext,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                    side: BorderSide(
                                                        color: _filter == label
                                                            ? AppColors.primary
                                                            : theme.border),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 8),
                                                    onSelected: (_) => setState(
                                                        () => _filter = label),
                                                  )))
                                              .toList())),
                                  const SizedBox(height: 22),
                                  Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 18,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                            _loading
                                                ? 'Finding your next course…'
                                                : resultCount == 1
                                                    ? '1 course to explore'
                                                    : '$resultCount courses to explore',
                                            style: TextStyle(
                                                color: theme.subtext,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                        if (!_hasFullAccess)
                                          TextButton(
                                              onPressed: _openPlans,
                                              child: const Text('View plans')),
                                      ]),
                                ]))),
                        if (_loading)
                          const SliverToBoxAdapter(
                              child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(
                                      child: CircularProgressIndicator())))
                        else if (visible.isEmpty)
                          SliverToBoxAdapter(
                              child: Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(inset, 12, inset, 48),
                                  child: Container(
                                      padding: const EdgeInsets.all(28),
                                      decoration: BoxDecoration(
                                          color: theme.card,
                                          borderRadius:
                                              BorderRadius.circular(24)),
                                      child: Column(children: [
                                        Icon(
                                            _loadFailed
                                                ? Icons.cloud_off_outlined
                                                : Icons.search_rounded,
                                            size: 36,
                                            color: theme.subtext),
                                        const SizedBox(height: 16),
                                        Text(
                                            _loadFailed
                                                ? 'Your courses couldn’t load'
                                                : 'Room for something new',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: theme.text,
                                                fontSize: 19,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        Text(
                                            _loadFailed
                                                ? 'Check your connection and try again.'
                                                : _filter == 'My courses' &&
                                                        _search.text.isEmpty
                                                    ? 'Enroll in a course to keep it close. Start with a free first module.'
                                                    : 'Try a different search or explore all courses.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: theme.subtext,
                                                height: 1.6)),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                            onPressed: _loadFailed
                                                ? _loadCatalogue
                                                : () => setState(() {
                                                      _search.clear();
                                                      _filter = 'All';
                                                    }),
                                            child: Text(_loadFailed
                                                ? 'Try again'
                                                : 'Explore all courses')),
                                      ]))))
                        else
                          SliverPadding(
                              padding: EdgeInsets.fromLTRB(inset, 0, inset, 32),
                              sliver: SliverList.builder(
                                  itemCount: (visible.length / columns).ceil(),
                                  itemBuilder: (context, row) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            for (var col = 0;
                                                col < columns;
                                                col++) ...[
                                              if (col > 0)
                                                const SizedBox(width: 16),
                                              Expanded(
                                                  child: row * columns + col <
                                                          visible.length
                                                      ? _courseCard(
                                                          visible[
                                                              row * columns +
                                                                  col],
                                                          theme)
                                                      : const SizedBox
                                                          .shrink()),
                                            ],
                                          ])))),
                      ],
                    ));
              })),
        )));
  }

  Widget _courseCard(Map<String, dynamic> course, ThemeNotifier theme) {
    final id = course['id'] as String;
    final category = _category(course);
    final color = Color(course['color'] ?? AppColors.primary.toARGB32());
    final enrolled = _enrolledIds.contains(id);
    final modules = course['totalModules'];
    return Material(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _openCourse(course),
          borderRadius: BorderRadius.circular(24),
          child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: enrolled
                          ? color.withValues(alpha: .45)
                          : theme.border)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(15)),
                          child: Icon(_icon(category), size: 25, color: color)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(category.toUpperCase(),
                              style: TextStyle(
                                  color: theme.subtext,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2))),
                      if (enrolled)
                        Icon(Icons.bookmark_rounded, size: 22, color: color),
                    ]),
                    const SizedBox(height: 18),
                    Text(displayTitle(id),
                        style: TextStyle(
                            color: theme.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.5,
                            height: 1.25)),
                    const SizedBox(height: 10),
                    Text(courseInfo(id)?.blurb ?? course['subtitle'] ?? '',
                        style: TextStyle(
                            color: theme.subtext, fontSize: 13, height: 1.6)),
                    const SizedBox(height: 18),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      StudyLabel(
                          modules is num
                              ? '$modules modules'
                              : 'Flashcard lessons',
                          color: theme.subtext,
                          icon: Icons.layers_outlined),
                      const StudyLabel('Free first module',
                          color: AppColors.green),
                    ]),
                    const SizedBox(height: 20),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton(
                              onPressed: () => _openCourse(course),
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              child: const Text('View course',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600))),
                          TextButton.icon(
                              onPressed: () => _toggleEnrollment(id),
                              style: TextButton.styleFrom(
                                  foregroundColor: theme.subtext),
                              icon: Icon(
                                  enrolled
                                      ? Icons.bookmark_remove_outlined
                                      : Icons.add_rounded,
                                  size: 18),
                              label: Text(enrolled ? 'Unenroll' : 'Enroll')),
                        ]),
                  ])),
        ));
  }
}
