// Local screenshot fixture: no production Firebase initialization or writes.
// Uses published catalogue metadata and a fictional learner. Build with --debug;
// FakeFirebaseFirestore deliberately refuses release-mode platform mocks.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'package:binary/app_startup.dart';
import 'package:binary/course_catalog.dart';
import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/courses_screen.dart';
import 'package:binary/screens/home_screen.dart';
import 'package:binary/screens/login_screen.dart';
import 'package:binary/screens/signup_screen.dart';
import 'package:binary/screens/profile_screen.dart';
import 'package:binary/screens/main_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:binary/screens/learning_navigation_bar.dart';
import 'package:binary/screens/lesson_screen.dart';
import 'package:binary/screens/offline_downloads_screen.dart';
import 'package:binary/screens/progress_screen.dart';
import 'package:binary/screens/quiz_screen.dart';
import 'package:binary/screens/review_screen.dart';
import 'package:binary/screens/review_service.dart';
import 'package:binary/screens/onboarding_screen.dart';
import 'package:binary/screens/welcome_screen.dart';
import 'package:binary/screens/paywall_screen.dart';
import 'package:binary/screens/legal_screen.dart';
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
  ServiceBackend.useAuth(_PreviewAuth());
  final storeCapture = Uri.base.queryParameters['store'] == '1';
  final screen = Uri.base.queryParameters['screen'] ?? 'onboarding';
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
      if (storeCapture) {
        // Render the real lesson/quiz widgets with published FREE content.
        // The export stays local; no user data or paid course body is bundled.
        for (final kind in ['flashcards', 'quiz']) {
          for (final item in (raw[kind] as List? ?? [])) {
            final card = Map<String, dynamic>.from(item as Map);
            final id = card.remove('id');
            await db
                .doc(
                    'courses/${course['id']}/modules/${module['id']}/$kind/$id')
                .set(card);
          }
        }
      }
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
      // Match ProgressService: quiz history stores the percentage in score.
      {'score': 80},
      {'score': 100}
    ],
    'streak': {'current': 7, 'longest': 7, 'lastLogin': today},
    'badges': {'streak_7': today, 'quiz_first': today, 'quiz_perfect': today},
    'dailyGoal': {'todayPoints': 30, 'target': 50, 'lastReset': today},
  });
  await db.doc('users/design-preview/progress/$network').set({'progress': .4});

  final dark = Uri.base.queryParameters['dark'] == '1';
  if (screen == 'recall') {
    for (var i = 1; i <= 2; i++) {
      await db
          .doc(
              'courses/$network/modules/${modules.first['id']}/flashcards/recall-$i')
          .set({
        'order': i,
        'label': 'Network basics',
        'question': i == 1 ? 'What does DNS do?' : 'What does DHCP do?',
        'answer': i == 1
            ? 'DNS resolves names to IP addresses.'
            : 'DHCP leases network settings to devices.',
        'example': i == 1
            ? 'Think of finding the address for a website before connecting to it.'
            : 'A new device can receive an address when it joins a network.',
      });
    }
  }
  if (screen == 'quiz-feedback') {
    for (var i = 1; i <= 2; i++) {
      await db
          .doc(
              'courses/$network/modules/${modules.first['id']}/quiz/feedback-$i')
          .set({
        'order': i,
        'question': i == 1
            ? 'Which service translates a website name into an IP address?'
            : 'What should you check first when a wired connection is down?',
        'options': i == 1
            ? ['DNS', 'DHCP']
            : ['Check the cable and link lights', 'Replace every device'],
        'correctIndex': 0,
        'explanation': i == 1
            ? 'DNS resolves names to IP addresses. DHCP leases network settings to devices.'
            : 'Start with the physical connection before changing network settings.',
      });
    }
  }
  if (screen == 'review') {
    await ReviewService.recordMiss(
      courseId: 'itil-v4',
      moduleId: 'module-1',
      courseTag: 'ITIL V4',
      question: {
        'question': 'How do teams improve a service?',
        'answers': ['Use feedback to adapt', 'Ignore measured outcomes'],
        'correct': 0,
        'explanation':
            'Feedback helps a team choose useful changes and learn from the results.',
      },
    );
  }
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  final theme = ThemeNotifier(initialIsDark: dark);
  final module = modules.first;
  final Widget page = switch (screen) {
    'startup-error' =>
      AppStartup(initialize: () async => throw StateError('offline')),
    'welcome' => const WelcomeScreen(),
    'login' => const LoginScreen(),
    'signup' => const SignupScreen(),
    'profile' => const ProfileScreen(),
    'navigation' => const MainNavigation(),
    'legal' => const LegalScreen(),
    'paywall' => PaywallScreen(
        courseId: network,
        courseTitle: 'Network Professional',
        courseColor: Color(networkData['color'])),
    'onboarding' => OnboardingScreen(onComplete: () {}),
    'courses' => const CoursesScreen(),
    'review' || 'review-empty' => const ReviewScreen(),
    'progress' => const ProgressScreen(),
    'offline' => const OfflineDownloadsScreen(),
    'lesson' || 'recall' => LessonScreen(
        moduleTitle: displayModuleTitle(module['title']),
        courseTag: 'Binary Network Pro',
        color: Color(networkData['color']),
        moduleId: module['id'],
        courseId: network),
    'quiz' || 'quiz-feedback' => QuizScreen(
        moduleTitle: displayModuleTitle(module['title']),
        courseTag: 'Binary Network Pro',
        color: Color(networkData['color']),
        moduleId: module['id'],
        courseId: network,
        practiceOnly: screen == 'quiz' && !storeCapture),
    _ => const HomeScreen(learnerName: 'Alex'),
  };
  final hasTabs = ['home', 'courses', 'progress'].contains(screen);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appMaterialTheme(theme, platform: TargetPlatform.iOS),
    builder: (context, child) => AppTheme(
        notifier: theme,
        child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
                // Native-like safe areas for the local 440 x 956 store preview.
                // The renderer adds OS chrome inside these reserved regions.
                padding: storeCapture
                    ? const EdgeInsets.only(top: 62, bottom: 34)
                    : null,
                viewPadding: storeCapture
                    ? const EdgeInsets.only(top: 62, bottom: 34)
                    : null),
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

// Display-only identity: unexpected auth operations fail instead of touching
// Firebase. All preview data belongs to the fictional learner in fake Firestore.
class _PreviewAuth implements FirebaseAuth {
  @override
  User get currentUser => _PreviewUser();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Preview auth: ${invocation.memberName}');
}

class _PreviewUser implements User {
  @override
  String get uid => 'design-preview';
  @override
  String get displayName => 'Alex Morgan';
  @override
  String get email => 'alex@example.com';
  @override
  String? get photoURL => null;
  @override
  bool get isAnonymous => false;
  @override
  List<UserInfo> get providerData => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Preview user: ${invocation.memberName}');
}
