import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/lesson_screen.dart';
import 'package:binary/screens/onboarding_screen.dart';
import 'package:binary/screens/offline_downloads_screen.dart';
import 'package:binary/screens/offline_service.dart';
import 'package:binary/screens/quiz_screen.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const quiz = QuizScreen(
    moduleTitle: 'Network basics',
    courseTag: 'Binary Network Pro',
    color: Colors.blue,
    moduleId: 'module-1',
    courseId: 'network');

void main() {
  late FakeFirebaseFirestore db;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'learner');
  });
  tearDown(ServiceBackend.reset);

  Future<void> pump(WidgetTester tester, Widget screen,
      {double textScale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppTheme(
          notifier: ThemeNotifier(),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          )),
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> seedQuiz({String? text}) =>
      db.doc('courses/network/modules/module-1/quiz/q1').set({
        'order': 1,
        'question': text ?? 'The actual published question',
        'options': ['Correct published answer', 'Wrong published answer'],
        'correctIndex': 0,
        'explanation': 'A useful explanation.',
      });

  testWidgets('retry reuses the published quiz instead of switching to samples',
      (tester) async {
    await seedQuiz();
    await pump(tester, quiz);
    await tap(tester, 'Wrong published answer');
    await tap(tester, 'See results');
    expect(find.text('Keep studying!'), findsOneWidget);
    await tap(tester, 'Try again');
    expect(find.text('The actual published question'), findsOneWidget);
    expect(find.text('Correct published answer'), findsOneWidget);
    expect(find.text('Wrong published answer'), findsOneWidget);
  });
  testWidgets('missing content offers a real retry and recovery',
      (tester) async {
    await pump(tester, quiz);
    expect(find.text('Quiz unavailable'), findsOneWidget);
    await seedQuiz();
    await tap(tester, 'Try again');
    expect(find.text('The actual published question'), findsOneWidget);
  });
  testWidgets('a passed quiz retries its save without losing the answers',
      (tester) async {
    await seedQuiz();
    await pump(tester, quiz);
    await tap(tester, 'Correct published answer');
    await tap(tester, 'See results');
    expect(
        find.textContaining('Your score could not be saved'), findsOneWidget);
    expect(find.text('Great work!'), findsNothing);
    await db.doc('courses/network/modules/module-1').set({'order': 1});
    await tap(tester, 'Retry save');
    expect(find.text('Great work!'), findsOneWidget);
    final user = (await db.doc('users/learner').get()).data()!;
    expect(user['lessonsCompleted'], 1);
    expect(user['quizScores'], hasLength(1));
  });
  testWidgets('a quiz cannot save its score into a different account',
      (tester) async {
    await seedQuiz();
    await db.doc('courses/network/modules/module-1').set({'order': 1});
    await pump(tester, quiz);
    await tap(tester, 'Correct published answer');
    ServiceBackend.useFake(db, uid: 'another-learner');
    await tap(tester, 'See results');
    expect(find.text('Great work!'), findsNothing);
    expect(
        find.textContaining('Your score could not be saved'), findsOneWidget);
    expect((await db.collection('users').get()).docs, isEmpty);
  });
  testWidgets('saved lessons remain usable when the course lookup is empty',
      (tester) async {
    await db.doc('courses/itil-v4/modules/module-1/flashcards/card').set({
      'question': 'A saved lesson',
      'answer': 'The downloaded explanation',
      'order': 1,
    });
    await OfflineService.downloadCourse(courseId: 'itil-v4', modules: const [
      {'id': 'module-1', 'title': 'Service basics', 'order': 1},
    ]);
    await db.doc('courses/itil-v4/modules/module-1/flashcards/card').delete();
    await pump(tester, const OfflineDownloadsScreen());
    expect(find.text('Lessons available offline'), findsOneWidget);
    expect(find.text('Study lessons'), findsOneWidget);
    await tap(tester, 'Study lessons');
    await tap(tester, 'Service basics');
    expect(find.text('A saved lesson'), findsOneWidget);
    expect(find.text('The downloaded explanation'), findsOneWidget);
    expect(find.textContaining('Saved copy'), findsOneWidget);
    await tap(tester, 'Back');
    await tap(tester, 'Back');
    await tap(tester, 'Remove');
    await tap(tester, 'Remove');
    expect(await OfflineService.getDownloadedCourses(), isEmpty);
  });
  testWidgets(
      'empty lessons render recovery rather than indexing an empty list',
      (tester) async {
    await pump(
        tester,
        const LessonScreen(
            moduleTitle: 'Missing',
            courseTag: 'Binary Network Pro',
            color: Colors.blue,
            moduleId: 'module-1',
            courseId: 'network'));
    expect(find.text('Lesson unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('passing a sample cannot award course progress', (tester) async {
    await pump(
        tester,
        const QuizScreen(
            moduleTitle: 'Missing',
            courseTag: 'Binary Network Pro',
            color: Colors.blue,
            moduleId: 'missing',
            courseId: 'network',
            practiceOnly: true));
    expect(find.textContaining('Progress and certificates are not awarded'),
        findsOneWidget);
    await tap(tester,
        'IP routing table — matches destination IP to next-hop or egress interface');
    await tap(tester, 'See results');
    expect(find.text('Practice complete'), findsOneWidget);
    expect((await db.doc('users/learner').get()).exists, isFalse);
    expect((await db.collection('users/learner/progress').get()).docs, isEmpty);
  });
  testWidgets('long questions remain usable on small screens with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedQuiz(
        text: List.filled(
                12, 'A network engineer is diagnosing a name resolution issue.')
            .join(' '));
    await pump(tester, quiz, textScale: 1.7);
    await tap(tester, 'Wrong published answer');
    await tap(tester, 'See results');
    expect(find.text('Keep studying!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('onboarding teaches a card and question, then completes once',
      (tester) async {
    var completed = 0;
    await pump(tester, OnboardingScreen(onComplete: () => completed++));
    await tap(tester, 'Reveal explanation');
    expect(find.textContaining('DNS translates domain names'), findsOneWidget);
    await tap(tester, 'Continue');
    await tap(tester, 'DNS');
    expect(find.textContaining('Exactly. DNS'), findsOneWidget);
    await tap(tester, 'Continue');
    await tap(tester, 'Explore free lessons');
    expect(completed, 1);
  });
  testWidgets('onboarding can be read and skipped with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var completed = false;
    await pump(tester, OnboardingScreen(onComplete: () => completed = true),
        textScale: 2);
    await tap(tester, 'Skip');
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
