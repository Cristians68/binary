import 'package:binary/screens/app_lock.dart';
import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/learning_navigation_bar.dart';
import 'package:binary/screens/main_navigation.dart';
import 'package:binary/screens/quiz_screen.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:binary/screens/welcome_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'learner';
  @override
  bool get isAnonymous => false;
  @override
  String? get displayName => 'Alex Learner';
  @override
  String? get email => 'learner@example.test';
  @override
  String? get photoURL => null;
  @override
  List<UserInfo> get providerData => [];
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

void main() {
  late FakeFirebaseFirestore db;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'course_picker_done_learner': true,
      kAppLockOfferedKey: true,
    });
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'learner');
    ServiceBackend.useAuth(_Auth());
  });
  tearDown(ServiceBackend.reset);

  Future<void> pump(WidgetTester tester, Widget screen,
      {Size size = const Size(390, 844), double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      builder: (context, child) => AppTheme(
        notifier: ThemeNotifier(),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  // These are a resize stress matrix, not asserted iPhone hardware dimensions.
  const sizes = [
    Size(960, 680),
    Size(600, 900),
    Size(720, 320),
    Size(320, 568),
    Size(390, 844),
  ];

  testWidgets('native forms stay bounded and retain input across resizes',
      (tester) async {
    await pump(
        tester,
        const Scaffold(
          body: SafeArea(child: WebContentBounds(child: TextField())),
        ));
    await tester.enterText(find.byType(TextField), 'Learning in progress');
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(
          tester.getSize(find.byType(TextField)).width, lessThanOrEqualTo(640));
      expect(find.text('Learning in progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('folding moves navigation without resetting the tab or search',
      (tester) async {
    await db.doc('courses/binary-cloud-fundamentals').set({
      'order': 1,
      'tag': 'Binary Cloud',
      'totalModules': 8,
    });
    await pump(tester, const MainNavigation());
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cloud');
    await tester.pumpAndSettle();
    final searchState = tester.state(find.byType(EditableText));
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditableText)), same(searchState));
      expect(find.text('cloud'), findsOneWidget);
      // The lazy course card may be below a short viewport's build cache.
      expect(find.text('1 course to explore'), findsOneWidget);
      expect(find.byType(LearningNavigationBar),
          size.width >= 720 ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('short wide navigation remains usable with doubled text',
      (tester) async {
    await pump(tester, const MainNavigation(),
        size: const Size(960, 320), scale: 2);
    await tester.ensureVisible(find.text('Courses').last);
    await tester.tap(find.text('Courses').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cloud');
    await tester.pumpAndSettle();
    expect(find.text('cloud'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome actions stay reachable after wide and short resizes',
      (tester) async {
    await pump(tester, const WelcomeScreen());
    for (final size in [...sizes, const Size(1200, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      for (final label in [
        'Continue as guest',
        'Continue with Google',
        'Create an account',
        'Already learning with us? Log in',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('quiz answer and feedback survive folds before submission',
      (tester) async {
    await db.doc('courses/network/modules/module-1/quiz/q1').set({
      'order': 1,
      'question': 'Which answer is correct?',
      'options': ['Correct answer', 'Wrong answer'],
      'correctIndex': 0,
      'explanation': 'Keep this feedback while resizing.',
    });
    await pump(
        tester,
        const QuizScreen(
          moduleTitle: 'Network basics',
          courseTag: 'Binary Network Pro',
          color: Colors.blue,
          moduleId: 'module-1',
          courseId: 'network',
        ));
    await tester.tap(find.text('Wrong answer'));
    await tester.pumpAndSettle();
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.text('Keep this feedback while resizing.'), findsOneWidget);
      await tester.ensureVisible(find.text('See results'));
      await tester.pumpAndSettle();
      expect(find.text('See results').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect((await db.doc('users/learner').get()).exists, isFalse);
  });
}
