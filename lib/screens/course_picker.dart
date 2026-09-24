import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../course_catalog.dart';
import 'service_backend.dart';
import 'streak_service.dart';

/// "What do you want to learn?" — asked once per account, the first time a
/// learner reaches the app with no courses, so Home opens on their choices.
class CoursePicker {
  CoursePicker._();

  static String _doneKey(String uid) => 'course_picker_done_$uid';

  /// Keyed by uid, unlike onboarding: a second account on the same phone is a
  /// different learner who has picked nothing yet.
  static Future<bool> shouldShow() async {
    final uid = ServiceBackend.uid;
    if (uid == null) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey(uid)) ?? false) return false;
    final snap = await ServiceBackend.db.collection('users').doc(uid).get();
    return StreakService.enrolledCourseIdsFrom(snap.data() ?? {}).isEmpty;
  }

  static Future<void> markDone() async {
    final uid = ServiceBackend.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey(uid), true);
  }

  /// Same write the Courses tab's Enroll button makes.
  static Future<void> save(Set<String> courseIds) async {
    final uid = ServiceBackend.uid;
    if (uid == null) return;
    await safeUpdate(ServiceBackend.db.collection('users').doc(uid), {
      for (final id in courseIds) 'enrolments.$id': true,
    });
    await markDone();
  }

  /// Shows the picker if this account should see it. Skipping still counts
  /// as answered, so nobody is asked twice.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      if (!await shouldShow() || !context.mounted) return;
    } catch (error) {
      debugPrint('Course picker check failed: $error');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CoursePickerScreen(onSave: save, onSkip: markDone),
    ));
  }
}

class CoursePickerScreen extends StatefulWidget {
  const CoursePickerScreen({super.key, required this.onSave, this.onSkip});

  final Future<void> Function(Set<String> courseIds) onSave;
  final Future<void> Function()? onSkip;

  @override
  State<CoursePickerScreen> createState() => _CoursePickerScreenState();
}

class _CoursePickerScreenState extends State<CoursePickerScreen> {
  final _picked = <String>{};
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_picked);
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      debugPrint('Saving picked courses failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your courses. Please try again.')));
    }
  }

  Future<void> _skip() async {
    await widget.onSkip?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Text('What do you want to learn?',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: scheme.onSurface)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                  'Pick one or more. Module 1 of every course is free, and '
                  'you can change this any time from the Courses tab.',
                  style: TextStyle(
                      height: 1.4,
                      color: scheme.onSurface.withValues(alpha: 0.7))),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final course in kCourseCatalog)
                    CheckboxListTile(
                      value: _picked.contains(course.id),
                      onChanged: _saving
                          ? null
                          : (on) => setState(() => on == true
                              ? _picked.add(course.id)
                              : _picked.remove(course.id)),
                      title: Text(course.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(course.blurb,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      controlAffinity: ListTileControlAffinity.trailing,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _picked.isEmpty || _saving ? null : _continue,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: const Text('Continue'),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
