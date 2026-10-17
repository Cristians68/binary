import 'package:binary/screens/app_router.dart';
import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/quiz_results_dialog.dart';
import 'package:binary/screens/quiz_screen.dart';
import 'package:binary/screens/review_service.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _quiz = QuizScreen(
  moduleTitle: 'Network basics',
  courseTag: 'Binary Network Pro',
  color: Colors.blue,
  moduleId: 'module-1',
  courseId: 'network',
);

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReviewService.resetForTesting();
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'learner');
  });
  tearDown(ServiceBackend.reset);

  Future<void> seed({int count = 1, bool longText = false}) async {
    await db.doc('courses/network/modules/module-1').set({'order': 1});
    for (var i = 1; i <= count; i++) {
      await db.doc('courses/network/modules/module-1/quiz/q$i').set({
        'order': i,
        'question': longText
            ? 'Question $i: ${List.filled(12, 'Diagnose this network issue.').join(' ')}'
            : 'Published question $i',
        'options': ['Correct answer $i', 'Wrong answer $i'],
        'correctIndex': 0,
        'explanation': 'Explanation for question $i.',
      });
    }
  }

  Future<void> open(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppTheme(
        notifier: ThemeNotifier(),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
      home: Builder(builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(AppRouter.push(_quiz)),
            child: const Text('Start quiz'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('Start quiz'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder inResults(String text) => find.descendant(
      of: find.byType(QuizResultsDialog), matching: find.text(text));

  Future<List<Map<String, dynamic>>> reviewQueue(WidgetTester tester) async {
    // The serialized SharedPreferences queue can cross real/fake async zones.
    // Pump both clocks instead of awaiting a callback on a paused test clock.
    List<Map<String, dynamic>>? items;
    ReviewService.all().then((value) => items = value);
    for (var i = 0; i < 30 && items == null; i++) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
    }
    expect(items, isNotNull, reason: 'Review storage should finish its writes');
    return items!;
  }

  testWidgets(
      'answer feedback announces correctness and names the right answer',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await seed(count: 2);
      await open(tester);
      await tap(tester, 'Wrong answer 1');
      expect(find.bySemanticsLabel('Wrong answer 1. Your answer, incorrect'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Correct answer 1. Correct answer'),
          findsOneWidget);
      final feedback = find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.liveRegion == true);
      var announcement = tester.getSemantics(feedback).getSemanticsData();
      expect(announcement.flagsCollection.isLiveRegion, isTrue);
      expect(announcement.label, contains('Keep practicing'));
      expect(announcement.label, contains('Correct answer: Correct answer 1'));
      expect(announcement.label, contains('Explanation for question 1.'));

      await tap(tester, 'Next question');
      expect(feedback, findsNothing);
      await tap(tester, 'Correct answer 2');
      announcement = tester.getSemantics(feedback).getSemanticsData();
      expect(announcement.label, startsWith('Correct'));
      expect(announcement.label, contains('Explanation for question 2.'));
      expect(announcement.label, isNot(contains('question 1')));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('system back returns from mistake review without losing results',
      (tester) async {
    await seed();
    await open(tester);
    await tap(tester, 'Wrong answer 1');
    await tap(tester, 'See results');
    await tap(tester, 'Review mistakes (1)');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(inResults('You scored 0 out of 1'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(inResults('You scored 0 out of 1'), findsOneWidget);
    await tap(tester, 'Review mistakes (1)');
    expect(inResults('Wrong answer 1'), findsOneWidget);
    await tap(tester, 'Back to course');
    expect(find.text('Start quiz'), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
  });

  testWidgets('results explain earlier mistakes without changing review state',
      (tester) async {
    await seed(count: 2);
    await open(tester);
    await tap(tester, 'Wrong answer 1');
    await tap(tester, 'Next question');
    await tap(tester, 'Correct answer 2');
    await tap(tester, 'See results');
    expect(inResults('You scored 1 out of 2'), findsOneWidget);
    expect(inResults('Pass mark: 2 of 2 correct'), findsOneWidget);
    final queueBefore = await reviewQueue(tester);
    expect(queueBefore, hasLength(1));

    await tap(tester, 'Review mistakes (1)');
    expect(inResults('Published question 1'), findsOneWidget);
    expect(inResults('Wrong answer 1'), findsOneWidget);
    expect(inResults('Correct answer 1'), findsOneWidget);
    expect(inResults('Explanation for question 1.'), findsOneWidget);
    expect(inResults('Published question 2'), findsNothing);
    await tap(tester, 'Back to results');
    expect(inResults('You scored 1 out of 2'), findsOneWidget);
    expect(await reviewQueue(tester), queueBefore);
    expect((await db.doc('users/learner').get()).exists, isFalse);
  });

  testWidgets('retaking clears old mistakes and saves a single new attempt',
      (tester) async {
    await seed();
    await open(tester);
    await tap(tester, 'Wrong answer 1');
    await tap(tester, 'See results');
    await tap(tester, 'Review mistakes (1)');
    await tap(tester, 'Try again');
    await tap(tester, 'Correct answer 1');
    await tap(tester, 'See results');
    expect(inResults('You scored 1 out of 1'), findsOneWidget);
    await tap(tester, 'Review answers');
    expect(inResults('Your answer'), findsNothing);
    expect(inResults('Correct answer 1'), findsOneWidget);
    await tap(tester, 'Back to results');
    await tap(tester, 'Review answers');
    final user = (await db.doc('users/learner').get()).data()!;
    expect(user['quizScores'], hasLength(1));
    expect(user['lessonsCompleted'], 1);
  });

  testWidgets('mistake review and all actions fit small phones at double text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(longText: true);
    await open(tester, textScale: 2);
    await tap(tester, 'Wrong answer 1');
    await tap(tester, 'See results');
    await tap(tester, 'Review mistakes (1)');
    for (final text in [
      'Correct answer 1',
      'Explanation for question 1.',
      'Back to results',
      'Back to course',
      'Try again',
    ]) {
      await tester.ensureVisible(inResults(text));
      expect(inResults(text).hitTestable(), findsOneWidget);
    }
    await tap(tester, 'Try again');
    expect(find.text('Question 1 of 1').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('next question resets scrolling after a long explanation',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(count: 2, longText: true);
    await open(tester, textScale: 1.7);
    await tap(tester, 'Wrong answer 1');
    await tap(tester, 'Next question');
    expect(find.text('Question 2 of 2').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back keeps answers until leaving is explicitly confirmed',
      (tester) async {
    await seed();
    await open(tester);
    await tap(tester, 'Wrong answer 1');
    await tap(tester, 'Lesson');
    expect(find.text('Leave this quiz?'), findsOneWidget);
    await tap(tester, 'Keep going');
    expect(find.text('See results'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave this quiz?'), findsOneWidget);
    await tap(tester, 'Leave quiz');
    expect(find.text('Start quiz'), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
  });

  testWidgets('an unstarted quiz can go back without confirmation',
      (tester) async {
    await seed();
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Start quiz'), findsOneWidget);
    expect(find.text('Leave this quiz?'), findsNothing);
  });
}
