// Local screenshot fixture: no production Firebase initialization or writes.
// Uses published catalogue metadata and a fictional learner. Build with --debug;
// FakeFirebaseFirestore deliberately refuses release-mode platform mocks.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'package:binary/course_catalog.dart';
import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/courses_screen.dart';
import 'package:binary/screens/home_screen.dart';
import 'package:binary/screens/learning_navigation_bar.dart';
import 'package:binary/screens/lesson_screen.dart';
import 'package:binary/screens/offline_downloads_screen.dart';
import 'package:binary/screens/progress_screen.dart';
import 'package:binary/screens/quiz_screen.dart';
import 'package:binary/screens/onboarding_screen.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixture_content.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Match main.dart: the preview must fail the same way production would
  // if a weight is missing from the bundle, not quietly download it and
  // render a screenshot that production could never produce.
  GoogleFonts.config.allowRuntimeFetching = false;
  binding.ensureSemantics();
  SharedPreferences.setMockInitialValues({});
  final db = FakeFirebaseFirestore();
  ServiceBackend.useFake(db, uid: 'design-preview');
  const network = 'binary-network-professional';
  final data = jsonDecode(fixtureContentJson) as Map<String, dynamic>;
  final courses = (data['courses'] as List).cast<Map<String, dynamic>>();
  final networkData = courses.firstWhere((c) => c['id'] == network);
  final modules = (networkData['modules'] as List).cast<Map<String, dynamic>>();
  for (final course in courses) {
    final metadata = Map<String, dynamic>.from(course)..remove('modules');
    await db.doc('courses/${course['id']}').set(metadata);
    for (final raw in course['modules'] as List) {
      final module = Map<String, dynamic>.from(raw as Map)
        ..remove('flashcards')
        ..remove('quiz')
        ..remove('flashcardsReadError')
        ..remove('quizReadError');
      await db
          .doc('courses/${course['id']}/modules/${module['id']}')
          .set(module);
    }
  }
  final today = Timestamp.fromDate(DateTime.now());
  await db.doc('users/design-preview').set({
    'enrolments': {network: true, 'binary-cloud-fundamentals': true},
    'lessonsCompleted': 8,
    'completedLessons': [
      for (final module in modules.take(8))
        {
          'moduleId': module['id'],
          'courseId': network,
          'moduleTitle': module['title'],
          'courseTag': 'Binary Network Pro',
          'percent': 100,
          'completedAt': today,
        },
    ],
    'quizScores': [
      {'score': 8, 'total': 10, 'percent': 80},
      {'score': 10, 'total': 10, 'percent': 100}
    ],
    'streak': {'current': 7, 'longest': 7, 'lastLogin': today},
    'badges': {'streak_7': today, 'quiz_first': today, 'quiz_perfect': today},
    'dailyGoal': {'todayPoints': 30, 'target': 50, 'lastReset': today},
  });
  await db.doc('users/design-preview/progress/$network').set({'progress': .4});

  final dark = Uri.base.queryParameters['dark'] == '1';
  final screen = Uri.base.queryParameters['screen'] ?? 'onboarding';
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  final theme = ThemeNotifier(initialIsDark: dark);
  final brightness = dark ? Brightness.dark : Brightness.light;
  final module = modules.first;
  final Widget page = switch (screen) {
    'onboarding' => OnboardingScreen(onComplete: () {}),
    'courses' => const CoursesScreen(),
    'progress' => const ProgressScreen(),
    'offline' => const OfflineDownloadsScreen(),
    'lesson' => LessonScreen(
        moduleTitle: displayModuleTitle(module['title']),
        courseTag: 'Binary Network Pro',
        color: Color(networkData['color']),
        moduleId: module['id'],
        courseId: network),
    'quiz' => QuizScreen(
        moduleTitle: displayModuleTitle(module['title']),
        courseTag: 'Binary Network Pro',
        color: Color(networkData['color']),
        moduleId: module['id'],
        courseId: network,
        practiceOnly: true),
    _ => const HomeScreen(learnerName: 'Alex'),
  };
  final hasTabs = ['home', 'courses', 'progress'].contains(screen);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: brightness,
      platform: TargetPlatform.iOS,
      scaffoldBackgroundColor: theme.bg,
      colorScheme: ColorScheme(
          brightness: brightness,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.primary,
          onSecondary: Colors.white,
          error: AppColors.red,
          onError: Colors.white,
          surface: theme.surface,
          onSurface: theme.text),
      textTheme: GoogleFonts.interTextTheme(
              dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
          .apply(bodyColor: theme.text, displayColor: theme.text),
    ),
    builder: (context, child) => AppTheme(
        notifier: theme,
        child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: child!)),
    home: hasTabs
        ? Scaffold(
            body: page,
            bottomNavigationBar: LearningNavigationBar(
                currentIndex: screen == 'courses'
                    ? 1
                    : screen == 'progress'
                        ? 2
                        : 0,
                onTap: (_) {}),
          )
        : page,
  ));
}
